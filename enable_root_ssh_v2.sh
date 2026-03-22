#!/bin/bash

################################################################################
# CentOS 启用 Root SSH 登录配置脚本 V2 (改进版)
# 改进:
#   1. 使用配置片段而不是修改主配置文件
#   2. 每次修改后都验证配置语法
#   3. 使用 reload 而不是 restart (避免断开连接)
#   4. 失败时自动回滚
################################################################################

VM_NAME="${1:-centos-official}"
ROOT_PASSWORD="${2:-root123}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  启用 Root SSH 登录配置向导 V2 (改进版)                                        ║${NC}"
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
STATE=$(mp list 2>/dev/null | grep "^${VM_NAME}" | awk '{print $2}')
if [ "$STATE" != "Running" ]; then
    echo -e "${RED}✗ 虚拟机未运行 (状态: ${STATE})${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 虚拟机正在运行${NC}"
echo ""

# 2. 测试连接
echo -e "${BLUE}═══ 2. 测试虚拟机连接 ═══${NC}"
if ! mp exec "${VM_NAME}" -- echo "连接测试" >/dev/null 2>&1; then
    echo -e "${RED}✗ 无法连接到虚拟机${NC}"
    echo ""
    echo "建议:"
    echo "  1. 重启虚拟机: mp restart ${VM_NAME}"
    echo "  2. 如果无法重启，删除并重新创建"
    exit 1
fi
echo -e "${GREEN}✓ 虚拟机连接正常${NC}"
echo ""

# 3. 创建配置片段（不修改主配置文件）
echo -e "${BLUE}═══ 3. 创建 SSH 配置片段 ═══${NC}"

# 创建配置目录
mp exec "${VM_NAME}" -- sudo mkdir -p /etc/ssh/sshd_config.d 2>/dev/null

# 创建配置文件
cat > /tmp/99-root-login.conf << 'EOF'
# 启用 root SSH 登录 (自动生成)
PermitRootLogin yes
PasswordAuthentication yes
EOF

# 上传配置文件
mp transfer /tmp/99-root-login.conf "${VM_NAME}:/tmp/99-root-login.conf"

# 移动到正确位置
mp exec "${VM_NAME}" -- sudo mv /tmp/99-root-login.conf /etc/ssh/sshd_config.d/99-root-login.conf
mp exec "${VM_NAME}" -- sudo chmod 644 /etc/ssh/sshd_config.d/99-root-login.conf

echo -e "${GREEN}✓ 配置文件已创建${NC}"
echo ""

# 4. 验证配置语法
echo -e "${BLUE}═══ 4. 验证 SSH 配置语法 ═══${NC}"
if mp exec "${VM_NAME}" -- sudo sshd -t 2>&1 | tee /tmp/sshd_test.log; then
    echo -e "${GREEN}✓ SSH 配置语法正确${NC}"
else
    echo -e "${RED}✗ SSH 配置语法错误${NC}"
    echo ""
    cat /tmp/sshd_test.log
    echo ""
    echo "回滚配置..."
    mp exec "${VM_NAME}" -- sudo rm -f /etc/ssh/sshd_config.d/99-root-login.conf
    echo -e "${RED}✗ 配置失败，已回滚${NC}"
    exit 1
fi
echo ""

# 5. 显示当前配置
echo -e "${BLUE}═══ 5. 显示生效的配置 ═══${NC}"
echo "配置文件内容:"
mp exec "${VM_NAME}" -- sudo cat /etc/ssh/sshd_config.d/99-root-login.conf
echo ""

# 6. 设置 root 密码
echo -e "${BLUE}═══ 6. 设置 root 密码 ═══${NC}"
mp exec "${VM_NAME}" -- sudo bash -c "echo 'root:${ROOT_PASSWORD}' | chpasswd"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Root 密码已设置为: ${ROOT_PASSWORD}${NC}"
else
    echo -e "${RED}✗ 设置密码失败${NC}"
    exit 1
fi
echo ""

# 7. 重新加载 SSH 配置（使用 reload 而不是 restart）
echo -e "${BLUE}═══ 7. 重新加载 SSH 配置 ═══${NC}"
echo "使用 reload (平滑重启，不断开现有连接)..."

# 使用 reload
if mp exec "${VM_NAME}" -- sudo systemctl reload sshd 2>/dev/null; then
    echo -e "${GREEN}✓ SSH 配置已重新加载${NC}"
