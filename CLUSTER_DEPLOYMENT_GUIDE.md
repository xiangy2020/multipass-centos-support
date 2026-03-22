# CentOS 三节点集群部署完整指南

## 📖 概述

本指南提供了使用 Multipass 和 CentOS 镜像快速部署三节点集群的完整流程。该集群可用于学习、开发和测试分布式系统,如 Kubernetes、Docker Swarm、Ceph 存储等。

**部署时间**: 约 5-10 分钟  
**难度级别**: ⭐⭐☆☆☆ (中等)  
**前置要求**: 已完成 Multipass CentOS 支持部署

---

## 🎯 集群架构

### 标准三节点配置

```
┌─────────────────────────────────────────────────┐
│                CentOS Cluster                    │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│  │ node-1   │    │ node-2   │    │ node-3   │  │
│  │ Master   │◄──►│ Worker 1 │◄──►│ Worker 2 │  │
│  │          │    │          │    │          │  │
│  │ 2 CPU    │    │ 2 CPU    │    │ 2 CPU    │  │
│  │ 2G RAM   │    │ 2G RAM   │    │ 2G RAM   │  │
│  │ 20G Disk │    │ 20G Disk │    │ 20G Disk │  │
│  └──────────┘    └──────────┘    └──────────┘  │
│                                                  │
│  Private Network: 10.x.x.x/24                   │
│  Hostnames: node-1, node-2, node-3              │
└─────────────────────────────────────────────────┘
```

### 集群特性

- ✅ **三节点高可用架构**
- ✅ **自动配置主机名和 /etc/hosts**
- ✅ **防火墙预配置 (允许内网通信)**
- ✅ **基础工具预安装** (vim, git, curl, htop)
- ✅ **统一时区设置** (Asia/Shanghai)
- ✅ **Cloud-init 自动化配置**

---

## 🚀 快速部署

### 方法 1: 一键自动化部署 (推荐)

```bash
# 1. 进入项目目录
cd /Users/tompyang/WorkBuddy/20260320161009

# 2. 运行自动化部署脚本
./deploy_centos_cluster.sh

# 脚本会自动完成:
# - 检查环境
# - 创建 3 个虚拟机
# - 配置网络和主机名
# - 安装基础工具
# - 测试连通性
# - 生成管理脚本
```

**预计耗时**: 5-10 分钟 (取决于网络速度)

### 方法 2: 手动逐步部署

如果您想了解详细过程或需要自定义配置:

```bash
# 1. 创建节点 1 (Master)
multipass launch centos9 --name node-1 --cpus 2 --memory 2G --disk 20G

# 2. 创建节点 2 (Worker 1)
multipass launch centos9 --name node-2 --cpus 2 --memory 2G --disk 20G

# 3. 创建节点 3 (Worker 2)
multipass launch centos9 --name node-3 --cpus 2 --memory 2G --disk 20G

# 4. 验证所有节点
multipass list
```

---

## ⚙️ 自定义配置

### 修改集群参数

编辑 `deploy_centos_cluster.sh` 中的配置变量:

```bash
# 集群配置
CLUSTER_NAME="centos-cluster"      # 集群名称
NODE_COUNT=3                        # 节点数量 (可改为 5, 7 等奇数)
CENTOS_VERSION="centos9"            # CentOS 版本
NODE_PREFIX="node"                  # 节点名称前缀

# 资源配置
CPUS=2                              # 每节点 CPU 核心数
MEMORY="2G"                         # 每节点内存 (可改为 4G, 8G)
DISK="20G"                          # 每节点磁盘 (可改为 40G, 100G)
```

### 使用不同的 CentOS 版本

```bash
# CentOS 7
CENTOS_VERSION="centos7"

# CentOS 8
CENTOS_VERSION="centos8"

# CentOS Stream 8
CENTOS_VERSION="centos-stream-8"

# CentOS Stream 9 (默认)
CENTOS_VERSION="centos9"
```

### 自定义 Cloud-init 配置

脚本中的 `create_cloud_init_config()` 函数可以自定义:

- 用户和权限
- 软件包安装
- 防火墙规则
- 启动脚本
- 时区设置

---

## 🔧 部署后配置

### 1. 验证集群状态

```bash
# 查看所有节点
multipass list

# 检查节点详情
./check_cluster.sh

# 或手动检查
multipass info node-1
multipass info node-2
multipass info node-3
```

### 2. 测试网络连通性

```bash
# 从 node-1 ping 其他节点
multipass exec node-1 -- ping -c 3 node-2
multipass exec node-1 -- ping -c 3 node-3

# 测试主机名解析
multipass exec node-1 -- nslookup node-2
```

### 3. 连接到节点

