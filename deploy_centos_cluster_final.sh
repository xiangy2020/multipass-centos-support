#!/bin/bash
################################################################################
# CentOS 三节点集群快速部署脚本
# 使用本地下载的 CentOS 镜像
################################################################################

set -e

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  CentOS 三节点集群自动化部署                                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 配置参数
CPUS=2
MEMORY="2G"
DISK="20G"
NODE_PREFIX="centos"
CENTOS_IMAGE="${HOME}/multipass-images/CentOS-Stream-9.qcow2"

# 检查镜像是否存在
if [ ! -f "${CENTOS_IMAGE}" ]; then
    echo -e "${RED}错误: CentOS 镜像不存在: ${CENTOS_IMAGE}${NC}"
    echo "请先运行: ./download_centos_images.sh"
    exit 1
fi

echo -e "${YELLOW}使用镜像: ${CENTOS_IMAGE}${NC}"
echo ""

# 1. 清理旧节点
echo -e "${BLUE}[1/6]${NC} 清理旧节点..."
for i in 1 2 3; do
    if multipass list | grep -q "${NODE_PREFIX}-${i}"; then
        echo "  删除 ${NODE_PREFIX}-${i}..."
        multipass delete ${NODE_PREFIX}-${i} 2>/dev/null || true
    fi
done
multipass purge 2>/dev/null || true
echo -e "${GREEN}✓ 清理完成${NC}"
echo ""

# 2. 创建三个节点
echo -e "${BLUE}[2/6]${NC} 创建三个 CentOS 节点..."
for i in 1 2 3; do
    NODE_NAME="${NODE_PREFIX}-${i}"
    echo "  创建 ${NODE_NAME} (${CPUS} CPU, ${MEMORY} RAM, ${DISK} Disk)..."
    
    multipass launch file://${CENTOS_IMAGE} \
        --name ${NODE_NAME} \
        --cpus ${CPUS} \
        --memory ${MEMORY} \
        --disk ${DISK} || {
        echo -e "${RED}✗ 创建 ${NODE_NAME} 失败${NC}"
        exit 1
    }
    
    echo -e "${GREEN}  ✓ ${NODE_NAME} 创建成功${NC}"
done
echo ""

# 3. 等待节点启动
echo -e "${BLUE}[3/6]${NC} 等待节点启动..."
sleep 10
echo -e "${GREEN}✓ 所有节点已启动${NC}"
echo ""

# 4. 获取 IP 地址并配置 /etc/hosts
echo -e "${BLUE}[4/6]${NC} 配置网络..."
declare -A NODE_IPS
for i in 1 2 3; do
    NODE_NAME="${NODE_PREFIX}-${i}"
    IP=$(multipass info ${NODE_NAME} | grep IPv4 | awk '{print $2}')
    NODE_IPS[${i}]=${IP}
    echo "  ${NODE_NAME}: ${IP}"
done
echo ""

# 生成 hosts 配置
HOSTS_CONTENT=""
for i in 1 2 3; do
    HOSTS_CONTENT+="${NODE_IPS[${i}]} ${NODE_PREFIX}-${i}\n"
done

# 在每个节点上配置 /etc/hosts
for i in 1 2 3; do
    NODE_NAME="${NODE_PREFIX}-${i}"
    echo "  配置 ${NODE_NAME} 的 /etc/hosts..."
    multipass exec ${NODE_NAME} -- sudo bash -c "echo -e '${HOSTS_CONTENT}' >> /etc/hosts"
done
echo -e "${GREEN}✓ 网络配置完成${NC}"
echo ""

# 5. 测试网络连通性
echo -e "${BLUE}[5/6]${NC} 测试网络连通性..."
multipass exec centos-1 -- ping -c 2 centos-2 > /dev/null && echo -e "${GREEN}  ✓ centos-1 → centos-2 连通${NC}"
multipass exec centos-1 -- ping -c 2 centos-3 > /dev/null && echo -e "${GREEN}  ✓ centos-1 → centos-3 连通${NC}"
multipass exec centos-2 -- ping -c 2 centos-3 > /dev/null && echo -e "${GREEN}  ✓ centos-2 → centos-3 连通${NC}"
echo ""

# 6. 获取系统信息
echo -e "${BLUE}[6/6]${NC} 获取系统信息..."
for i in 1 2 3; do
    NODE_NAME="${NODE_PREFIX}-${i}"
    OS_INFO=$(multipass exec ${NODE_NAME} -- cat /etc/os-release | grep "PRETTY_NAME" | cut -d'"' -f2)
    KERNEL=$(multipass exec ${NODE_NAME} -- uname -r)
    echo "  ${NODE_NAME}: ${OS_INFO} (${KERNEL})"
