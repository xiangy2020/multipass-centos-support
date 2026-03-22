#!/bin/bash
################################################################################
# Ubuntu 三节点集群快速部署脚本
# 创建日期: 2026-03-22
# 说明: 使用 Ubuntu 24.04 创建3节点集群进行演示
################################################################################

set -e

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Ubuntu 三节点集群自动化部署                                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 配置参数
CPUS=2
MEMORY="2G"
DISK="20G"
NODE_PREFIX="node"

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
echo -e "${BLUE}[2/6]${NC} 创建三个节点..."
for i in 1 2 3; do
    NODE_NAME="${NODE_PREFIX}-${i}"
    echo "  创建 ${NODE_NAME} (${CPUS} CPU, ${MEMORY} RAM, ${DISK} Disk)..."
    multipass launch ubuntu -n ${NODE_NAME} -c ${CPUS} -m ${MEMORY} -d ${DISK} || {
        echo -e "${RED}✗ 创建 ${NODE_NAME} 失败${NC}"
        exit 1
    }
    echo -e "${GREEN}  ✓ ${NODE_NAME} 创建成功${NC}"
done
echo ""

# 3. 等待节点启动
echo -e "${BLUE}[3/6]${NC} 等待节点启动..."
sleep 5
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
multipass exec node-1 -- ping -c 2 node-2 > /dev/null && echo -e "${GREEN}  ✓ node-1 → node-2 连通${NC}"
multipass exec node-1 -- ping -c 2 node-3 > /dev/null && echo -e "${GREEN}  ✓ node-1 → node-3 连通${NC}"
multipass exec node-2 -- ping -c 2 node-3 > /dev/null && echo -e "${GREEN}  ✓ node-2 → node-3 连通${NC}"
echo ""

# 6. 生成管理脚本
echo -e "${BLUE}[6/6]${NC} 生成管理脚本..."

# check_cluster.sh
cat > check_cluster.sh << 'EEOF'
#!/bin/bash
echo "=== 集群状态 ==="
multipass list
echo ""
echo "=== 节点详细信息 ==="
for i in 1 2 3; do
    echo "--- node-${i} ---"
    multipass info node-${i} | grep -E "State|IPv4|Release"
    echo ""
done
EEOF
chmod +x check_cluster.sh

# ssh_nodes.sh
cat > ssh_nodes.sh << 'EEOF'
#!/bin/bash
echo "选择要登录的节点:"
echo "1) node-1"
echo "2) node-2"
echo "3) node-3"
read -p "请输入 (1-3): " choice
case $choice in
    1) multipass shell node-1 ;;
    2) multipass shell node-2 ;;
    3) multipass shell node-3 ;;
    *) echo "无效选择" ;;
esac
EEOF
chmod +x ssh_nodes.sh

# stop_cluster.sh
cat > stop_cluster.sh << 'EEOF'
#!/bin/bash
echo "停止集群..."
for i in 1 2 3; do
    multipass stop node-${i}
done
echo "集群已停止"
EEOF
chmod +x stop_cluster.sh

# start_cluster.sh
cat > start_cluster.sh << 'EEOF'
#!/bin/bash
echo "启动集群..."
for i in 1 2 3; do
    multipass start node-${i}
done
echo "集群已启动"
EEOF
chmod +x start_cluster.sh

# delete_cluster.sh
cat > delete_cluster.sh << 'EEOF'
#!/bin/bash
read -p "确定要删除整个集群吗? (yes/no): " confirm
if [ "$confirm" == "yes" ]; then
    echo "删除集群..."
    for i in 1 2 3; do
        multipass delete node-${i}
    done
    multipass purge
    echo "集群已删除"
else
    echo "取消操作"
fi
EEOF
chmod +x delete_cluster.sh

# test_cluster.sh
cat > test_cluster.sh << 'EEOF'
#!/bin/bash
echo "=== 集群功能测试 ==="
echo ""
echo "1. 系统信息:"
multipass exec node-1 -- uname -a
echo ""
echo "2. 网络测试:"
multipass exec node-1 -- ping -c 2 node-2
echo ""
echo "3. 在所有节点上执行命令:"
for i in 1 2 3; do
    echo "node-${i}: $(multipass exec node-${i} -- hostname)"
done
EEOF
chmod +x test_cluster.sh

echo -e "${GREEN}✓ 管理脚本已生成${NC}"
echo ""

# 7. 总结
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  🎉 集群部署成功!                                             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}集群配置:${NC}"
echo "  - 节点数量: 3"
echo "  - 操作系统: Ubuntu 24.04 LTS"
echo "  - 配置: ${CPUS} CPU, ${MEMORY} RAM, ${DISK} Disk"
echo ""
echo -e "${YELLOW}节点 IP 地址:${NC}"
for i in 1 2 3; do
    echo "  - node-${i}: ${NODE_IPS[${i}]}"
done
echo ""
echo -e "${YELLOW}管理命令:${NC}"
echo "  查看状态:   ./check_cluster.sh"
echo "  登录节点:   ./ssh_nodes.sh"
echo "  测试集群:   ./test_cluster.sh"
echo "  停止集群:   ./stop_cluster.sh"
echo "  启动集群:   ./start_cluster.sh"
echo "  删除集群:   ./delete_cluster.sh"
echo ""
echo -e "${YELLOW}快速开始:${NC}"
echo "  multipass shell node-1    # 登录 node-1"
echo "  multipass list            # 查看所有节点"
echo ""
echo -e "${GREEN}现在您可以开始使用集群了! 🚀${NC}"
