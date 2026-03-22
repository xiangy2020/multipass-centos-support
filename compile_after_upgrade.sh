#!/bin/bash
# 升级完成后自动编译脚本
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Multipass 编译脚本 (升级后执行)                              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 验证编译器版本
echo -e "${BLUE}[1/5]${NC} 验证编译器版本..."
CLANG_VERSION=$(clang++ --version | head -1)
echo "  $CLANG_VERSION"

if echo "$CLANG_VERSION" | grep -q "version 14\."; then
    echo -e "${RED}  ✗ 仍然是旧版本 14.x${NC}"
    echo ""
    echo -e "${YELLOW}请先执行升级命令:${NC}"
    echo "  sudo softwareupdate --install 'Command Line Tools for Xcode-16.2'"
    echo ""
    exit 1
elif echo "$CLANG_VERSION" | grep -qE "version (15\.|16\.)"; then
    echo -e "${GREEN}  ✓ 已升级到新版本${NC}"
else
    echo -e "${YELLOW}  ! 无法确定版本,继续尝试编译...${NC}"
fi
echo ""

# 测试 source_location 支持
echo -e "${BLUE}[2/5]${NC} 测试 C++20 source_location 支持..."
if echo '#include <source_location>' | clang++ -std=c++20 -x c++ - -fsyntax-only 2>/dev/null; then
    echo -e "${GREEN}  ✓ source_location 支持正常${NC}"
else
    echo -e "${RED}  ✗ 仍然不支持 source_location${NC}"
    echo ""
    echo "可能的原因:"
    echo "1. CommandLineTools 未正确升级"
    echo "2. 需要完全删除旧版本后重装"
    echo ""
    echo "建议执行:"
    echo "  sudo rm -rf /Library/Developer/CommandLineTools"
    echo "  xcode-select --install"
    echo ""
    exit 1
fi
echo ""

# 清理旧构建
echo -e "${BLUE}[3/5]${NC} 清理旧构建..."
cd /Users/tompyang/WorkBuddy/20260320161009/multipass/build
ninja clean || true
echo -e "${GREEN}  ✓ 清理完成${NC}"
echo ""

# 开始编译
echo -e "${BLUE}[4/5]${NC} 开始编译 Multipass..."
echo "  这将需要 10-20 分钟..."
echo "  启动时间: $(date)"
echo ""

START_TIME=$(date +%s)

if ninja; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ 编译成功!                                                  ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "完成时间: $(date)"
    echo "耗时: ${MINUTES}分${SECONDS}秒"
    echo ""
else
    echo ""
    echo -e "${RED}编译失败,请查看错误信息${NC}"
    exit 1
fi

# 提示安装
echo -e "${BLUE}[5/5]${NC} 准备安装..."
echo ""
echo -e "${YELLOW}现在需要安装编译好的 Multipass (需要 sudo 权限):${NC}"
echo ""
echo -e "${GREEN}  sudo ninja install${NC}"
echo ""
read -p "是否现在安装? (y/n): " answer

if [ "$answer" = "y" ]; then
    echo ""
    echo "开始安装..."
    if sudo ninja install; then
        echo ""
        echo -e "${GREEN}✓ 安装成功!${NC}"
        echo ""
        echo "验证安装:"
        multipass version
        echo ""
        echo "检查 CentOS 支持:"
        multipass find | grep -i centos || echo "(CentOS 可能不在默认列表,但可以使用本地镜像)"
        echo ""
        echo -e "${YELLOW}接下来可以测试 CentOS 集群:${NC}"
        echo ""
        echo "  cd /Users/tompyang/WorkBuddy/20260320161009"
        echo "  ./auto_test_centos.sh"
        echo ""
    else
        echo -e "${RED}安装失败${NC}"
        exit 1
    fi
else
    echo ""
    echo "稍后手动安装:"
    echo "  cd /Users/tompyang/WorkBuddy/20260320161009/multipass/build"
    echo "  sudo ninja install"
fi
