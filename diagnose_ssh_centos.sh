#!/bin/bash

################################################################################
# CentOS SSH 登录问题诊断和修复脚本
################################################################################

VM_NAME="${1:-centos-official}"
VM_IP="192.168.252.3"

echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
echo "║  CentOS SSH 登录问题诊断                                                       ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
echo ""

echo "虚拟机: ${VM_NAME}"
echo "IP: ${VM_IP}"
echo ""

# 1. 检查虚拟机状态
echo "═══ 1. 检查虚拟机状态 ═══"
mp info "${VM_NAME}" | head -10
echo ""

# 2. 检查当前用户
echo "═══ 2. 检查默认用户 ═══"
mp exec "${VM_NAME}" -- whoami
echo ""

# 3. 获取 root 权限测试
echo "═══ 3. 测试 sudo 权限 ═══"
mp exec "${VM_NAME}" -- sudo whoami
echo ""

# 4. 查看用户列表
echo "═══ 4. 查看系统用户 ═══"
mp exec "${VM_NAME}" -- cat /etc/passwd | grep -E "root:|ubuntu:|centos:"
echo ""

# 5. 检查 SSH 配置
echo "═══ 5. 检查 SSH 配置 ═══"
mp exec "${VM_NAME}" -- sudo cat /etc/ssh/sshd_config | grep "^PermitRootLogin"
mp exec "${VM_NAME}" -- sudo cat /etc/ssh/sshd_config | grep "^PasswordAuthentication"
mp exec "${VM_NAME}" -- sudo cat /etc/ssh/sshd_config | grep "^PubkeyAuthentication"
echo ""

# 6. 检查 authorized_keys
echo "═══ 6. 检查 authorized_keys ═══"
mp exec "${VM_NAME}" -- ls -la ~/.ssh/
mp exec "${VM_NAME}" -- wc -l ~/.ssh/authorized_keys
echo ""

# 7. 检查 root 用户的 SSH 配置
echo "═══ 7. 检查 root 用户 SSH 配置 ═══"
mp exec "${VM_NAME}" -- sudo ls -la /root/.ssh/ 2>/dev/null || echo "root 用户没有 .ssh 目录"
echo ""

echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
echo "║  诊断完成                                                                      ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