```bash
# 方法 1: 使用 multipass shell
multipass shell node-1

# 方法 2: 使用便捷脚本
./ssh_node1.sh
./ssh_node2.sh
./ssh_node3.sh

# 方法 3: 通过 SSH (需先配置密钥)
ssh ubuntu@$(multipass info node-1 | grep IPv4 | awk '{print $2}')
```

### 4. 配置 SSH 密钥认证

```bash
# 生成密钥对 (如果还没有)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/centos_cluster_rsa

# 将公钥复制到所有节点
for i in 1 2 3; do
    multipass exec node-$i -- bash -c \
        "mkdir -p ~/.ssh && echo '$(cat ~/.ssh/centos_cluster_rsa.pub)' >> ~/.ssh/authorized_keys"
done

# 配置 SSH config (可选)
cat >> ~/.ssh/config <<EOF

# CentOS Cluster Nodes
Host node-1
    HostName $(multipass info node-1 | grep IPv4 | awk '{print $2}')
    User ubuntu
    IdentityFile ~/.ssh/centos_cluster_rsa

Host node-2
    HostName $(multipass info node-2 | grep IPv4 | awk '{print $2}')
    User ubuntu
    IdentityFile ~/.ssh/centos_cluster_rsa

Host node-3
    HostName $(multipass info node-3 | grep IPv4 | awk '{print $2}')
    User ubuntu
    IdentityFile ~/.ssh/centos_cluster_rsa
EOF

# 现在可以直接 SSH
ssh node-1
```

---

## 📦 集群应用场景

### 场景 1: Kubernetes 集群

使用该三节点集群部署 Kubernetes:

```bash
# 1. 禁用 swap 和 SELinux
for i in 1 2 3; do
    multipass exec node-$i -- sudo swapoff -a
    multipass exec node-$i -- sudo setenforce 0
done

# 2. 安装容器运行时 (containerd)
for i in 1 2 3; do
    multipass exec node-$i -- bash <<'INSTALL'
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y containerd.io
sudo systemctl enable --now containerd
INSTALL
done

# 3. 安装 kubeadm, kubelet, kubectl
# (参考 Kubernetes 官方文档)
```

### 场景 2: Docker Swarm 集群

```bash
# 1. 安装 Docker
for i in 1 2 3; do
    multipass exec node-$i -- sudo dnf install -y docker
    multipass exec node-$i -- sudo systemctl enable --now docker
done

# 2. 初始化 Swarm (在 node-1)
multipass exec node-1 -- sudo docker swarm init

# 3. 获取 join token 并加入 worker 节点
JOIN_TOKEN=$(multipass exec node-1 -- sudo docker swarm join-token worker -q)
NODE1_IP=$(multipass info node-1 | grep IPv4 | awk '{print $2}')

for i in 2 3; do
    multipass exec node-$i -- sudo docker swarm join --token $JOIN_TOKEN $NODE1_IP:2377
done

# 4. 验证集群
multipass exec node-1 -- sudo docker node ls
```

### 场景 3: Ceph 存储集群

```bash
# 1. 安装 Ceph (在所有节点)
for i in 1 2 3; do
    multipass exec node-$i -- sudo dnf install -y centos-release-ceph-quincy
    multipass exec node-$i -- sudo dnf install -y ceph
done

# 2. 配置 Ceph
# (参考 Ceph 官方文档进行详细配置)
```

### 场景 4: Elasticsearch 集群

```bash
# 1. 安装 Java (在所有节点)
for i in 1 2 3; do
    multipass exec node-$i -- sudo dnf install -y java-11-openjdk
done

# 2. 安装 Elasticsearch
# (参考 Elasticsearch 官方文档)
```

### 场景 5: PostgreSQL 高可用集群 (Patroni)

```bash
# 1. 安装 PostgreSQL 和 Patroni
for i in 1 2 3; do
    multipass exec node-$i -- sudo dnf install -y postgresql-server python3-pip
    multipass exec node-$i -- sudo pip3 install patroni[etcd]
done

# 2. 配置 Patroni
# (参考 Patroni 官方文档)
```

---

## 🛠️ 集群管理

### 启动和停止

```bash
# 停止所有节点
./stop_cluster.sh
# 或
multipass stop node-1 node-2 node-3

# 启动所有节点
./start_cluster.sh
# 或
multipass start node-1 node-2 node-3

# 重启所有节点
multipass restart node-1 node-2 node-3
```

### 查看状态

```bash
# 快速查看
./check_cluster.sh

# 详细信息
multipass info node-1
multipass info node-2
multipass info node-3

# 查看资源使用
for i in 1 2 3; do
    echo "=== Node-$i ==="
    multipass exec node-$i -- free -h
    multipass exec node-$i -- df -h
done
```

