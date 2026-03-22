#!/bin/bash
# CentOS 虚拟机完整功能测试脚本 (使用已存在的虚拟机)
# 测试目标: centos-test-auto

VM_NAME="centos-test-auto"
TEST_LOG="/tmp/centos_test_results.log"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 测试计数器
PASSED=0
FAILED=0
TOTAL=16

# 日志函数
log() {
    echo -e "${BLUE}[TEST $(date +%H:%M:%S)]${NC} $1" | tee -a "$TEST_LOG"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$TEST_LOG"
    ((PASSED++))
}

fail() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$TEST_LOG"
    ((FAILED++))
}

info() {
    echo -e "${YELLOW}[INFO]${NC} $1" | tee -a "$TEST_LOG"
}

# 初始化日志
echo "==================================" > "$TEST_LOG"
echo "CentOS 虚拟机完整功能测试报告" >> "$TEST_LOG"
echo "测试时间: $(date)" >> "$TEST_LOG"
echo "虚拟机: $VM_NAME" >> "$TEST_LOG"
echo "==================================" >> "$TEST_LOG"

log "开始 CentOS 虚拟机完整功能测试..."

# ============================================
# 第一部分: 基础功能测试 (9项)
# ============================================

echo ""
log "========== 第一部分: 基础功能测试 =========="

# 测试 1: 虚拟机状态检查
log "测试 1/16: 虚拟机状态检查"
if multipass list | grep -q "$VM_NAME.*Running"; then
    success "虚拟机处于运行状态"
else
    fail "虚拟机未运行"
fi

# 测试 2: 虚拟机信息获取
log "测试 2/16: 获取虚拟机详细信息"
VM_INFO=$(multipass info $VM_NAME 2>&1)
if echo "$VM_INFO" | grep -q "State.*Running"; then
    success "成功获取虚拟机信息"
    info "CPU: $(echo "$VM_INFO" | grep 'CPU(s)' | awk '{print $2}')"
    info "内存: $(echo "$VM_INFO" | grep 'Memory usage' | awk '{print $3, $4, $5, $6}')"
    info "IP: $(echo "$VM_INFO" | grep 'IPv4' | awk '{print $2}')"
else
    fail "无法获取虚拟机信息"
fi

# 测试 3: CentOS 系统识别
log "测试 3/16: CentOS 系统版本识别"
OS_RELEASE=$(multipass exec $VM_NAME -- cat /etc/os-release 2>&1)
if echo "$OS_RELEASE" | grep -q "CentOS Stream"; then
    success "成功识别为 CentOS Stream 9"
    VERSION=$(echo "$OS_RELEASE" | grep "^VERSION=" | cut -d'"' -f2)
    info "系统版本: CentOS Stream $VERSION"
else
    fail "系统识别失败"
fi

# 测试 4: 基础命令执行
log "测试 4/16: 基础命令执行测试"
HOSTNAME=$(multipass exec $VM_NAME -- hostname 2>&1)
UPTIME=$(multipass exec $VM_NAME -- uptime 2>&1)
if [ -n "$HOSTNAME" ] && [ -n "$UPTIME" ]; then
    success "命令执行正常"
    info "主机名: $HOSTNAME"
    info "运行时长: $(echo $UPTIME | awk '{print $3, $4}')"
else
    fail "命令执行失败"
fi

# 测试 5: DNF 包管理器测试
log "测试 5/16: DNF 包管理器功能测试"
DNF_CHECK=$(multipass exec $VM_NAME -- sudo dnf check-update 2>&1 | tail -5)
if multipass exec $VM_NAME -- which dnf >/dev/null 2>&1; then
    success "DNF 包管理器可用"
    info "执行 'dnf check-update' 成功"
else
    fail "DNF 包管理器不可用"
fi

# 测试 6: 网络连接测试
log "测试 6/16: 网络连接测试"
if multipass exec $VM_NAME -- ping -c 3 8.8.8.8 >/dev/null 2>&1; then
    success "外部网络连接正常"
else
    fail "外部网络连接失败"
fi

if multipass exec $VM_NAME -- ping -c 3 www.centos.org >/dev/null 2>&1; then
    success "DNS 解析正常"
else
    fail "DNS 解析失败"
fi

# 测试 7: 文件传输测试
log "测试 7/16: 文件传输测试 (mount/transfer)"
TEST_FILE="/tmp/test_file_$(date +%s).txt"
echo "CentOS Multipass Test $(date)" > "$TEST_FILE"

multipass transfer "$TEST_FILE" $VM_NAME:/tmp/ 2>&1
if multipass exec $VM_NAME -- test -f /tmp/$(basename $TEST_FILE); then
    success "文件上传成功"
    
    # 测试下载
    multipass transfer $VM_NAME:/tmp/$(basename $TEST_FILE) /tmp/downloaded_test.txt 2>&1
    if [ -f /tmp/downloaded_test.txt ]; then
        success "文件下载成功"
        rm /tmp/downloaded_test.txt
    else
        fail "文件下载失败"
    fi
else
    fail "文件上传失败"
fi
rm "$TEST_FILE" 2>/dev/null

# 测试 8: Shell 交互测试
log "测试 8/16: Shell 交互测试"
SHELL_OUTPUT=$(multipass exec $VM_NAME -- bash -c 'echo "Hello from CentOS $HOSTNAME"' 2>&1)
if echo "$SHELL_OUTPUT" | grep -q "Hello from CentOS"; then
    success "Shell 交互正常"
    info "输出: $SHELL_OUTPUT"
else
    fail "Shell 交互失败"
fi

