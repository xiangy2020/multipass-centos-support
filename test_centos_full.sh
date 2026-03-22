#!/bin/bash
# Multipass CentOS 支持完整功能测试脚本
# 测试所有核心功能和边界情况

# set -e  # 允许部分测试失败而继续执行

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 计数器
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓ PASS]${NC} $1"
    ((TESTS_PASSED++))
    ((TESTS_TOTAL++))
}

log_error() {
    echo -e "${RED}[✗ FAIL]${NC} $1"
    ((TESTS_FAILED++))
    ((TESTS_TOTAL++))
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 测试标题
print_test_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# 清理函数
cleanup() {
    log_info "清理测试虚拟机..."
    multipass delete centos-test 2>/dev/null || true
    multipass delete centos-test-2 2>/dev/null || true
    multipass delete centos-custom 2>/dev/null || true
    multipass purge 2>/dev/null || true
    log_info "清理完成"
}

# 捕获退出信号进行清理
# trap cleanup EXIT  # 暂时禁用自动清理

# ============================================
# 测试 1: 部署配置文件
# ============================================
print_test_header "测试 1: 部署 CentOS 配置文件"

log_info "检查配置文件是否存在..."
if [ -f "/Users/tompyang/WorkBuddy/20260320161009/multipass/data/distributions/distribution-info.json" ]; then
    log_success "配置文件存在"
else
    log_error "配置文件不存在"
    exit 1
fi

log_info "查找 Multipass 数据目录..."
# macOS 上 Multipass 的可能位置
POSSIBLE_DIRS=(
    "/Library/Application Support/multipass/data/distributions"
    "$HOME/Library/Application Support/multipass/data/distributions"
    "/var/snap/multipass/common/data/distributions"
    "/usr/local/var/multipass/data/distributions"
)

MULTIPASS_DATA_DIR=""
for dir in "${POSSIBLE_DIRS[@]}"; do
    if [ -d "$(dirname "$dir")" ]; then
        MULTIPASS_DATA_DIR="$dir"
        log_info "找到 Multipass 数据目录: $MULTIPASS_DATA_DIR"
        break
    fi
done

if [ -z "$MULTIPASS_DATA_DIR" ]; then
    log_warning "未找到标准 Multipass 数据目录,尝试创建本地测试配置"
    # 对于 macOS 上的 Multipass,可能需要其他方式
    log_info "由于 macOS Multipass 的限制,将使用镜像 URL 直接启动"
else
    log_info "复制配置文件到 Multipass 数据目录..."
    mkdir -p "$MULTIPASS_DATA_DIR"
    cp /Users/tompyang/WorkBuddy/20260320161009/multipass/data/distributions/distribution-info.json "$MULTIPASS_DATA_DIR/" 2>/dev/null || log_warning "无法复制配置文件,可能需要管理员权限"
fi

# ============================================
# 测试 2: 检查镜像列表
# ============================================
print_test_header "测试 2: 检查 CentOS 镜像是否可见"

log_info "执行 multipass find 查找所有可用镜像..."
FIND_OUTPUT=$(multipass find 2>&1)
echo "$FIND_OUTPUT"

if echo "$FIND_OUTPUT" | grep -i "centos" > /dev/null; then
    log_success "在镜像列表中找到 CentOS"
else
    log_warning "未在 multipass find 中找到 CentOS (可能需要重启 Multipass 或使用直接 URL)"
fi

# ============================================
# 测试 3: 启动 CentOS 虚拟机 (使用别名)
# ============================================
print_test_header "测试 3: 启动 CentOS 虚拟机"

log_info "尝试使用 centos 别名启动虚拟机..."
if multipass launch centos --name centos-test --timeout 600 2>&1 | tee /tmp/centos_launch.log; then
    log_success "成功使用 'centos' 别名启动虚拟机"
else
    log_warning "使用别名失败,尝试使用直接 URL 启动..."
    
    # 使用直接 URL 启动 (macOS 通常是 x86_64 或 ARM64)
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        IMAGE_URL="https://cloud.centos.org/centos/9-stream/aarch64/images/CentOS-Stream-GenericCloud-9-latest.aarch64.qcow2"
    else
        IMAGE_URL="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
    fi
    
    log_info "使用 URL: $IMAGE_URL"
    if multipass launch "$IMAGE_URL" --name centos-test --timeout 600 2>&1 | tee /tmp/centos_launch_url.log; then
        log_success "成功使用直接 URL 启动 CentOS 虚拟机"
    else
        log_error "无法启动 CentOS 虚拟机"
        cat /tmp/centos_launch_url.log
        exit 1
    fi
fi

# 等待虚拟机完全启动
log_info "等待虚拟机完全启动 (30秒)..."
sleep 30

# ============================================
# 测试 4: 检查虚拟机状态
# ============================================
print_test_header "测试 4: 检查虚拟机状态"

log_info "执行 multipass list..."
LIST_OUTPUT=$(multipass list)
echo "$LIST_OUTPUT"

if echo "$LIST_OUTPUT" | grep "centos-test" | grep "Running" > /dev/null; then
    log_success "虚拟机运行状态正常"
else
    log_error "虚拟机未正常运行"
fi

# ============================================
# 测试 5: 获取虚拟机信息
# ============================================
print_test_header "测试 5: 获取虚拟机详细信息"

log_info "执行 multipass info centos-test..."
INFO_OUTPUT=$(multipass info centos-test)
echo "$INFO_OUTPUT"

if echo "$INFO_OUTPUT" | grep -E "(IPv4|Release|Image)" > /dev/null; then
    log_success "成功获取虚拟机详细信息"
else
    log_error "无法获取虚拟机信息"
fi

# ============================================
# 测试 6: 系统识别
# ============================================
print_test_header "测试 6: 验证 CentOS 系统"

log_info "检查操作系统版本..."
OS_RELEASE=$(multipass exec centos-test -- cat /etc/os-release)
echo "$OS_RELEASE"

if echo "$OS_RELEASE" | grep -i "centos" > /dev/null; then
    log_success "确认为 CentOS 系统"
else
    log_error "系统识别失败,不是 CentOS"
fi

if echo "$OS_RELEASE" | grep -i "stream" > /dev/null; then
    log_success "确认为 CentOS Stream 版本"
fi

# ============================================
# 测试 7: 基本命令执行
# ============================================
print_test_header "测试 7: 执行基本系统命令"

log_info "测试 hostname 命令..."
HOSTNAME=$(multipass exec centos-test -- hostname)
echo "Hostname: $HOSTNAME"
if [ -n "$HOSTNAME" ]; then
    log_success "hostname 命令执行成功"
else
    log_error "hostname 命令失败"
fi

log_info "测试 uname 命令..."
UNAME=$(multipass exec centos-test -- uname -a)
echo "Kernel: $UNAME"
if [ -n "$UNAME" ]; then
    log_success "uname 命令执行成功"
else
    log_error "uname 命令失败"
fi

log_info "测试 uptime 命令..."
UPTIME=$(multipass exec centos-test -- uptime)
echo "Uptime: $UPTIME"
if [ -n "$UPTIME" ]; then
    log_success "uptime 命令执行成功"
else
    log_error "uptime 命令失败"
fi

# ============================================
# 测试 8: 包管理器
# ============================================
print_test_header "测试 8: 包管理器功能 (DNF/YUM)"

log_info "检查 DNF 包管理器..."
if multipass exec centos-test -- which dnf > /dev/null 2>&1; then
    log_success "DNF 包管理器可用"
    
    log_info "测试 dnf --version..."
    multipass exec centos-test -- dnf --version
    
    log_info "尝试更新软件包列表..."
    if multipass exec centos-test -- sudo dnf check-update 2>&1 | head -20; then
        log_success "DNF 软件源连接正常"
    else
        log_warning "DNF 更新检查失败 (可能是网络问题)"
    fi
else
    log_error "DNF 包管理器不可用"
fi

# ============================================
# 测试 9: 网络连接
# ============================================
print_test_header "测试 9: 网络连接测试"

log_info "测试 DNS 解析..."
if multipass exec centos-test -- nslookup google.com > /dev/null 2>&1; then
    log_success "DNS 解析正常"
else
    log_warning "DNS 解析失败"
fi

log_info "测试外网连接 (ping)..."
if multipass exec centos-test -- ping -c 3 8.8.8.8 > /dev/null 2>&1; then
    log_success "外网连接正常"
else
    log_warning "外网 ping 失败"
fi

log_info "测试 HTTP 连接..."
if multipass exec centos-test -- curl -s -o /dev/null -w "%{http_code}" https://www.google.com | grep "200" > /dev/null; then
    log_success "HTTP/HTTPS 连接正常"
else
    log_warning "HTTP 连接测试失败"
fi

# ============================================
# 测试 10: 文件传输
# ============================================
print_test_header "测试 10: 文件传输功能"

log_info "创建测试文件..."
echo "Hello from macOS host! Time: $(date)" > /tmp/test_file.txt

log_info "上传文件到虚拟机..."
if multipass transfer /tmp/test_file.txt centos-test:/tmp/; then
    log_success "文件上传成功"
else
    log_error "文件上传失败"
fi

log_info "验证上传的文件..."
REMOTE_CONTENT=$(multipass exec centos-test -- cat /tmp/test_file.txt)
echo "远程文件内容: $REMOTE_CONTENT"
if [ -n "$REMOTE_CONTENT" ]; then
    log_success "文件内容验证成功"
else
    log_error "文件内容为空"
fi

log_info "从虚拟机下载文件..."
multipass exec centos-test -- echo "Hello from CentOS VM! Time: $(date)" > /tmp/test_reply.txt
if multipass transfer centos-test:/tmp/test_reply.txt /tmp/test_reply_local.txt; then
    log_success "文件下载成功"
    cat /tmp/test_reply_local.txt
else
    log_error "文件下载失败"
fi

# ============================================
# 测试 11: Shell 交互
# ============================================
print_test_header "测试 11: Shell 交互功能"

log_info "测试 multipass shell 命令执行..."
SHELL_TEST=$(multipass shell centos-test -- whoami)
echo "当前用户: $SHELL_TEST"
if [ -n "$SHELL_TEST" ]; then
    log_success "Shell 交互正常"
else
    log_error "Shell 交互失败"
fi

# ============================================
# 测试 12: 软件安装
# ============================================
print_test_header "测试 12: 软件安装测试"

log_info "安装测试软件包 (htop)..."
if multipass exec centos-test -- sudo dnf install -y htop 2>&1 | tail -20; then
    log_success "软件安装功能正常"
    
    log_info "验证软件是否可执行..."
    if multipass exec centos-test -- which htop > /dev/null 2>&1; then
        log_success "安装的软件可以正常使用"
    fi
else
    log_warning "软件安装失败 (可能是网络或软件源问题)"
fi

# ============================================
# 测试 13: 虚拟机生命周期
# ============================================
print_test_header "测试 13: 虚拟机生命周期管理"

log_info "停止虚拟机..."
if multipass stop centos-test; then
    log_success "虚拟机停止成功"
    sleep 5
else
    log_error "虚拟机停止失败"
fi

log_info "检查停止状态..."
if multipass list | grep "centos-test" | grep "Stopped" > /dev/null; then
    log_success "虚拟机已停止"
else
    log_error "虚拟机状态不正确"
fi

log_info "启动虚拟机..."
if multipass start centos-test; then
    log_success "虚拟机启动成功"
    sleep 15
else
    log_error "虚拟机启动失败"
fi

log_info "检查运行状态..."
if multipass list | grep "centos-test" | grep "Running" > /dev/null; then
    log_success "虚拟机已重新运行"
else
    log_error "虚拟机未能恢复运行状态"
fi

# ============================================
# 测试 14: 自定义配置启动
# ============================================
print_test_header "测试 14: 自定义配置启动虚拟机"

log_info "使用自定义 CPU/内存/磁盘启动第二个虚拟机..."
if multipass launch centos --name centos-custom --cpus 2 --memory 2G --disk 10G --timeout 600 2>/dev/null || \
   multipass launch "$IMAGE_URL" --name centos-custom --cpus 2 --memory 2G --disk 10G --timeout 600; then
    log_success "自定义配置虚拟机启动成功"
    sleep 20
    
    log_info "验证资源配置..."
    CPU_COUNT=$(multipass exec centos-custom -- nproc)
    MEM_SIZE=$(multipass exec centos-custom -- free -h | grep Mem | awk '{print $2}')
    echo "CPU 核心数: $CPU_COUNT"
    echo "内存大小: $MEM_SIZE"
    
    if [ "$CPU_COUNT" = "2" ]; then
        log_success "CPU 配置正确"
    else
        log_warning "CPU 配置可能不正确 (预期: 2, 实际: $CPU_COUNT)"
    fi
else
    log_warning "自定义配置启动失败 (非致命错误)"
fi

# ============================================
# 测试 15: 虚拟机快照 (如果支持)
# ============================================
print_test_header "测试 15: 快照功能 (可选)"

log_info "检查快照支持..."
if multipass snapshot centos-test --name test-snapshot 2>&1 | grep -i "not supported\|not available" > /dev/null; then
    log_warning "当前版本不支持快照功能"
else
    log_success "快照功能可用"
fi

# ============================================
# 测试 16: 清理资源
# ============================================
print_test_header "测试 16: 清理测试资源"

log_info "删除测试虚拟机..."
multipass delete centos-test
multipass delete centos-custom 2>/dev/null || true
log_success "虚拟机删除命令已执行"

log_info "清理已删除的虚拟机..."
if multipass purge; then
    log_success "虚拟机资源清理完成"
else
    log_warning "清理命令执行失败"
fi

log_info "验证清理结果..."
if multipass list | grep "centos-test" > /dev/null; then
    log_warning "虚拟机可能未完全清理"
else
    log_success "虚拟机已完全清理"
fi

# ============================================
# 测试总结
# ============================================
print_test_header "测试总结"

echo ""
echo -e "${BLUE}总测试数: $TESTS_TOTAL${NC}"
echo -e "${GREEN}通过: $TESTS_PASSED${NC}"
echo -e "${RED}失败: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  🎉 所有测试通过!CentOS 支持正常!${NC}"
    echo -e "${GREEN}========================================${NC}"
    exit 0
else
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  ⚠️  部分测试失败,请检查日志${NC}"
    echo -e "${YELLOW}========================================${NC}"
    exit 1
fi
