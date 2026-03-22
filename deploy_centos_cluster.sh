#!/bin/bash
################################################################################
# CentOS 三节点集群自动化部署脚本
# 基于 Multipass CentOS 支持项目
# 创建日期: 2026-03-22
################################################################################

set -e  # 遇到错误立即退出

# 确保使用 bash 4.0+
if [ "${BASH_VERSINFO:-0}" -lt 4 ]; then
    echo "Error: This script requires bash 4.0 or higher"
    echo "Current version: $BASH_VERSION"
    echo "Please upgrade bash or use: /bin/bash $0"
    exit 1
fi

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印函数
print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} $1"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# 配置参数
CLUSTER_NAME="centos-cluster"
NODE_COUNT=3
CENTOS_VERSION="centos9"  # 可选: centos7, centos8, centos-stream-8, centos9
NODE_PREFIX="node"
CPUS=2
MEMORY="2G"
DISK="20G"

# 节点配置
NODE_NAMES=()
NODE_IP_1=""
NODE_IP_2=""
NODE_IP_3=""

################################################################################
# 函数定义
################################################################################

# 检查 Multipass 是否安装
check_multipass() {
    print_header "检查 Multipass 环境"
    
    if ! command -v multipass &> /dev/null; then
        print_error "Multipass 未安装!"
        print_info "请访问 https://multipass.run 安装 Multipass"
        exit 1
    fi
    
    MULTIPASS_VERSION=$(multipass version | head -n 1 | awk '{print $2}')
    print_success "Multipass 已安装: $MULTIPASS_VERSION"
}

# 检查 CentOS 镜像是否可用
check_centos_image() {
    print_header "检查 CentOS 镜像可用性"
    
    if multipass find | grep -i "centos" > /dev/null 2>&1; then
        print_success "CentOS 镜像已可用"
        multipass find | grep -i "centos"
    else
        print_error "CentOS 镜像不可用!"
        print_info "请先按照 DEPLOYMENT_GUIDE.md 部署 CentOS 支持"
        exit 1
    fi
}

# 清理已存在的集群
cleanup_existing_cluster() {
    print_header "清理已存在的集群"
    
    local existing_nodes=$(multipass list | grep "${NODE_PREFIX}-" | awk '{print $1}' || true)
    
    if [ -z "$existing_nodes" ]; then
        print_info "没有发现已存在的集群节点"
        return
    fi
    
    print_warning "发现已存在的集群节点:"
    echo "$existing_nodes"
    
    read -p "是否删除这些节点? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for node in $existing_nodes; do
            print_info "删除节点: $node"
            multipass delete "$node"
        done
        multipass purge
        print_success "已清理旧节点"
    else
        print_error "用户取消操作"
        exit 1
    fi
}

# 创建 cloud-init 配置
create_cloud_init_config() {
    local node_name=$1
    local config_file="/tmp/${node_name}-cloud-init.yaml"
    
    cat > "$config_file" <<EOF
#cloud-config

# 主机名配置
hostname: ${node_name}
fqdn: ${node_name}.${CLUSTER_NAME}.local

# 用户配置
users:
  - name: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: wheel
    shell: /bin/bash
    lock_passwd: false
    passwd: \$6\$rounds=4096\$saltsalt\$9t7nCDX7.xL0Qz0qH7g0
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... # 请替换为您的公钥

# 包更新和安装
package_update: true
package_upgrade: true
packages:
  - vim
  - git
  - curl
  - wget
  - net-tools
  - htop
  - iptables
  - firewalld

# 防火墙配置 (允许集群间通信)
runcmd:
  - systemctl enable firewalld
  - systemctl start firewalld
  - firewall-cmd --permanent --add-service=ssh
  - firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.0.0.0/8" accept'
  - firewall-cmd --reload
  - echo "${node_name}" > /etc/hostname
  - hostnamectl set-hostname ${node_name}
  - echo "Node ${node_name} initialized" >> /var/log/cloud-init-custom.log

# 时区设置
timezone: Asia/Shanghai

# 写入文件
write_files:
  - path: /etc/motd
    content: |
      ╔════════════════════════════════════════╗
      ║  CentOS Cluster Node: ${node_name}
      ║  Cluster: ${CLUSTER_NAME}
      ║  Created: $(date)
      ╚════════════════════════════════════════╝
    permissions: '0644'

# 最终消息
final_message: "System ${node_name} is ready after \$UPTIME seconds"
EOF
    
    echo "$config_file"
}