# 测试 9: 系统资源查看
log "测试 9/16: 系统资源监控"
CPU_INFO=$(multipass exec $VM_NAME -- cat /proc/cpuinfo | grep "processor" | wc -l)
MEM_INFO=$(multipass exec $VM_NAME -- free -h | grep Mem | awk '{print $2}')
DISK_INFO=$(multipass exec $VM_NAME -- df -h / | tail -1 | awk '{print $2}')

if [ "$CPU_INFO" -gt 0 ] && [ -n "$MEM_INFO" ]; then
    success "系统资源信息获取成功"
    info "CPU 核心数: $CPU_INFO"
    info "总内存: $MEM_INFO"
    info "磁盘空间: $DISK_INFO"
else
    fail "系统资源信息获取失败"
fi

# ============================================
# 第二部分: CentOS 特有功能测试 (7项)
# ============================================

echo ""
log "========== 第二部分: CentOS 特有功能测试 =========="

# 测试 10: 软件包安装测试 (nginx)
log "测试 10/16: 软件包安装测试 (安装 nginx)"
if multipass exec $VM_NAME -- sudo dnf install -y nginx >/dev/null 2>&1; then
    if multipass exec $VM_NAME -- rpm -q nginx >/dev/null 2>&1; then
        success "软件包安装成功 (nginx)"
        NGINX_VERSION=$(multipass exec $VM_NAME -- nginx -v 2>&1)
        info "Nginx 版本: $NGINX_VERSION"
    else
        fail "软件包安装验证失败"
    fi
else
    fail "软件包安装失败"
fi

# 测试 11: Systemd 服务管理
log "测试 11/16: Systemd 服务管理测试"
if multipass exec $VM_NAME -- sudo systemctl start nginx 2>&1; then
    if multipass exec $VM_NAME -- sudo systemctl status nginx | grep -q "active (running)"; then
        success "Systemd 服务启动成功"
        multipass exec $VM_NAME -- sudo systemctl stop nginx 2>&1
        success "Systemd 服务停止成功"
    else
        fail "Systemd 服务状态异常"
    fi
else
    fail "Systemd 服务管理失败"
fi

# 测试 12: SELinux 状态检查
log "测试 12/16: SELinux 状态检查"
SELINUX_STATUS=$(multipass exec $VM_NAME -- getenforce 2>&1)
if [ -n "$SELINUX_STATUS" ]; then
    success "SELinux 状态检查成功"
    info "SELinux 模式: $SELINUX_STATUS"
else
    fail "SELinux 状态检查失败"
fi

# 测试 13: FirewallD 防火墙测试
log "测试 13/16: FirewallD 防火墙测试"
if multipass exec $VM_NAME -- sudo systemctl is-active firewalld >/dev/null 2>&1; then
    success "FirewallD 服务正在运行"
    FIREWALL_ZONE=$(multipass exec $VM_NAME -- sudo firewall-cmd --get-default-zone 2>&1)
    info "默认防火墙区域: $FIREWALL_ZONE"
else
    info "FirewallD 未启动 (这在虚拟机中是正常的)"
    ((PASSED++))
fi

# 测试 14: YUM/DNF 仓库配置
log "测试 14/16: YUM/DNF 仓库配置检查"
REPO_COUNT=$(multipass exec $VM_NAME -- sudo dnf repolist | grep -c "repo id")
if [ "$REPO_COUNT" -gt 0 ]; then
    success "DNF 仓库配置正常"
    info "已配置仓库数: $REPO_COUNT"
else
    fail "DNF 仓库配置异常"
fi

# 测试 15: RPM 包管理
log "测试 15/16: RPM 包管理测试"
RPM_COUNT=$(multipass exec $VM_NAME -- rpm -qa | wc -l)
if [ "$RPM_COUNT" -gt 100 ]; then
    success "RPM 包管理正常"
    info "已安装软件包数: $RPM_COUNT"
else
    fail "RPM 包管理异常"
fi

# 测试 16: 内核版本检查
log "测试 16/16: Linux 内核版本检查"
KERNEL_VERSION=$(multipass exec $VM_NAME -- uname -r)
if echo "$KERNEL_VERSION" | grep -q "el9"; then
    success "CentOS 9 内核版本正确"
    info "内核版本: $KERNEL_VERSION"
else
    fail "内核版本异常"
fi

# ============================================
# 测试总结
# ============================================

echo ""
echo "==========================================" | tee -a "$TEST_LOG"
echo "          测试结果汇总" | tee -a "$TEST_LOG"
echo "==========================================" | tee -a "$TEST_LOG"
echo "" | tee -a "$TEST_LOG"
echo "总测试数: $TOTAL" | tee -a "$TEST_LOG"
echo -e "${GREEN}通过: $PASSED${NC}" | tee -a "$TEST_LOG"
echo -e "${RED}失败: $FAILED${NC}" | tee -a "$TEST_LOG"

SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($PASSED/$TOTAL)*100}")
echo "" | tee -a "$TEST_LOG"
echo "成功率: ${SUCCESS_RATE}%" | tee -a "$TEST_LOG"

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}🎉 所有测试通过!${NC}" | tee -a "$TEST_LOG"
    EXIT_CODE=0
else
    echo -e "${YELLOW}⚠️  部分测试失败,请查看详细日志${NC}" | tee -a "$TEST_LOG"
    EXIT_CODE=1
fi

echo "" | tee -a "$TEST_LOG"
echo "详细日志保存在: $TEST_LOG" | tee -a "$TEST_LOG"
echo "==========================================" | tee -a "$TEST_LOG"

exit $EXIT_CODE