else
    echo -e "${YELLOW}⚠ reload 失败，尝试 restart...${NC}"
    
    # 如果 reload 失败，在后台 restart
    mp exec "${VM_NAME}" -- sudo bash -c "nohup systemctl restart sshd >/dev/null 2>&1 &"
    sleep 3
    
    # 检查服务状态
    if mp exec "${VM_NAME}" -- sudo systemctl is-active sshd 2>/dev/null | grep -q "active"; then
        echo -e "${GREEN}✓ SSH 服务已重启${NC}"
    else
        echo -e "${RED}✗ SSH 服务启动失败${NC}"
        echo ""
        echo "查看错误日志:"
        mp exec "${VM_NAME}" -- sudo journalctl -u sshd -n 20 --no-pager
        exit 1
    fi
fi
echo ""

# 8. 等待 SSH 服务完全启动
echo -e "${BLUE}═══ 8. 等待 SSH 服务就绪 ═══${NC}"
echo "等待 3 秒..."
sleep 3
echo -e "${GREEN}✓ SSH 服务应该已经就绪${NC}"
echo ""

# 9. 获取 IP 地址
echo -e "${BLUE}═══ 9. 获取虚拟机 IP ═══${NC}"
VM_IP=$(mp info "${VM_NAME}" 2>/dev/null | grep "IPv4:" | awk '{print $2}' | head -1)
if [ -z "$VM_IP" ]; then
    echo -e "${YELLOW}⚠ 无法自动获取 IP，请手动查看${NC}"
    echo "  mp info ${VM_NAME}"
    VM_IP="<IP地址>"
else
    echo -e "${GREEN}✓ IP 地址: ${VM_IP}${NC}"
fi
echo ""

# 10. 配置完成
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  配置完成                                                                      ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}✓ Root SSH 登录已成功启用!${NC}"
echo ""

echo "配置详情:"
echo "  - 配置文件: /etc/ssh/sshd_config.d/99-root-login.conf"
echo "  - PermitRootLogin: yes"
echo "  - PasswordAuthentication: yes"
echo "  - Root 密码: ${ROOT_PASSWORD}"
echo ""

echo "现在您可以使用以下方式登录:"
echo ""

echo -e "${BLUE}═══ 方法 1: SSH 密码登录 ═══${NC}"
if [ "$VM_IP" != "<IP地址>" ]; then
    echo "  ssh root@${VM_IP}"
    echo "  密码: ${ROOT_PASSWORD}"
    echo ""
    echo "  # 移除旧的 known_hosts 条目"
    echo "  ssh-keygen -R ${VM_IP}"
else
    echo "  ssh root@<IP地址>"
    echo "  密码: ${ROOT_PASSWORD}"
fi
echo ""

echo -e "${BLUE}═══ 方法 2: 配置 SSH 密钥 (推荐) ═══${NC}"
if [ "$VM_IP" != "<IP地址>" ]; then
    echo "  # 复制公钥"
    echo "  ssh-copy-id -i ~/.ssh/id_ed25519.pub root@${VM_IP}"
    echo "  密码: ${ROOT_PASSWORD}"
    echo ""
    echo "  # 免密登录"
    echo "  ssh root@${VM_IP}"
else
    echo "  ssh-copy-id -i ~/.ssh/id_ed25519.pub root@<IP地址>"
fi
echo ""

echo -e "${BLUE}═══ 回滚配置 ═══${NC}"
echo "如需禁用 root SSH 登录:"
echo "  mp exec ${VM_NAME} -- sudo rm /etc/ssh/sshd_config.d/99-root-login.conf"
echo "  mp exec ${VM_NAME} -- sudo systemctl reload sshd"
echo ""

echo -e "${YELLOW}⚠️  安全提示:${NC}"
echo "   1. 请及时修改 root 密码"
echo "   2. 强烈建议配置 SSH 密钥后禁用密码认证"
echo "   3. 生产环境不建议启用 root SSH 登录"
echo ""

# 11. 测试连接
if [ "$VM_IP" != "<IP地址>" ]; then
    echo -e "${BLUE}═══ 11. 准备测试连接 ═══${NC}"
    echo "移除旧的 known_hosts 条目..."
    ssh-keygen -R "${VM_IP}" 2>/dev/null
    echo ""
    echo "请在新终端中测试以下命令:"
    echo ""
    echo -e "${GREEN}  ssh root@${VM_IP}${NC}"
    echo -e "  密码: ${YELLOW}${ROOT_PASSWORD}${NC}"
    echo ""
fi

echo -e "${GREEN}🎉 配置脚本执行完成!${NC}"
