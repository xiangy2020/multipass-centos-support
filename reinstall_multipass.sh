#!/bin/bash
################################################################################
# Multipass 完全清理和重装脚本
# 清理旧版本,使用 Git 仓库中修改过的版本
################################################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Multipass 完全清理和重装                                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 1. 强制停止所有 QEMU 进程
echo -e "${BLUE}[1/8]${NC} 强制停止所有虚拟机进程..."
QEMU_PIDS=$(ps aux | grep qemu-system | grep -v grep | awk '{print $2}')
if [ -n "$QEMU_PIDS" ]; then
    echo "  发现 QEMU 进程: $QEMU_PIDS"
    echo "  需要 sudo 权限来停止进程..."
    for pid in $QEMU_PIDS; do
        sudo kill -9 $pid 2>/dev/null || true
    done
    echo -e "${GREEN}  ✓ QEMU 进程已停止${NC}"
else
    echo -e "${GREEN}  ✓ 没有运行的 QEMU 进程${NC}"
fi
echo ""

# 2. 停止 multipassd 服务
echo -e "${BLUE}[2/8]${NC} 停止 Multipass 守护进程..."
MULTIPASSD_PID=$(ps aux | grep multipassd | grep -v grep | awk '{print $2}')
if [ -n "$MULTIPASSD_PID" ]; then
    echo "  发现 multipassd 进程: $MULTIPASSD_PID"
    sudo kill -9 $MULTIPASSD_PID 2>/dev/null || true
    echo -e "${GREEN}  ✓ multipassd 进程已停止${NC}"
else
    echo -e "${GREEN}  ✓ multipassd 未运行${NC}"
fi
echo ""

# 3. 卸载 Multipass
echo -e "${BLUE}[3/8]${NC} 卸载 Multipass..."
if brew list multipass &>/dev/null; then
    echo "  通过 Homebrew 卸载..."
    brew uninstall --cask multipass --force || true
    echo -e "${GREEN}  ✓ Multipass 已卸载${NC}"
else
    echo -e "${YELLOW}  Multipass 未通过 Homebrew 安装${NC}"
fi
echo ""

# 4. 清理残留文件
echo -e "${BLUE}[4/8]${NC} 清理残留文件..."
echo "  需要 sudo 权限来删除系统文件..."

# 清理应用程序
sudo rm -rf "/Applications/Multipass.app" 2>/dev/null || true

# 清理系统支持文件
sudo rm -rf "/Library/Application Support/com.canonical.multipass" 2>/dev/null || true

# 清理启动项
sudo rm -f "/Library/LaunchDaemons/com.canonical.multipassd.plist" 2>/dev/null || true

# 清理用户数据
rm -rf ~/Library/Application\ Support/multipass 2>/dev/null || true
rm -rf ~/Library/Preferences/multipass 2>/dev/null || true
rm -rf ~/Library/Caches/multipass 2>/dev/null || true

# 清理 root 用户数据
sudo rm -rf /var/root/Library/Application\ Support/multipassd 2>/dev/null || true

# 清理 Homebrew 缓存
rm -rf /opt/homebrew/Caskroom/multipass 2>/dev/null || true

echo -e "${GREEN}  ✓ 残留文件已清理${NC}"
echo ""

# 5. 检查 Git 仓库中的 multipass
echo -e "${BLUE}[5/8]${NC} 检查 Git 仓库..."
REPO_DIR="/Users/tompyang/WorkBuddy/20260320161009"
MULTIPASS_SRC="${REPO_DIR}/multipass"

if [ -d "$MULTIPASS_SRC" ]; then
    echo -e "${GREEN}  ✓ 找到 multipass 源码: $MULTIPASS_SRC${NC}"
    
    # 检查修改过的配置文件
    if [ -f "$MULTIPASS_SRC/data/distributions/distribution-info.json" ]; then
        echo -e "${GREEN}  ✓ 找到配置文件: distribution-info.json${NC}"
    else
        echo -e "${RED}  ✗ 配置文件不存在${NC}"
    fi
else
    echo -e "${RED}  ✗ multipass 源码不存在: $MULTIPASS_SRC${NC}"
    exit 1
fi
echo ""

# 6. 重新安装 Multipass (官方版本)
echo -e "${BLUE}[6/8]${NC} 重新安装 Multipass..."
echo "  从 Homebrew 安装最新版本..."
brew install --cask multipass
echo -e "${GREEN}  ✓ Multipass 安装完成${NC}"
echo ""

# 7. 等待服务启动
echo -e "${BLUE}[7/8]${NC} 等待服务启动..."
sleep 5
multipass version
echo -e "${GREEN}  ✓ Multipass 服务正常${NC}"
echo ""

# 8. 应用修改过的配置
echo -e "${BLUE}[8/8]${NC} 应用 CentOS 支持配置..."

# 检查配置目录
CONFIG_DIRS=(
    "/var/snap/multipass/common/data/distributions"
    "/Library/Application Support/com.canonical.multipass/data/distributions"
    "$HOME/Library/Application Support/multipass/data/distributions"
)

INSTALLED=false
for CONFIG_DIR in "${CONFIG_DIRS[@]}"; do
    if [ -d "$(dirname $CONFIG_DIR)" ]; then
        echo "  找到配置目录: $CONFIG_DIR"
        sudo mkdir -p "$CONFIG_DIR" 2>/dev/null || mkdir -p "$CONFIG_DIR"
        
        # 复制配置文件
        if sudo cp "$MULTIPASS_SRC/data/distributions/distribution-info.json" "$CONFIG_DIR/" 2>/dev/null; then
            echo -e "${GREEN}  ✓ 配置文件已复制到: $CONFIG_DIR${NC}"
            INSTALLED=true
        elif cp "$MULTIPASS_SRC/data/distributions/distribution-info.json" "$CONFIG_DIR/" 2>/dev/null; then
            echo -e "${GREEN}  ✓ 配置文件已复制到: $CONFIG_DIR${NC}"
            INSTALLED=true
        fi
    fi
done

if [ "$INSTALLED" = false ]; then
    echo -e "${YELLOW}  注意: 未找到合适的配置目录,可能需要重新编译 Multipass${NC}"
fi
echo ""

# 重启 Multipass 服务
echo -e "${BLUE}重启 Multipass 服务...${NC}"
sudo launchctl unload /Library/LaunchDaemons/com.canonical.multipassd.plist 2>/dev/null || true
sleep 2
sudo launchctl load /Library/LaunchDaemons/com.canonical.multipassd.plist 2>/dev/null || true
sleep 3

# 9. 验证
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  清理和重装完成!                                              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}下一步:${NC}"
echo "  1. 测试 CentOS 支持:"
echo "     multipass find | grep -i centos"
echo ""
echo "  2. 如果看不到 CentOS,则需要从源码编译 Multipass"
echo "     cd $MULTIPASS_SRC"
echo "     # 按照 DEPLOYMENT_GUIDE.md 中的说明编译"
echo ""
echo "  3. 或者直接使用已下载的镜像:"
echo "     multipass launch file://~/multipass-images/CentOS-Stream-9.qcow2 --name centos-1"
echo ""
