#!/bin/bash

# Multipass CentOS 支持 - 快速测试脚本
# 用于验证 CentOS 镜像支持是否正常工作

set -e  # 遇到错误立即退出

echo "════════════════════════════════════════════════════════════════"
echo "  Multipass CentOS 支持测试脚本"
echo "════════════════════════════════════════════════════════════════"
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 测试 1: 检查 multipass 是否安装
echo -e "${YELLOW}[测试 1/7]${NC} 检查 Multipass 是否安装..."
if ! command -v multipass &> /dev/null; then
    echo -e "${RED}✗ Multipass 未安装${NC}"
    echo "请先安装 Multipass: https://multipass.run/install"
    exit 1
fi
echo -e "${GREEN}✓ Multipass 已安装${NC}"
multipass version
echo ""

# 测试 2: 检查 CentOS 是否出现在镜像列表中
echo -e "${YELLOW}[测试 2/7]${NC} 检查 CentOS 镜像是否可用..."
if multipass find | grep -i centos > /dev/null; then
    echo -e "${GREEN}✓ CentOS 镜像已列出${NC}"
    echo ""
    echo "可用的 CentOS 镜像:"
    multipass find | grep -i centos
else
    echo -e "${RED}✗ 未找到 CentOS 镜像${NC}"
    echo "请确认已将 distribution-info.json 复制到正确位置"
    exit 1
fi
echo ""

# 测试 3: 启动 CentOS 虚拟机
VM_NAME="test-centos-$(date +%s)"
echo -e "${YELLOW}[测试 3/7]${NC} 启动 CentOS 虚拟机 (名称: ${VM_NAME})..."
echo "这可能需要几分钟时间下载镜像..."

if multipass launch centos --name "$VM_NAME" --cpus 1 --memory 1G --disk 5G; then
    echo -e "${GREEN}✓ 虚拟机启动成功${NC}"
else
    echo -e "${RED}✗ 虚拟机启动失败${NC}"
    exit 1
fi
echo ""

# 等待虚拟机完全启动
echo "等待虚拟机完全初始化..."
sleep 10

# 测试 4: 查看虚拟机信息
echo -e "${YELLOW}[测试 4/7]${NC} 查看虚拟机信息..."
multipass info "$VM_NAME"
echo ""

# 测试 5: 验证操作系统
echo -e "${YELLOW}[测试 5/7]${NC} 验证操作系统..."
OS_INFO=$(multipass exec "$VM_NAME" -- cat /etc/os-release)
echo "$OS_INFO"

if echo "$OS_INFO" | grep -i "centos" > /dev/null; then
    echo -e "${GREEN}✓ 确认为 CentOS 系统${NC}"
else
    echo -e "${RED}✗ 系统识别失败${NC}"
fi
echo ""

# 测试 6: 测试网络连接
echo -e "${YELLOW}[测试 6/7]${NC} 测试网络连接..."
if multipass exec "$VM_NAME" -- ping -c 3 8.8.8.8 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 网络连接正常${NC}"
else
    echo -e "${RED}✗ 网络连接失败${NC}"
fi
echo ""

# 测试 7: 测试软件包管理器
echo -e "${YELLOW}[测试 7/7]${NC} 测试 DNF 软件包管理器..."
if multipass exec "$VM_NAME" -- sudo dnf --version > /dev/null 2>&1; then
    echo -e "${GREEN}✓ DNF 可用${NC}"
    multipass exec "$VM_NAME" -- dnf --version
else
    echo -e "${RED}✗ DNF 不可用${NC}"
fi
echo ""

# 交互式测试
echo "════════════════════════════════════════════════════════════════"
echo -e "${GREEN}所有自动化测试已完成!${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "你可以执行以下命令进行进一步测试:"
echo ""
echo "  # 连接到虚拟机 Shell"
echo "  multipass shell $VM_NAME"
echo ""
echo "  # 在虚拟机中执行命令"
echo "  multipass exec $VM_NAME -- uname -a"
echo ""
echo "  # 查看虚拟机列表"
echo "  multipass list"
echo ""
echo "  # 停止虚拟机"
echo "  multipass stop $VM_NAME"
echo ""
echo "  # 删除虚拟机"
echo "  multipass delete $VM_NAME"
echo "  multipass purge"
echo ""

# 询问是否清理
read -p "是否立即删除测试虚拟机? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "正在清理..."
    multipass delete "$VM_NAME"
    multipass purge
    echo -e "${GREEN}✓ 测试虚拟机已删除${NC}"
else
    echo "虚拟机 '$VM_NAME' 已保留,请手动清理"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo -e "${GREEN}测试完成!${NC}"
echo "════════════════════════════════════════════════════════════════"