done
echo ""

# 7. 生成管理脚本
echo -e "${BLUE}[7/6]${NC} 生成管理脚本..."

# check_centos_cluster.sh
cat > check_centos_cluster.sh << 'EEOF'
#!/bin/bash
echo "=== CentOS 集群状态 ==="
multipass list | grep centos
echo ""
echo "=== 节点详细信息 ==="
for i in 1 2 3; do
    echo "--- centos-${i} ---"
    multipass info centos-${i} | grep -E "State|IPv4|Release"
    echo ""
done
EEOF
chmod +x check_centos_cluster.sh

# ssh_centos.sh
cat > ssh_centos.sh << 'EEOF'
#!/bin/bash
echo "选择要登录的节点:"
echo "1) centos-1"
echo "2) centos-2"
echo "3) centos-3"
read -p "请输入 (1-3): " choice
case $choice in
    1) multipass shell centos-1 ;;
    2) multipass shell centos-2 ;;
    3) multipass shell centos-3 ;;
    *) echo "无效选择" ;;
esac
EEOF
chmod +x ssh_centos.sh

# stop_centos_cluster.sh
cat > stop_centos_cluster.sh << 'EEOF'
#!/bin/bash
echo "停止 CentOS 集群..."
for i in 1 2 3; do
    multipass stop centos-${i}
done
echo "集群已停止"
EEOF
chmod +x stop_centos_cluster.sh

# start_centos_cluster.sh
cat > start_centos_cluster.sh << 'EEOF'
#!/bin/bash
echo "启动 CentOS 集群..."
for i in 1 2 3; do
    multipass start centos-${i}
done
echo "集群已启动"
EEOF
chmod +x start_centos_cluster.sh

# delete_centos_cluster.sh
cat > delete_centos_cluster.sh << 'EEOF'
#!/bin/bash
read -p "确定要删除整个 CentOS 集群吗? (yes/no): " confirm
if [ "$confirm" == "yes" ]; then
    echo "删除集群..."
    for i in 1 2 3; do
        multipass delete centos-${i}
    done
    multipass purge
    echo "集群已删除"
    rm -f check_centos_cluster.sh ssh_centos.sh stop_centos_cluster.sh start_centos_cluster.sh delete_centos_cluster.sh test_centos_cluster.sh
else
    echo "取消操作"
fi
EEOF
chmod +x delete_centos_cluster.sh

# test_centos_cluster.sh
cat > test_centos_cluster.sh << 'EEOF'
#!/bin/bash
echo "=== CentOS 集群功能测试 ==="
echo ""
echo "1. 系统信息:"
for i in 1 2 3; do
    echo "centos-${i}:"
    multipass exec centos-${i} -- cat /etc/os-release | grep PRETTY_NAME
done
echo ""
echo "2. 网络测试:"
multipass exec centos-1 -- ping -c 3 centos-2
echo ""
echo "3. 在所有节点上执行命令:"
for i in 1 2 3; do
    echo "centos-${i}: $(multipass exec centos-${i} -- hostname)"
done
echo ""
echo "4. 磁盘使用情况:"
for i in 1 2 3; do
    echo "centos-${i}:"
    multipass exec centos-${i} -- df -h / | tail -1
done
EEOF
chmod +x test_centos_cluster.sh

echo -e "${GREEN}✓ 管理脚本已生成${NC}"
echo ""

# 8. 总结
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  🎉 CentOS 集群部署成功!                                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}集群配置:${NC}"
echo "  - 节点数量: 3"
echo "  - 操作系统: CentOS Stream 9"
echo "  - 配置: ${CPUS} CPU, ${MEMORY} RAM, ${DISK} Disk"
echo ""
echo -e "${YELLOW}节点 IP 地址:${NC}"
for i in 1 2 3; do
    echo "  - centos-${i}: ${NODE_IPS[${i}]}"
done
echo ""
echo -e "${YELLOW}管理命令:${NC}"
echo "  查看状态:   ./check_centos_cluster.sh"
echo "  登录节点:   ./ssh_centos.sh"
echo "  测试集群:   ./test_centos_cluster.sh"
echo "  停止集群:   ./stop_centos_cluster.sh"
echo "  启动集群:   ./start_centos_cluster.sh"
echo "  删除集群:   ./delete_centos_cluster.sh"
echo ""
echo -e "${YELLOW}快速开始:${NC}"
echo "  multipass shell centos-1   # 登录 centos-1"
echo "  multipass list             # 查看所有节点"
echo ""
echo -e "${GREEN}现在您可以开始使用 CentOS 集群了! 🚀${NC}"
