#!/bin/bash

################################################################################
# CentOS SSH 登录配置脚本
# 功能: 自动配置 SSH 密钥,实现 ssh ubuntu@IP 直接登录
################################################################################

VM_NAME="${1:-centos-official}"
VM_IP="${2:-192.168.252.3}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  CentOS SSH 登录配置向导                                                       ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "虚拟机名称: ${VM_NAME}"
echo "虚拟机 IP: ${VM_IP}"
echo ""

# 1. 检查虚拟机状态
echo -e "${BLUE}═══ 1. 检查虚拟机状态 ═══${NC}"
STATE=$(mp list | grep "${VM_NAME}" | awk '{print $2}')
if [ "$STATE" != "Running" ]; then
    echo -e "${RED}✗ 虚拟机未运行 (状态: ${STATE})${NC}"
    echo ""
    echo "请先启动虚拟机:"
    echo "  mp start ${VM_NAME}"
    exit 1
fi
echo -e "${GREEN}✓ 虚拟机正在运行${NC}"
echo ""

# 2. 检查 SSH 密钥
echo -e "${BLUE}═══ 2. 检查本地 SSH 密钥 ═══${NC}"
if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo -e "${YELLOW}⚠ 未找到 SSH 密钥,正在生成...${NC}"
    ssh-keygen -t ed25519 -C "multipass-${VM_NAME}" -f ~/.ssh/id_ed25519 -N ""
    echo -e "${GREEN}✓ SSH 密钥已生成${NC}"
else
    echo -e "${GREEN}✓ SSH 密钥已存在${NC}"
fi
echo ""

# 3. 获取公钥
PUB_KEY=$(cat ~/.ssh/id_ed25519.pub)
echo -e "${BLUE}═══ 3. 读取公钥 ═══${NC}"
echo "${PUB_KEY:0:60}..."
echo ""

# 4. 配置虚拟机
echo -e "${BLUE}═══ 4. 配置虚拟机 SSH ═══${NC}"

# 创建 .ssh 目录
echo "创建 .ssh 目录..."
mp exec "${VM_NAME}" -- bash -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ .ssh 目录已创建${NC}"
else
    echo -e "${RED}✗ 无法创建 .ssh 目录${NC}"
    exit 1
fi

# 添加公钥
echo "添加公钥到 authorized_keys..."
mp exec "${VM_NAME}" -- bash -c "echo '${PUB_KEY}' >> ~/.ssh/authorized_keys" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 公钥已添加${NC}"
else
    echo -e "${RED}✗ 无法添加公钥${NC}"
    exit 1
fi

# 设置权限
echo "设置文件权限..."
mp exec "${VM_NAME}" -- bash -c "chmod 600 ~/.ssh/authorized_keys" 2>/dev/null
echo -e "${GREEN}✓ 权限已设置${NC}"
echo ""

# 5. 测试连接
echo -e "${BLUE}═══ 5. 测试 SSH 连接 ═══${NC}"
echo "尝试连接 ubuntu@${VM_IP}..."

# 移除旧的 known_hosts 条目
ssh-keygen -R "${VM_IP}" 2>/dev/null

# 测试连接
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@${VM_IP} "whoami" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ SSH 连接成功!${NC}"
else
    echo -e "${YELLOW}⚠ 直接 SSH 连接失败,但 multipass shell 仍然可用${NC}"
fi
echo ""

# 6. 配置完成
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  配置完成                                                                      ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}✓ SSH 密钥已配置完成!${NC}"
echo ""

echo "现在您可以使用以下方式登录:"
echo ""

echo -e "${BLUE}方法 1: 使用 multipass shell (推荐)${NC}"
echo "  mp shell ${VM_NAME}"
echo ""

echo -e "${BLUE}方法 2: 使用 SSH 直接登录${NC}"
echo "  ssh ubuntu@${VM_IP}"
echo ""

echo -e "${BLUE}方法 3: 执行命令${NC}"
echo "  mp exec ${VM_NAME} -- sudo yum install -y nginx"
echo "  ssh ubuntu@${VM_IP} 'sudo systemctl status sshd'"
echo ""

echo -e "${BLUE}方法 4: 切换到 root${NC}"
echo "  mp shell ${VM_NAME}"
echo "  sudo su -"
echo ""

echo -e "${YELLOW}提示: 如果需要 root SSH 登录,请参考 CENTOS_SSH_LOGIN_GUIDE.md${NC}"
echo ""
