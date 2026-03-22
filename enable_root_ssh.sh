#!/bin/bash

################################################################################
# CentOS 启用 Root SSH 登录配置脚本
# 功能: 启用 root 用户 SSH 登录并设置密码
# 警告: 这会降低安全性，仅建议用于测试环境
################################################################################

VM_NAME="${1:-centos-official}"
ROOT_PASSWORD="${2:-root123}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  启用 Root SSH 登录配置向导                                                    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}⚠️  安全警告${NC}"
echo "   启用 root SSH 登录会降低系统安全性"
echo "   建议仅在测试环境中使用"
echo ""
echo "虚拟机: ${VM_NAME}"
echo "Root 密码: ${ROOT_PASSWORD}"
echo ""

# 等待确认
read -p "是否继续? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 0
fi
echo ""

# 1. 检查虚拟机状态
echo -e "${BLUE}═══ 1. 检查虚拟机状态 ═══${NC}"
STATE=$(mp list | grep "${VM_NAME}" | awk '{print $2}')
if [ "$STATE" != "Running" ]; then
    echo -e "${RED}✗ 虚拟机未运行 (状态: ${STATE})${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 虚拟机正在运行${NC}"
echo ""

# 2. 备份 SSH 配置
echo -e "${BLUE}═══ 2. 备份 SSH 配置 ═══${NC}"
mp exec "${VM_NAME}" -- sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
echo -e "${GREEN}✓ 配置已备份到 /etc/ssh/sshd_config.backup${NC}"
echo ""

# 3. 修改 SSH 配置
echo -e "${BLUE}═══ 3. 修改 SSH 配置 ═══${NC}"

# 启用 root 登录
echo "启用 PermitRootLogin..."
mp exec "${VM_NAME}" -- sudo bash -c "sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config"
mp exec "${VM_NAME}" -- sudo bash -c "grep -q '^PermitRootLogin' /etc/ssh/sshd_config || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config"
echo -e "${GREEN}✓ PermitRootLogin 已设置为 yes${NC}"

# 启用密码认证
echo "启用 PasswordAuthentication..."
mp exec "${VM_NAME}" -- sudo bash -c "sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config"
mp exec "${VM_NAME}" -- sudo bash -c "grep -q '^PasswordAuthentication' /etc/ssh/sshd_config || echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config"
echo -e "${GREEN}✓ PasswordAuthentication 已设置为 yes${NC}"
echo ""

# 4. 显示修改后的配置
echo -e "${BLUE}═══ 4. 验证配置 ═══${NC}"
echo "当前 SSH 配置:"
mp exec "${VM_NAME}" -- sudo grep -E "^PermitRootLogin|^PasswordAuthentication" /etc/ssh/sshd_config
echo ""

# 5. 设置 root 密码
echo -e "${BLUE}═══ 5. 设置 root 密码 ═══${NC}"
mp exec "${VM_NAME}" -- sudo bash -c "echo 'root:${ROOT_PASSWORD}' | chpasswd"
echo -e "${GREEN}✓ Root 密码已设置为: ${ROOT_PASSWORD}${NC}"
echo ""

# 6. 重启 SSH 服务
echo -e "${BLUE}═══ 6. 重启 SSH 服务 ═══${NC}"
mp exec "${VM_NAME}" -- sudo systemctl restart sshd
sleep 2

# 检查服务状态
if mp exec "${VM_NAME}" -- sudo systemctl is-active sshd | grep -q "active"; then
    echo -e "${GREEN}✓ SSH 服务已重启${NC}"
else
    echo -e "${RED}✗ SSH 服务重启失败${NC}"
    exit 1
fi
echo ""

# 7. 获取 IP 地址
echo -e "${BLUE}═══ 7. 获取虚拟机 IP ═══${NC}"
VM_IP=$(mp info "${VM_NAME}" | grep "IPv4:" | awk '{print $2}' | head -1)
if [ -z "$VM_IP" ]; then
    echo -e "${RED}✗ 无法获取 IP 地址${NC}"
    exit 1
fi
echo -e "${GREEN}✓ IP 地址: ${VM_IP}${NC}"
echo ""

# 8. 配置完成
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  配置完成                                                                      ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}✓ Root SSH 登录已启用!${NC}"
echo ""

echo "现在您可以使用以下方式登录:"
echo ""

echo -e "${BLUE}═══ 方法 1: SSH 密码登录 ═══${NC}"
echo "  ssh root@${VM_IP}"
echo "  密码: ${ROOT_PASSWORD}"
echo ""

echo -e "${BLUE}═══ 方法 2: 使用 sshpass 自动登录 ═══${NC}"
echo "  # 安装 sshpass (如果需要)"
echo "  brew install sshpass"
echo ""
echo "  # 自动登录"
echo "  sshpass -p '${ROOT_PASSWORD}' ssh -o StrictHostKeyChecking=no root@${VM_IP}"
echo ""

echo -e "${BLUE}═══ 方法 3: 配置 SSH 密钥 (推荐) ═══${NC}"
echo "  # 复制公钥到 root 用户"
echo "  ssh-copy-id -i ~/.ssh/id_ed25519.pub root@${VM_IP}"
echo "  密码: ${ROOT_PASSWORD}"
echo ""
echo "  # 之后可以免密登录"
echo "  ssh root@${VM_IP}"
echo ""

echo -e "${BLUE}═══ 测试命令 ═══${NC}"
echo "  ssh root@${VM_IP}"
echo ""

echo -e "${YELLOW}⚠️  安全提示:${NC}"
echo "   1. 请及时修改 root 密码"
echo "   2. 建议配置 SSH 密钥后禁用密码认证"
echo "   3. 生产环境不建议启用 root SSH 登录"
echo ""

echo -e "${BLUE}═══ 恢复到安全配置 ═══${NC}"
echo "如需恢复安全配置,执行:"
echo "  mp exec ${VM_NAME} -- sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config"
echo "  mp exec ${VM_NAME} -- sudo systemctl restart sshd"
echo ""

# 9. 测试连接
echo -e "${BLUE}═══ 9. 测试连接 ═══${NC}"
echo "移除旧的 known_hosts 条目..."
ssh-keygen -R "${VM_IP}" 2>/dev/null

echo ""
echo "请在新终端中测试以下命令:"
echo ""
echo -e "${GREEN}  ssh root@${VM_IP}${NC}"
echo -e "  密码: ${YELLOW}${ROOT_PASSWORD}${NC}"
echo ""
