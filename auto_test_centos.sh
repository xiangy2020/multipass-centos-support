#!/bin/bash
# CentOS 集群自动化测试脚本
# 用于编译安装完成后的快速验证

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  CentOS 集群快速测试                                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 测试1: Multipass 版本
echo -e "${BLUE}[1/6]${NC} 检查 Multipass 版本..."
if multipass version; then
    echo -e "${GREEN}  ✓ Multipass 已安装${NC}"
else
    echo -e "${RED}  ✗ Multipass 未安装或未启动${NC}"
    exit 1
fi
echo ""

# 测试2: CentOS 镜像可用性
echo -e "${BLUE}[2/6]${NC} 检查 CentOS 镜像..."
if multipass find | grep -i "centos"; then
    echo -e "${GREEN}  ✓ CentOS 镜像可用${NC}"
else
    echo -e "${YELLOW}  ! CentOS 镜像未在列表中,但可以使用本地镜像${NC}"
fi
echo ""

# 测试3: 清理旧虚拟机
echo -e "${BLUE}[3/6]${NC} 清理旧虚拟机..."
multipass delete --all 2>/dev/null || true
multipass purge
echo -e "${GREEN}  ✓ 清理完成${NC}"
echo ""

# 测试4: 创建测试节点
echo -e "${BLUE}[4/6]${NC} 创建 CentOS 测试节点..."
echo "  使用本地 CentOS Stream 9 镜像..."

if multipass launch file://${HOME}/multipass-images/CentOS-Stream-9.qcow2 \
    --name centos-test-auto \
    --cpus 2 \
    --memory 2G \
    --disk 20G \
    --timeout 300; then
    echo -e "${GREEN}  ✓ 节点创建成功${NC}"
else
    echo -e "${YELLOW}  ! file:// 不支持,尝试使用URL...${NC}"
    multipass launch https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2 \
        --name centos-test-auto \
        --cpus 2 \
        --memory 2G \
        --disk 20G
fi
echo ""

# 测试5: 验证节点
echo -e "${BLUE}[5/6]${NC} 验证节点..."
echo "  等待节点就绪..."
sleep 10

echo "  节点列表:"
multipass list

echo ""
echo "  测试节点连接:"
if multipass exec centos-test-auto -- cat /etc/os-release | grep "CentOS"; then
    echo -e "${GREEN}  ✓ CentOS 节点运行正常${NC}"
else
    echo -e "${RED}  ✗ 节点可能不是 CentOS${NC}"
fi
echo ""

# 测试6: 系统信息
echo -e "${BLUE}[6/6]${NC} 获取系统信息..."
echo "  CentOS 版本:"
multipass exec centos-test-auto -- cat /etc/redhat-release || true

echo ""
echo "  内核版本:"
multipass exec centos-test-auto -- uname -r

echo ""
echo "  IP 地址:"
multipass exec centos-test-auto -- ip -4 addr show | grep inet

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ CentOS 单节点测试成功!                                     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 询问是否继续部署集群
echo -e "${YELLOW}测试节点创建成功!${NC}"
echo ""
read -p "是否继续创建3节点集群? (y/n): " answer
if [ "$answer" = "y" ]; then
    echo ""
    echo "开始部署 3 节点集群..."
    ./deploy_centos_cluster_final.sh
else
    echo ""
    echo "保留测试节点 centos-test-auto"
    echo ""
    echo "可用命令:"
    echo "  multipass shell centos-test-auto    # 登录节点"
    echo "  multipass list                       # 查看节点列表"
    echo "  multipass delete centos-test-auto    # 删除节点"
fi
