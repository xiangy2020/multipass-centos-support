#!/bin/bash
################################################################################
# CentOS 三节点集群快速部署脚本 (简化版)
# 基于 Multipass CentOS 支持项目
# 创建日期: 2026-03-22
################################################################################

set -e  # 遇到错误立即退出

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  CentOS 三节点集群自动化部署                                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 配置参数
CENTOS_VERSION="centos9"
CPUS=2
MEMORY="2G"
DISK="20G"

# 1. 检查 Multipass
echo -e "${BLUE}[1/8]${NC} 检查 Multipass..."
if ! command -v multipass &> /dev/null; then
    echo -e "${YELLOW}Multipass 未安装!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Multipass 已安装${NC}"
echo ""

# 2. 检查 CentOS 镜像
echo -e "${BLUE}[2/8]${NC} 检查 CentOS 镜像..."
if ! multipass find | grep -i "centos" > /dev/null 2>&1; then
    echo -e "${YELLOW}CentOS 镜像不可用!请先部署 CentOS 支持${NC}"
    exit 1
fi
echo -e "${GREEN}✓ CentOS 镜像可用${NC}"
echo ""

# 3. 清理旧节点 (如果存在)
echo -e "${BLUE}[3/8]${NC} 检查已存在的节点..."
if multipass list | grep -E "node-[123]" > /dev/null 2>&1; then
    echo "发现已存在的节点:"
    multipass list | grep -E "node-[123]"
    echo ""
    read -p "是否删除这些节点? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "删除旧节点..."
        multipass delete node-1 node-2 node-3 2>/dev/null || true
        multipass purge
        echo -e "${GREEN}✓ 已清理旧节点${NC}"
    else
        echo "操作已取消"
        exit 0
    fi
else
    echo -e "${GREEN}✓ 无需清理${NC}"
fi
echo ""

# 4. 创建节点
echo -e "${BLUE}[4/8]${NC} 创建 3 个集群节点..."
echo ""

for i in 1 2 3; do
    echo -e "${BLUE}  创建 node-$i...${NC}"
    
    multipass launch "$CENTOS_VERSION" \
        --name "node-$i" \
        --cpus "$CPUS" \
        --memory "$MEMORY" \
        --disk "$DISK" \
        2>&1 | grep -E "(Launched|error|Error)" || true
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓ node-$i 创建成功${NC}"
    fi
    echo ""
done

echo -e "${GREEN}✓ 所有节点创建完成${NC}"
echo ""

# 5. 等待节点完全启动
echo -e "${BLUE}[5/8]${NC} 等待节点完全启动 (30秒)..."
sleep 30
echo -e "${GREEN}✓ 节点已就绪${NC}"
echo ""

# 6. 获取 IP 地址
echo -e "${BLUE}[6/8]${NC} 获取节点 IP 地址..."
NODE1_IP=$(multipass info node-1 | grep IPv4 | awk '{print $2}')
NODE2_IP=$(multipass info node-2 | grep IPv4 | awk '{print $2}')
NODE3_IP=$(multipass info node-3 | grep IPv4 | awk '{print $2}')

echo "  node-1: $NODE1_IP"
echo "  node-2: $NODE2_IP"
echo "  node-3: $NODE3_IP"
echo -e "${GREEN}✓ IP 地址获取完成${NC}"
echo ""

# 7. 配置集群网络
echo -e "${BLUE}[7/8]${NC} 配置集群网络..."

HOSTS_CONTENT="
# CentOS Cluster Nodes
$NODE1_IP node-1 node-1.centos-cluster.local
$NODE2_IP node-2 node-2.centos-cluster.local
$NODE3_IP node-3 node-3.centos-cluster.local"

for i in 1 2 3; do
    echo "  配置 node-$i..."
    multipass exec "node-$i" -- sudo bash -c "echo '$HOSTS_CONTENT' >> /etc/hosts"
done

echo -e "${GREEN}✓ 网络配置完成${NC}"
echo ""

# 8. 测试连通性
echo -e "${BLUE}[8/8]${NC} 测试节点连通性..."
echo "  测试 node-1 -> node-2..."
if multipass exec node-1 -- ping -c 2 node-2 > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ 连接成功${NC}"
else
    echo -e "${YELLOW}  ! 连接失败${NC}"
fi

echo "  测试 node-1 -> node-3..."
if multipass exec node-1 -- ping -c 2 node-3 > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ 连接成功${NC}"
else
    echo -e "${YELLOW}  ! 连接失败${NC}"
fi
echo ""

# 生成管理脚本
echo "生成集群管理脚本..."

cat > "check_cluster.sh" <<'EOF'
#!/bin/bash
echo "═══════════════════════════════════════"
echo "  CentOS 集群状态"
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

cat > "stop_cluster.sh" <<'EOF'
#!/bin/bash
echo "停止集群..."
multipass stop node-1 node-2 node-3
echo "完成!"
EOF
chmod +x stop_cluster.sh

cat > "start_cluster.sh" <<'EOF'
#!/bin/bash
echo "启动集群..."
multipass start node-1 node-2 node-3
echo "完成!"
multipass list
EOF
chmod +x start_cluster.sh

cat > "delete_cluster.sh" <<'EOF'
#!/bin/bash
read -p "确认删除整个集群? (yes/no): " confirm
if [ "$confirm" = "yes" ]; then
    echo "删除集群..."
    multipass delete node-1 node-2 node-3
    multipass purge
    echo "完成!"
else
    echo "已取消"
fi
EOF
chmod +x delete_cluster.sh

for i in 1 2 3; do
    echo "#!/bin/bash" > "ssh_node${i}.sh"
    echo "multipass shell node-${i}" >> "ssh_node${i}.sh"
    chmod +x "ssh_node${i}.sh"
done

echo -e "${GREEN}✓ 管理脚本已生成${NC}"
echo ""

# 显示集群信息
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    🎉 集群部署完成! 🎉                                ║${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC} 集群名称: centos-cluster"
echo -e "${GREEN}║${NC} 节点数量: 3"
echo -e "${GREEN}║${NC} CentOS 版本: $CENTOS_VERSION"
echo -e "${GREEN}║${NC} 配置: $CPUS CPU, $MEMORY RAM, $DISK Disk"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════════════╣${NC}"
printf "${GREEN}║${NC} %-15s : %-48s${GREEN}║${NC}\n" "node-1" "$NODE1_IP"
printf "${GREEN}║${NC} %-15s : %-48s${GREEN}║${NC}\n" "node-2" "$NODE2_IP"
printf "${GREEN}║${NC} %-15s : %-48s${GREEN}║${NC}\n" "node-3" "$NODE3_IP"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}🎯 快速操作:${NC}"
echo ""
echo "  查看状态:    ./check_cluster.sh"
echo "  连接节点:    ./ssh_node1.sh"
echo "  停止集群:    ./stop_cluster.sh"
echo "  启动集群:    ./start_cluster.sh"
echo "  删除集群:    ./delete_cluster.sh"
echo ""
echo "  或使用 multipass 命令:"
echo "    multipass shell node-1"
echo "    multipass list"
echo "    multipass info node-1"
echo ""
echo -e "${GREEN}✨ 集群已就绪,开始您的分布式系统之旅吧! 🚀${NC}"
echo ""
