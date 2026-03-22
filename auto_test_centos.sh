#!/bin/bash
# CentOS 镜像下载监控和自动测试脚本

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

IMAGE_FILE="/tmp/multipass_images/centos9-stream-arm64.qcow2"
EXPECTED_SIZE=1527644160  # 1.46 GB in bytes
VM_NAME="centos-test-auto"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

# 监控下载进度
log_info "监控 CentOS 镜像下载进度..."
echo ""

while true; do
    if [ ! -f "$IMAGE_FILE" ]; then
        log_warning "镜像文件不存在,等待下载开始..."
        sleep 10
        continue
    fi
    
    CURRENT_SIZE=$(stat -f%z "$IMAGE_FILE" 2>/dev/null || echo 0)
    PERCENT=$((CURRENT_SIZE * 100 / EXPECTED_SIZE))
    HUMAN_SIZE=$(du -h "$IMAGE_FILE" | cut -f1)
    
    printf "\r${BLUE}[INFO]${NC} 下载进度: %s / 1.46GB (%d%%)   " "$HUMAN_SIZE" "$PERCENT"
    
    # 检查是否下载完成
    if [ $CURRENT_SIZE -ge $EXPECTED_SIZE ]; then
        echo ""
        log_success "镜像下载完成!"
        break
    fi
    
    # 检查下载是否停止
    PREV_SIZE=$CURRENT_SIZE
    sleep 5
    CURRENT_SIZE=$(stat -f%z "$IMAGE_FILE" 2>/dev/null || echo 0)
    
    if [ $CURRENT_SIZE -eq $PREV_SIZE ] && [ $CURRENT_SIZE -lt $EXPECTED_SIZE ]; then
        # 下载可能已停止,再等待一次确认
        sleep 5
        NEW_SIZE=$(stat -f%z "$IMAGE_FILE" 2>/dev/null || echo 0)
        if [ $NEW_SIZE -eq $CURRENT_SIZE ]; then
            echo ""
            log_warning "下载似乎已停止,当前大小: $HUMAN_SIZE"
            log_info "尝试恢复下载..."
            
            # 尝试恢复下载
            cd /tmp/multipass_images
            curl -L -C - -o centos9-stream-arm64.qcow2 \
                https://cloud.centos.org/centos/9-stream/aarch64/images/CentOS-Stream-GenericCloud-9-latest.aarch64.qcow2 &
            CURL_PID=$!
            log_info "恢复下载,PID: $CURL_PID"
            sleep 5
        fi
    fi
done

echo ""
log_info "验证镜像文件完整性..."
if file "$IMAGE_FILE" | grep -q "QCOW"; then
    log_success "镜像格式正确 (QCOW2)"
else
    log_warning "无法验证镜像格式,但将尝试启动"
fi

# 启动虚拟机
log_info "使用本地镜像启动 CentOS 虚拟机..."
echo ""

if multipass launch "file://$IMAGE_FILE" --name "$VM_NAME" --cpus 2 --memory 2G --disk 10G --timeout 600; then
    log_success "虚拟机启动成功!"
else
    log_warning "虚拟机启动失败,请检查日志"
    exit 1
fi

# 等待虚拟机完全启动
log_info "等待虚拟机完全初始化 (60秒)..."
sleep 60

# 执行基础测试
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  开始 CentOS 虚拟机功能测试${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 测试 1: 虚拟机状态
log_info "测试 1: 检查虚拟机状态"
multipass list
if multipass list | grep "$VM_NAME" | grep "Running" > /dev/null; then
    log_success "虚拟机运行正常"
else
    log_warning "虚拟机状态异常"
fi

# 测试 2: 获取详细信息
log_info "测试 2: 获取虚拟机信息"
multipass info "$VM_NAME"

# 测试 3: 系统识别
log_info "测试 3: 验证 CentOS 系统"
OS_INFO=$(multipass exec "$VM_NAME" -- cat /etc/os-release)
echo "$OS_INFO"
if echo "$OS_INFO" | grep -i "centos" > /dev/null; then
    log_success "确认为 CentOS Stream 系统"
else
    log_warning "系统识别异常"
fi

# 测试 4: 基础命令
log_info "测试 4: 执行基础命令"
log_info "  - hostname:"
multipass exec "$VM_NAME" -- hostname
log_info "  - uname:"
multipass exec "$VM_NAME" -- uname -a
log_info "  - uptime:"
multipass exec "$VM_NAME" -- uptime

# 测试 5: 包管理器
log_info "测试 5: 测试 DNF 包管理器"
if multipass exec "$VM_NAME" -- which dnf > /dev/null; then
    log_success "DNF 可用"
    multipass exec "$VM_NAME" -- dnf --version
else
    log_warning "DNF 不可用"
fi

# 测试 6: 网络
log_info "测试 6: 网络连接测试"
if multipass exec "$VM_NAME" -- ping -c 3 8.8.8.8 > /dev/null 2>&1; then
    log_success "网络连接正常"
else
    log_warning "网络连接失败"
fi

# 测试 7: 文件传输
log_info "测试 7: 文件传输测试"
echo "Hello from macOS at $(date)" > /tmp/test_file.txt
if multipass transfer /tmp/test_file.txt "$VM_NAME":/tmp/; then
    log_success "文件上传成功"
    CONTENT=$(multipass exec "$VM_NAME" -- cat /tmp/test_file.txt)
    echo "  远程内容: $CONTENT"
else
    log_warning "文件传输失败"
fi

# 测试 8: 软件安装
log_info "测试 8: 软件安装测试 (htop)"
if multipass exec "$VM_NAME" -- sudo dnf install -y htop 2>&1 | tail -10; then
    log_success "软件安装成功"
else
    log_warning "软件安装失败 (可能需要更多时间或网络问题)"
fi

# 测试 9: 生命周期
log_info "测试 9: 虚拟机生命周期测试"
log_info "  - 停止虚拟机"
multipass stop "$VM_NAME"
sleep 5
log_info "  - 启动虚拟机"
multipass start "$VM_NAME"
sleep 15
log_success "生命周期测试完成"

# 测试总结
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✓ CentOS 虚拟机测试完成!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
log_info "虚拟机 '$VM_NAME' 已保留,可以继续使用"
log_info "连接虚拟机: multipass shell $VM_NAME"
log_info "停止虚拟机: multipass stop $VM_NAME"
log_info "删除虚拟机: multipass delete $VM_NAME && multipass purge"
echo ""
