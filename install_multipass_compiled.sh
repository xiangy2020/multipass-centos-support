#!/bin/bash

################################################################################
# 编译版 Multipass 安装脚本
# 功能:
#   1. 自动启动 multipassd 守护进程
#   2. 添加环境变量到 shell 配置
#   3. 创建便捷启动脚本
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 路径定义
MULTIPASS_BUILD_DIR="/Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin"
MULTIPASS_BIN="${MULTIPASS_BUILD_DIR}/multipass"
MULTIPASSD_BIN="${MULTIPASS_BUILD_DIR}/multipassd"
QEMU_BIN="${MULTIPASS_BUILD_DIR}/qemu-system-aarch64"

# 安装目录
INSTALL_DIR="/usr/local/bin"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  编译版 Multipass 安装与配置工具                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

################################################################################
# 步骤 1: 验证文件
################################################################################

echo -e "${BLUE}═══ 步骤 1: 验证编译文件 ═══${NC}"
echo ""

if [ ! -f "${MULTIPASS_BIN}" ]; then
    echo -e "${RED}✗ multipass 未找到: ${MULTIPASS_BIN}${NC}"
    exit 1
fi

if [ ! -f "${MULTIPASSD_BIN}" ]; then
    echo -e "${RED}✗ multipassd 未找到: ${MULTIPASSD_BIN}${NC}"
    exit 1
fi

if [ ! -f "${QEMU_BIN}" ]; then
    echo -e "${RED}✗ qemu-system-aarch64 未找到: ${QEMU_BIN}${NC}"
    exit 1
fi

echo -e "${GREEN}✓ multipass 可执行文件验证成功${NC}"
echo -e "${GREEN}✓ multipassd 守护进程验证成功${NC}"
echo -e "${GREEN}✓ qemu-system-aarch64 验证成功${NC}"
echo ""

################################################################################
# 步骤 2: 停止旧的 multipassd 进程
################################################################################

echo -e "${BLUE}═══ 步骤 2: 清理旧进程 ═══${NC}"
echo ""

OLD_PIDS=$(pgrep -f multipassd || true)
if [ -n "${OLD_PIDS}" ]; then
    echo "发现运行中的 multipassd 进程: ${OLD_PIDS}"
    echo "正在停止..."
    pkill -f multipassd || true
    sleep 2
    echo -e "${GREEN}✓ 旧进程已停止${NC}"
else
    echo -e "${GREEN}✓ 没有运行中的 multipassd 进程${NC}"
fi
echo ""

################################################################################
# 步骤 3: 创建启动脚本
################################################################################

echo -e "${BLUE}═══ 步骤 3: 创建启动脚本 ═══${NC}"
echo ""

# 创建 multipassd 启动脚本
cat > /tmp/start_multipassd.sh << 'SCRIPT_EOF'
#!/bin/bash

# multipassd 守护进程启动脚本
MULTIPASSD_BIN="/Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin/multipassd"
LOG_DIR="${HOME}/.multipass/logs"
LOG_FILE="${LOG_DIR}/multipassd.log"

# 创建日志目录
mkdir -p "${LOG_DIR}"

# 检查是否已运行
if pgrep -f multipassd > /dev/null; then
    echo "✓ multipassd 已在运行"
    exit 0
fi

# 启动 multipassd
echo "启动 multipassd..."
nohup "${MULTIPASSD_BIN}" > "${LOG_FILE}" 2>&1 &

# 等待启动
sleep 2

# 验证
if pgrep -f multipassd > /dev/null; then
    echo "✓ multipassd 启动成功 (PID: $(pgrep -f multipassd))"
    echo "  日志文件: ${LOG_FILE}"
else
    echo "✗ multipassd 启动失败"
    echo "  查看日志: cat ${LOG_FILE}"
    exit 1
fi
SCRIPT_EOF

sudo cp /tmp/start_multipassd.sh "${INSTALL_DIR}/start_multipassd"
sudo chmod +x "${INSTALL_DIR}/start_multipassd"
echo -e "${GREEN}✓ 启动脚本已创建: ${INSTALL_DIR}/start_multipassd${NC}"
echo ""