# 创建集群节点
create_cluster_nodes() {
    print_header "创建 ${NODE_COUNT} 个集群节点"
    
    for i in $(seq 1 $NODE_COUNT); do
        local node_name="${NODE_PREFIX}-${i}"
        NODE_NAMES+=("$node_name")
        
        print_info "正在创建节点 ${i}/${NODE_COUNT}: $node_name"
        
        # 创建 cloud-init 配置
        local cloud_init_config=$(create_cloud_init_config "$node_name")
        
        # 启动虚拟机
        multipass launch "$CENTOS_VERSION" \
            --name "$node_name" \
            --cpus "$CPUS" \
            --memory "$MEMORY" \
            --disk "$DISK" \
            --cloud-init "$cloud_init_config" \
            2>&1 | tee -a "/tmp/${node_name}-launch.log"
        
        if [ $? -eq 0 ]; then
            print_success "节点 $node_name 创建成功"
        else
            print_error "节点 $node_name 创建失败!"
            cat "/tmp/${node_name}-launch.log"
            exit 1
        fi
        
        # 清理临时文件
        rm -f "$cloud_init_config"
        
        # 等待节点完全启动
        print_info "等待节点 $node_name 完全启动..."
        sleep 5
    done
    
    print_success "所有节点创建完成!"
}

# 获取节点 IP 地址
get_node_ips() {
    print_header "获取节点 IP 地址"
    
    NODE_IP_1=$(multipass info node-1 | grep IPv4 | awk '{print $2}')
    NODE_IP_2=$(multipass info node-2 | grep IPv4 | awk '{print $2}')
    NODE_IP_3=$(multipass info node-3 | grep IPv4 | awk '{print $2}')
    
    print_info "node-1: $NODE_IP_1"
    print_info "node-2: $NODE_IP_2"
    print_info "node-3: $NODE_IP_3"
}

# 配置集群互联
configure_cluster_networking() {
    print_header "配置集群网络互联"
    
    # 生成 /etc/hosts 内容
    local hosts_content="${NODE_IP_1} node-1 node-1.${CLUSTER_NAME}.local
${NODE_IP_2} node-2 node-2.${CLUSTER_NAME}.local
${NODE_IP_3} node-3 node-3.${CLUSTER_NAME}.local"
    
    # 更新所有节点的 /etc/hosts
    for i in 1 2 3; do
        print_info "配置节点 node-$i 的 /etc/hosts"
        
        multipass exec "node-$i" -- sudo bash -c "cat >> /etc/hosts <<'EOFHOSTS'

# CentOS Cluster Nodes
$hosts_content
EOFHOSTS"
        
        print_success "node-$i 网络配置完成"
    done
}

# 测试节点间连通性
test_cluster_connectivity() {
    print_header "测试集群节点连通性"
    
    local master_node="${NODE_NAMES[0]}"
    
    for target_node in "${NODE_NAMES[@]:1}"; do
        print_info "测试 $master_node -> $target_node"
        
        if multipass exec "$master_node" -- ping -c 2 "$target_node" > /dev/null 2>&1; then
            print_success "连接成功"
        else
            print_error "连接失败!"
        fi
    done
}

# 在所有节点安装基础工具
install_cluster_tools() {
    print_header "安装集群基础工具"
    
    local packages="vim git curl wget net-tools htop iotop sysstat"
    
    for node_name in "${NODE_NAMES[@]}"; do
        print_info "在 $node_name 上安装工具..."
        
        multipass exec "$node_name" -- sudo dnf install -y $packages > /dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            print_success "$node_name 工具安装完成"
        else
            print_warning "$node_name 工具安装部分失败(可能已安装)"
        fi
    done
}

# 显示集群信息
show_cluster_info() {
    print_header "集群部署完成! 🎉"
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║                     CentOS 集群信息                                   ║"
    echo "╠═══════════════════════════════════════════════════════════════════════╣"
    echo "║ 集群名称: $CLUSTER_NAME"
    echo "║ 节点数量: $NODE_COUNT"
    echo "║ CentOS 版本: $CENTOS_VERSION"
    echo "║ 配置: $CPUS CPU, $MEMORY RAM, $DISK Disk"
    echo "╠═══════════════════════════════════════════════════════════════════════╣"
    printf "║ %-15s : %-45s ║\n" "node-1" "$NODE_IP_1"
    printf "║ %-15s : %-45s ║\n" "node-2" "$NODE_IP_2"
    printf "║ %-15s : %-45s ║\n" "node-3" "$NODE_IP_3"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
}

