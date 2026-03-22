#!/bin/bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  升级 Xcode CommandLineTools 并完成 Multipass 编译          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 步骤1: 检查当前版本
echo -e "${BLUE}[1/4]${NC} 检查当前 CommandLineTools 版本..."
echo "  当前版本: $(clang++ --version | head -1)"
echo ""

# 步骤2: 升级 CommandLineTools
echo -e "${YELLOW}[2/4]${NC} 升级 CommandLineTools (需要sudo权限)..."
echo ""
echo -e "${YELLOW}可用版本:${NC}"
echo "  - Command Line Tools for Xcode 15.3 (707MB)"
echo "  - Command Line Tools for Xcode 16.2 (751MB) <- 推荐"
echo ""
echo -e "${YELLOW}请执行以下命令升级:${NC}"
echo ""
echo -e "${GREEN}  sudo softwareupdate --install 'Command Line Tools for Xcode-16.2'${NC}"
echo ""
echo "升级时间: 约5-10分钟"
echo ""
read -p "按回车键继续(升级完成后)..." dummy
echo ""

# 步骤3: 验证新版本
echo -e "${BLUE}[3/4]${NC} 验证新版本..."
clang++ --version
echo ""

# 检查是否支持 source_location
echo "测试 C++20 source_location 支持..."
cat > /tmp/test_source_location.cpp << 'EOF'
#include <source_location>
int main() { return 0; }
EOF

if clang++ -std=c++20 /tmp/test_source_location.cpp -o /tmp/test_source_location 2>/dev/null; then
    echo -e "${GREEN}  ✓ source_location 支持正常${NC}"
    rm /tmp/test_source_location*
else
    echo -e "${RED}  ✗ 仍然不支持 source_location${NC}"
    echo "  可能需要完全重装 Xcode CommandLineTools"
    exit 1
fi
echo ""

# 步骤4: 重新编译
echo -e "${BLUE}[4/4]${NC} 重新编译 Multipass..."
cd /Users/tompyang/WorkBuddy/20260320161009/multipass/build

echo "  清理之前的构建..."
ninja clean || true

echo "  开始编译 (这将需要10-20分钟)..."
echo "  启动时间: $(date)"
echo ""

if ninja; then
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ 编译成功!                                                  ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "完成时间: $(date)"
    echo ""
    echo "接下来需要安装编译好的 Multipass:"
    echo ""
    echo -e "${YELLOW}  sudo ninja install${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}编译失败,请查看错误信息${NC}"
    exit 1
fi