################################################################################
# 步骤 4: 创建符号链接
################################################################################

echo -e "${BLUE}═══ 步骤 4: 创建全局命令 ═══${NC}"
echo ""

# 创建 multipass 符号链接
if [ -L "${INSTALL_DIR}/multipass-compiled" ]; then
    sudo rm "${INSTALL_DIR}/multipass-compiled"
fi
sudo ln -sf "${MULTIPASS_BIN}" "${INSTALL_DIR}/multipass-compiled"
echo -e "${GREEN}✓ 创建命令: multipass-compiled${NC}"

# 创建 qemu 符号链接
if [ -L "${INSTALL_DIR}/qemu-aarch64-compiled" ]; then
    sudo rm "${INSTALL_DIR}/qemu-aarch64-compiled"
fi
sudo ln -sf "${QEMU_BIN}" "${INSTALL_DIR}/qemu-aarch64-compiled"
echo -e "${GREEN}✓ 创建命令: qemu-aarch64-compiled${NC}"
echo ""

################################################################################
# 步骤 5: 添加环境变量
################################################################################

echo -e "${BLUE}═══ 步骤 5: 配置环境变量 ═══${NC}"
echo ""

# 检测 shell
SHELL_NAME=$(basename "${SHELL}")
if [ "${SHELL_NAME}" = "zsh" ]; then
    SHELL_RC="${HOME}/.zshrc"
elif [ "${SHELL_NAME}" = "bash" ]; then
    SHELL_RC="${HOME}/.bash_profile"
else
    SHELL_RC="${HOME}/.profile"
fi

# 添加环境变量配置
ENV_CONFIG="
# Multipass 编译版配置 (自动添加)
export MULTIPASS_BUILD_DIR=\"${MULTIPASS_BUILD_DIR}\"
export PATH=\"\${MULTIPASS_BUILD_DIR}:\${PATH}\"

# Multipass 别名
alias mp='multipass-compiled'
alias mpd='start_multipassd'
alias mp-start='start_multipassd && sleep 2 && multipass-compiled list'
alias mp-stop='pkill -f multipassd'
alias mp-log='tail -f \${HOME}/.multipass/logs/multipassd.log'
"

# 检查是否已添加
if grep -q "MULTIPASS_BUILD_DIR" "${SHELL_RC}" 2>/dev/null; then
    echo -e "${YELLOW}⚠ 环境变量已存在于 ${SHELL_RC}${NC}"
    echo "是否覆盖? (y/N): "
    read -r CONFIRM
    if [ "${CONFIRM}" = "y" ] || [ "${CONFIRM}" = "Y" ]; then
        # 删除旧配置
        sed -i.bak '/# Multipass 编译版配置/,/^$/d' "${SHELL_RC}"
        echo "${ENV_CONFIG}" >> "${SHELL_RC}"
        echo -e "${GREEN}✓ 环境变量已更新${NC}"
    fi
else
    echo "${ENV_CONFIG}" >> "${SHELL_RC}"
    echo -e "${GREEN}✓ 环境变量已添加到 ${SHELL_RC}${NC}"
fi
echo ""

################################################################################
# 步骤 6: 创建 LaunchAgent (可选)
################################################################################

echo -e "${BLUE}═══ 步骤 6: 配置自动启动 (可选) ═══${NC}"
echo ""
echo "是否配置 multipassd 开机自动启动? (y/N): "
read -r AUTO_START

if [ "${AUTO_START}" = "y" ] || [ "${AUTO_START}" = "Y" ]; then
    mkdir -p "${LAUNCH_AGENTS_DIR}"
    
    cat > "${LAUNCH_AGENTS_DIR}/com.canonical.multipassd.plist" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.canonical.multipassd</string>
    <key>ProgramArguments</key>
    <array>
        <string>${MULTIPASSD_BIN}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/.multipass/logs/multipassd.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/.multipass/logs/multipassd.error.log</string>