# 生成集群管理脚本
generate_management_scripts() {
    print_header "生成集群管理脚本"
    
    # 1. 停止集群脚本
    cat > "stop_cluster.sh" <<'EOF'
#!/bin/bash
echo "停止集群所有节点..."
multipass stop node-1 node-2 node-3
echo "集群已停止"
EOF
    chmod +x stop_cluster.sh
    print_success "已生成: stop_cluster.sh"
    
    # 2. 启动集群脚本
    cat > "start_cluster.sh" <<'EOF'
#!/bin/bash
echo "启动集群所有节点..."
multipass start node-1 node-2 node-3
echo "集群已启动"
multipass list
EOF
    chmod +x start_cluster.sh
    print_success "已生成: start_cluster.sh"
    
    # 3. 删除集群脚本
    cat > "delete_cluster.sh" <<'EOF'
#!/bin/bash
read -p "确认删除整个集群? (yes/no): " confirm
if [ "$confirm" = "yes" ]; then
    echo "删除集群所有节点..."
    multipass delete node-1 node-2 node-3
    multipass purge
    echo "集群已删除"
else
    echo "操作已取消"
fi
EOF
    chmod +x delete_cluster.sh
    print_success "已生成: delete_cluster.sh"
    
    # 4. 集群状态检查脚本
    cat > "check_cluster.sh" <<'EOF'
#!/bin/bash
echo "═══════════════════════════════════════"
echo "  CentOS 集群状态检查"
echo "═══════════════════════════════════════"
multipass list | grep node-
echo ""
echo "详细信息:"
for i in 1 2 3; do
    echo "───────────────────────────────────────"
    echo "Node-$i:"
    multipass info node-$i | grep -E "State|IPv4|Release|Load"
done
EOF
    chmod +x check_cluster.sh
    print_success "已生成: check_cluster.sh"
    
    # 5. SSH 连接脚本
    for i in $(seq 1 $NODE_COUNT); do
        cat > "ssh_node${i}.sh" <<EOF
#!/bin/bash
multipass shell node-${i}
EOF
        chmod +x "ssh_node${i}.sh"
    done
    print_success "已生成: ssh_node1.sh, ssh_node2.sh, ssh_node3.sh"
}