### 批量执行命令

```bash
# 在所有节点执行命令
for i in 1 2 3; do
    echo "=== Node-$i ==="
    multipass exec node-$i -- <命令>
done

# 示例: 更新所有节点
for i in 1 2 3; do
    multipass exec node-$i -- sudo dnf update -y
done

# 示例: 检查磁盘使用
for i in 1 2 3; do
    echo "=== Node-$i ==="
    multipass exec node-$i -- df -h
done
```

### 数据传输

```bash
# 从本地复制到节点
multipass transfer local-file.txt node-1:/home/ubuntu/

# 从节点复制到本地
multipass transfer node-1:/home/ubuntu/remote-file.txt ./

# 在节点间复制 (通过主机中转)
multipass transfer node-1:/data/file.txt ./temp.txt
multipass transfer ./temp.txt node-2:/data/
```

### 挂载共享目录

```bash
# 挂载本地目录到所有节点
mkdir -p ~/cluster-shared

for i in 1 2 3; do
    multipass mount ~/cluster-shared node-$i:/mnt/shared
done

# 测试
echo "Hello from host" > ~/cluster-shared/test.txt
multipass exec node-1 -- cat /mnt/shared/test.txt

# 取消挂载
for i in 1 2 3; do
    multipass umount node-$i:/mnt/shared
done
```

---

## 🔍 监控和诊断

### 系统监控

```bash
# 安装监控工具
for i in 1 2 3; do
    multipass exec node-$i -- sudo dnf install -y htop iotop sysstat
done

# 查看实时资源使用
multipass exec node-1 -- htop

# 查看 I/O 统计
multipass exec node-1 -- iostat -x 1

# 查看网络统计
multipass exec node-1 -- sar -n DEV 1
```

### 日志查看

```bash
# 系统日志
multipass exec node-1 -- sudo journalctl -xe

# 跟踪特定服务
multipass exec node-1 -- sudo journalctl -u firewalld -f

# 查看 cloud-init 日志
multipass exec node-1 -- sudo cat /var/log/cloud-init.log
multipass exec node-1 -- sudo cat /var/log/cloud-init-output.log
```

### 网络诊断

```bash
# 查看网络接口
multipass exec node-1 -- ip addr show

# 查看路由表
multipass exec node-1 -- ip route

# 查看防火墙规则
multipass exec node-1 -- sudo firewall-cmd --list-all

# 端口监听状态
multipass exec node-1 -- sudo ss -tulnp
```

---

## 🧪 性能测试

### CPU 性能测试

```bash
# 安装 sysbench
multipass exec node-1 -- sudo dnf install -y sysbench

# CPU 测试
multipass exec node-1 -- sysbench cpu --threads=2 run
```

### 内存性能测试

```bash
# 内存测试
multipass exec node-1 -- sysbench memory --threads=2 run
```

### 磁盘性能测试

```bash
# 安装 fio
multipass exec node-1 -- sudo dnf install -y fio

# 随机读写测试
multipass exec node-1 -- sudo fio --name=randtest --filename=/tmp/testfile \
    --size=1G --bs=4k --rw=randrw --ioengine=libaio --direct=1 --runtime=60 --time_based
```

### 网络性能测试

```bash
# 安装 iperf3
for i in 1 2 3; do
    multipass exec node-$i -- sudo dnf install -y iperf3
done

# 在 node-2 启动服务器
multipass exec node-2 -- iperf3 -s -D

# 从 node-1 测试到 node-2
multipass exec node-1 -- iperf3 -c node-2 -t 30
```

---

## 🔐 安全加固

### 防火墙配置

```bash
# 只允许必要的端口
for i in 1 2 3; do
    multipass exec node-$i -- sudo firewall-cmd --permanent --add-service=ssh
    multipass exec node-$i -- sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.0.0.0/8" accept'
    multipass exec node-$i -- sudo firewall-cmd --reload
done
```

### SELinux 配置

```bash
# 检查 SELinux 状态
multipass exec node-1 -- sestatus

# 如果需要禁用 (某些应用要求)
for i in 1 2 3; do
    multipass exec node-$i -- sudo setenforce 0
    multipass exec node-$i -- sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
done
```

### 更新系统

```bash
# 更新所有节点
for i in 1 2 3; do
    echo "=== 更新 Node-$i ==="
    multipass exec node-$i -- sudo dnf update -y
done
```

---

## 🆘 故障排除

### 节点无法启动

**症状**: `multipass launch` 失败或超时