</dict>
</plist>
PLIST_EOF
    
    # 加载 LaunchAgent
    launchctl unload "${LAUNCH_AGENTS_DIR}/com.canonical.multipassd.plist" 2>/dev/null || true
    launchctl load "${LAUNCH_AGENTS_DIR}/com.canonical.multipassd.plist"
    
    echo -e "${GREEN}✓ 开机自动启动已配置${NC}"
    echo "  - 取消自动启动: launchctl unload ${LAUNCH_AGENTS_DIR}/com.canonical.multipassd.plist"
else
    echo -e "${YELLOW}⊘ 跳过自动启动配置${NC}"
fi
echo ""

################################################################################
# 步骤 7: 启动 multipassd
################################################################################

echo -e "${BLUE}═══ 步骤 7: 启动 multipassd ═══${NC}"
echo ""

start_multipassd

echo ""

################################################################################
# 步骤 8: 验证安装
################################################################################

echo -e "${BLUE}═══ 步骤 8: 验证安装 ═══${NC}"
echo ""

# 检查 multipassd 进程
if pgrep -f multipassd > /dev/null; then
    MULTIPASSD_PID=$(pgrep -f multipassd)
    echo -e "${GREEN}✓ multipassd 运行中 (PID: ${MULTIPASSD_PID})${NC}"
else
    echo -e "${RED}✗ multipassd 未运行${NC}"
fi

# 测试 multipass 命令
if multipass-compiled version > /dev/null 2>&1; then
    echo -e "${GREEN}✓ multipass-compiled 命令可用${NC}"
else
    echo -e "${RED}✗ multipass-compiled 命令不可用${NC}"
fi

# 列出虚拟机
echo ""
echo "当前虚拟机列表:"
multipass-compiled list || echo "无虚拟机或连接失败"
echo ""

################################################################################
# 完成
################################################################################

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ✅ 安装完成!                                                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo -e "${GREEN}═══ 可用命令 ═══${NC}"
echo ""
echo "  ${BLUE}multipass-compiled${NC}    - Multipass 主命令 (避免与官方版冲突)"
echo "  ${BLUE}start_multipassd${NC}      - 启动 multipassd 守护进程"
echo "  ${BLUE}mp${NC}                    - multipass-compiled 别名"
echo "  ${BLUE}mpd${NC}                   - start_multipassd 别名"
echo "  ${BLUE}mp-start${NC}              - 启动守护进程并列出虚拟机"
echo "  ${BLUE}mp-stop${NC}               - 停止 multipassd"
echo "  ${BLUE}mp-log${NC}                - 查看 multipassd 日志"
echo ""

echo -e "${GREEN}═══ 使用示例 ═══${NC}"
echo ""
echo "  # 启动守护进程"
echo "  ${BLUE}mp-start${NC}"
echo ""
echo "  # 列出虚拟机"
echo "  ${BLUE}mp list${NC}"
echo ""
echo "  # 启动虚拟机"
echo "  ${BLUE}mp launch ubuntu --name test${NC}"
echo ""
echo "  # 查看日志"
echo "  ${BLUE}mp-log${NC}"
echo ""

echo -e "${YELLOW}⚠ 注意: 需要重新加载 shell 配置 ⚠${NC}"
echo ""
echo "  执行以下命令之一:"
echo "  ${BLUE}source ${SHELL_RC}${NC}"
echo "  ${BLUE}exec \${SHELL}${NC}"
echo "  或重新打开终端"
echo ""

echo -e "${GREEN}═══ 相关文件 ═══${NC}"
echo ""
echo "  编译目录: ${MULTIPASS_BUILD_DIR}"
echo "  守护进程: ${MULTIPASSD_BIN}"
echo "  启动脚本: ${INSTALL_DIR}/start_multipassd"
echo "  配置文件: ${SHELL_RC}"
echo "  日志目录: ${HOME}/.multipass/logs"
if [ "${AUTO_START}" = "y" ] || [ "${AUTO_START}" = "Y" ]; then
    echo "  自动启动: ${LAUNCH_AGENTS_DIR}/com.canonical.multipassd.plist"
fi
echo ""

echo "🎉 完成!"