# 生成使用文档
generate_usage_guide() {
    print_header "生成使用文档"
    
    cat > "CLUSTER_USAGE.md" <<EOF
# CentOS 三节点集群使用指南

## 📊 集群信息

- **集群名称**: $CLUSTER_NAME
- **节点数量**: $NODE_COUNT
- **CentOS 版本**: $CENTOS_VERSION
- **配置**: $CPUS CPU, $MEMORY RAM, $DISK Disk

## 🖥️ 节点列表

| 节点名称 | IP 地址 | 角色建议 |
|---------|---------|----------|
EOF

    echo "| node-1 | $NODE_IP_1 | Master/Control Plane |" >> "CLUSTER_USAGE.md"
    echo "| node-2 | $NODE_IP_2 | Worker Node 1 |" >> "CLUSTER_USAGE.md"
    echo "| node-3 | $NODE_IP_3 | Worker Node 2 |" >> "CLUSTER_USAGE.md"
    
    cat >> "CLUSTER_USAGE.md" <<'EOF'

## 🚀 快速操作

### 连接到节点

```bash
# 方法 1: 使用 multipass shell
multipass shell node-1

# 方法 2: 使用便捷脚本
./ssh_node1.sh
./ssh_node2.sh
./ssh_node3.sh

# 方法 3: 使用 SSH (如果已配置密钥)
ssh admin@<node-ip>
```

### 集群管理

```bash
# 查看集群状态
./check_cluster.sh
multipass list

# 停止集群
./stop_cluster.sh

# 启动集群
./start_cluster.sh

# 删除集群 (危险操作!)
./delete_cluster.sh
```

### 在节点上执行命令

```bash
# 单个节点
multipass exec node-1 -- hostname
multipass exec node-1 -- cat /etc/centos-release

# 所有节点
for i in 1 2 3; do
    echo "=== Node-$i ==="
    multipass exec node-$i -- hostname
done
```

## 🔧 常见任务

### 1. 部署 Kubernetes 集群

```bash
# 在所有节点上禁用 SELinux (K8s 要求)
for i in 1 2 3; do
    multipass exec node-$i -- sudo setenforce 0
    multipass exec node-$i -- sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
done

# 在所有节点上安装容器运行时
for i in 1 2 3; do
    multipass exec node-$i -- sudo dnf install -y containerd
    multipass exec node-$i -- sudo systemctl enable --now containerd
done

# 安装 kubeadm, kubelet, kubectl (参考 K8s 官方文档)
```

### 2. 配置 SSH 密钥认证

```bash
# 生成 SSH 密钥对 (如果还没有)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/cluster_rsa

# 将公钥添加到所有节点
for i in 1 2 3; do
    multipass exec node-$i -- bash -c \
        "echo '$(cat ~/.ssh/cluster_rsa.pub)' >> ~/.ssh/authorized_keys"
done
```

### 3. 挂载本地目录

```bash
# 将本地目录挂载到所有节点
mkdir -p ~/cluster-shared
for i in 1 2 3; do
    multipass mount ~/cluster-shared node-$i:/mnt/shared
done

# 测试共享目录
echo "Hello from host" > ~/cluster-shared/test.txt
multipass exec node-1 -- cat /mnt/shared/test.txt
```

### 4. 配置 NFS 共享存储

```bash
# 在 node-1 配置为 NFS 服务器
multipass exec node-1 -- sudo dnf install -y nfs-utils
multipass exec node-1 -- sudo mkdir -p /nfs-share
multipass exec node-1 -- sudo bash -c 'echo "/nfs-share *(rw,sync,no_root_squash)" >> /etc/exports'
multipass exec node-1 -- sudo systemctl enable --now nfs-server
multipass exec node-1 -- sudo exportfs -ra

# 在 node-2 和 node-3 挂载 NFS
NODE1_IP=$(multipass info node-1 | grep IPv4 | awk '{print $2}')
for i in 2 3; do
    multipass exec node-$i -- sudo dnf install -y nfs-utils
    multipass exec node-$i -- sudo mkdir -p /mnt/nfs-share
    multipass exec node-$i -- sudo mount -t nfs ${NODE1_IP}:/nfs-share /mnt/nfs-share
done
```

### 5. 配置防火墙规则

```bash
# 开放特定端口 (例如 Web 服务)
for i in 1 2 3; do
    multipass exec node-$i -- sudo firewall-cmd --permanent --add-port=80/tcp
    multipass exec node-$i -- sudo firewall-cmd --permanent --add-port=443/tcp
    multipass exec node-$i -- sudo firewall-cmd --reload
done
```

### 6. 同步时间 (NTP)

```bash
# 安装和配置 chrony
for i in 1 2 3; do
    multipass exec node-$i -- sudo dnf install -y chrony
    multipass exec node-$i -- sudo systemctl enable --now chronyd
    multipass exec node-$i -- sudo chronyc makestep
done

# 验证时间同步
for i in 1 2 3; do
    echo "=== Node-$i ==="
    multipass exec node-$i -- date
done
```

## 🧪 测试集群

### 网络连通性测试

```bash
# 从 node-1 ping 其他节点
multipass exec node-1 -- ping -c 3 node-2
multipass exec node-1 -- ping -c 3 node-3

# 测试 DNS 解析
multipass exec node-1 -- nslookup node-2
```

### 性能测试

```bash
# CPU 信息
multipass exec node-1 -- lscpu

# 内存信息
multipass exec node-1 -- free -h

# 磁盘性能测试
multipass exec node-1 -- sudo dnf install -y fio
multipass exec node-1 -- fio --name=test --filename=/tmp/testfile --size=1G --bs=4k --rw=randrw --ioengine=libaio --direct=1 --runtime=60
```

## 📦 部署应用示例

### 示例 1: Web 服务器集群

```bash
# 在所有节点安装 nginx
for i in 1 2 3; do
    multipass exec node-$i -- sudo dnf install -y nginx
    multipass exec node-$i -- sudo systemctl enable --now nginx
done

# 配置负载均衡 (在 node-1 作为负载均衡器)
# [具体配置省略,参考 nginx 负载均衡文档]
```

### 示例 2: 数据库主从复制

```bash
# 在 node-1 配置 MySQL 主库
multipass exec node-1 -- sudo dnf install -y mysql-server
multipass exec node-1 -- sudo systemctl enable --now mysqld

# 在 node-2 和 node-3 配置 MySQL 从库
# [具体配置省略,参考 MySQL 主从复制文档]
```

## 🔍 监控和日志

### 查看系统日志

```bash
# 查看系统日志
multipass exec node-1 -- sudo journalctl -xe

# 查看特定服务日志
multipass exec node-1 -- sudo journalctl -u firewalld -f
```

### 系统监控

```bash
# 安装 htop
for i in 1 2 3; do
    multipass exec node-$i -- sudo dnf install -y htop
done

# 查看实时资源使用
multipass exec node-1 -- htop
```

## 🆘 故障排除

### 节点无响应

```bash
# 重启节点
multipass restart node-1

# 停止后重新启动
multipass stop node-1
multipass start node-1
```

### 网络问题

```bash
# 检查 IP 地址
multipass info node-1

# 检查防火墙状态
multipass exec node-1 -- sudo firewall-cmd --list-all

# 重启网络服务
multipass exec node-1 -- sudo systemctl restart NetworkManager
```

### 磁盘空间不足

```bash
# 查看磁盘使用情况
multipass exec node-1 -- df -h

# 清理不必要的软件包
multipass exec node-1 -- sudo dnf clean all
multipass exec node-1 -- sudo dnf autoremove -y
```

## 📝 备份和恢复

### 快照管理

```bash
# 创建快照 (需要停止虚拟机)
multipass stop node-1
# 注意: Multipass 本身不直接支持快照,建议使用底层虚拟化平台的快照功能
# 或者定期备份重要数据

# 备份虚拟机数据
multipass exec node-1 -- tar czf /tmp/backup.tar.gz /important/data
multipass transfer node-1:/tmp/backup.tar.gz ./backup-node1-$(date +%Y%m%d).tar.gz
```

## 🎓 学习资源

- **CentOS 官方文档**: https://docs.centos.org/
- **Multipass 文档**: https://multipass.run/docs
- **Kubernetes 官方文档**: https://kubernetes.io/docs/
- **Docker 文档**: https://docs.docker.com/

## 📞 获取帮助

如有问题,请参考:
- 本项目的 `README.md`
- `DEPLOYMENT_GUIDE.md`
- `CENTOS_MULTI_VERSION_GUIDE.md`
- GitHub Issues: https://github.com/xiangy2020/multipass-centos-support

---

**创建时间**: $(date)
**集群名称**: $CLUSTER_NAME
**祝您使用愉快! 🚀**
EOF
    
    print_success "已生成: CLUSTER_USAGE.md"
}