**解决方案**:
```bash
# 1. 检查 Multipass 服务状态
multipass version

# 2. 重启 Multipass (macOS)
sudo launchctl unload /Library/LaunchDaemons/com.canonical.multipassd.plist
sudo launchctl load /Library/LaunchDaemons/com.canonical.multipassd.plist

# 3. 查看详细日志
tail -f /Library/Logs/Multipass/multipassd.log
```

### 网络连通性问题

**症状**: 节点间无法 ping 通

**解决方案**:
```bash
# 1. 检查防火墙
multipass exec node-1 -- sudo firewall-cmd --list-all

# 2. 临时禁用防火墙测试
multipass exec node-1 -- sudo systemctl stop firewalld

# 3. 检查 IP 地址
multipass exec node-1 -- ip addr show

# 4. 检查路由
multipass exec node-1 -- ip route
```

### 磁盘空间不足

**症状**: 节点磁盘空间满

**解决方案**:
```bash
# 1. 查看磁盘使用
multipass exec node-1 -- df -h

# 2. 清理不必要的软件包
multipass exec node-1 -- sudo dnf clean all
multipass exec node-1 -- sudo dnf autoremove -y

# 3. 清理日志文件
multipass exec node-1 -- sudo journalctl --vacuum-time=7d

# 4. 如果需要扩容
# 需要停止虚拟机后使用底层虚拟化工具扩容
```

### Cloud-init 失败

**症状**: 自定义配置未生效

**解决方案**:
```bash
# 1. 查看 cloud-init 日志
multipass exec node-1 -- sudo cat /var/log/cloud-init.log
multipass exec node-1 -- sudo cat /var/log/cloud-init-output.log

# 2. 检查 cloud-init 状态
multipass exec node-1 -- sudo cloud-init status --long

# 3. 重新运行 cloud-init (危险)
multipass exec node-1 -- sudo cloud-init clean
multipass exec node-1 -- sudo cloud-init init
```

---

## 🗑️ 清理集群

### 临时停止

```bash
# 停止所有节点
./stop_cluster.sh

# 或手动停止
multipass stop node-1 node-2 node-3
```

### 完全删除

```bash
# 使用脚本 (推荐)
./delete_cluster.sh

# 或手动删除
multipass delete node-1 node-2 node-3
multipass purge

# 验证删除
multipass list
```

---

## 📚 参考资料

### 官方文档

- **Multipass**: https://multipass.run/docs
- **CentOS**: https://docs.centos.org/
- **Cloud-init**: https://cloudinit.readthedocs.io/

### 分布式系统文档

- **Kubernetes**: https://kubernetes.io/docs/
- **Docker Swarm**: https://docs.docker.com/engine/swarm/
- **Ceph**: https://docs.ceph.com/
- **Elasticsearch**: https://www.elastic.co/guide/

### 本项目文档

- [README.md](./README.md) - 项目总览
- [CENTOS_MULTI_VERSION_GUIDE.md](./CENTOS_MULTI_VERSION_GUIDE.md) - 多版本支持指南
- [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - CentOS 支持部署指南
- [CLUSTER_USAGE.md](./CLUSTER_USAGE.md) - 集群使用指南 (部署后自动生成)

---

## 💡 最佳实践

### 1. 资源规划

- **开发/测试**: 2 CPU, 2G RAM, 20G Disk (默认)
- **性能测试**: 4 CPU, 4G RAM, 40G Disk
- **生产模拟**: 8 CPU, 8G RAM, 100G Disk

### 2. 安全建议

- ✅ 使用 SSH 密钥认证,禁用密码登录
- ✅ 定期更新系统和软件包
- ✅ 启用防火墙,只开放必要端口
- ✅ 根据应用需求配置 SELinux
- ✅ 定期备份重要数据

### 3. 监控建议

- ✅ 部署监控工具 (Prometheus + Grafana)
- ✅ 配置日志聚合 (ELK Stack)
- ✅ 设置告警规则
- ✅ 定期检查资源使用情况

### 4. 备份策略

- ✅ 定期创建快照 (底层虚拟化平台)
- ✅ 备份重要配置文件
- ✅ 使用版本控制管理配置
- ✅ 测试恢复流程

---

## 🎯 下一步

现在您已经有了一个完整的三节点 CentOS 集群,可以:

1. **学习分布式系统**: 部署 Kubernetes, Docker Swarm 等
2. **开发和测试**: 模拟生产环境,测试应用的高可用性
3. **性能测试**: 测试应用在集群环境下的性能
4. **学习 DevOps**: 实践 CI/CD, 配置管理, 监控等

**祝您使用愉快! 🚀**

---

**文档版本**: 1.0  
**创建日期**: 2026-03-22  
**项目主页**: https://github.com/xiangy2020/multipass-centos-support