# 打印后续步骤
print_next_steps() {
    echo ""
    print_header "🎯 后续步骤建议"
    echo ""
    echo "1️⃣  阅读集群使用文档:"
    echo "    cat CLUSTER_USAGE.md"
    echo ""
    echo "2️⃣  连接到主节点:"
    echo "    multipass shell node-1"
    echo "    或运行: ./ssh_node1.sh"
    echo ""
    echo "3️⃣  测试节点间网络:"
    echo "    multipass exec node-1 -- ping -c 3 node-2"
    echo ""
    echo "4️⃣  在所有节点执行命令:"
    echo "    for i in 1 2 3; do multipass exec node-\$i -- hostname; done"
    echo ""
    echo "5️⃣  查看集群状态:"
    echo "    ./check_cluster.sh"
    echo ""
    echo "6️⃣  部署您的应用:"
    echo "    - Kubernetes 集群"
    echo "    - Docker Swarm"
    echo "    - Ceph 存储集群"
    echo "    - Elasticsearch 集群"
    echo "    - 等等..."
    echo ""
    print_info "所有管理脚本已生成在当前目录"
    echo ""
}

################################################################################
# 主流程
################################################################################

main() {
    echo ""
    print_header "🚀 CentOS 三节点集群自动化部署"
    echo ""
    
    # 执行部署步骤
    check_multipass
    check_centos_image
    cleanup_existing_cluster
    create_cluster_nodes
    
    echo ""
    print_info "等待所有节点完全启动 (30秒)..."
    sleep 30
    
    get_node_ips
    configure_cluster_networking
    test_cluster_connectivity
    install_cluster_tools
    
    # 生成管理工具
    generate_management_scripts
    generate_usage_guide
    
    # 显示结果
    show_cluster_info
    print_next_steps
    
    print_success "集群部署完成! 🎉"
}

# 运行主流程
main "$@"
