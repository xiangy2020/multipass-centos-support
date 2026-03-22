#!/bin/bash

# CentOS 虚拟机启动诊断和测试脚本
# 目标: 诊断为什么 CentOS 启动卡住

set -e

MULTIPASS_BIN="/Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin/multipass"
CENTOS_IMAGE="file:///Users/tompyang/multipass-images/CentOS-Stream-9.qcow2"
VM_NAME="centos-diagnosis-test"
TIMEOUT=180  # 3 分钟超时

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  CentOS 虚拟机启动诊断测试                                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# 函数: 清理旧虚拟机
cleanup_old_vm() {
    echo "═══ 清理旧虚拟机 ═══"
    if ${MULTIPASS_BIN} list 2>&1 | grep -q "${VM_NAME}"; then
        echo "发现旧虚拟机 ${VM_NAME},清理中..."
        ${MULTIPASS_BIN} delete ${VM_NAME} --purge 2>&1 || true
        sleep 2
        echo "✓ 旧虚拟机已清理"
    else
        echo "✓ 没有旧虚拟机需要清理"
    fi
    echo ""
}

# 函数: 创建虚拟机
create_vm() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  创建 CentOS 虚拟机                                            ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "参数:"
    echo "  - 名称: ${VM_NAME}"
    echo "  - CPUs: 2"
    echo "  - 内存: 2GB"
    echo "  - 磁盘: 15GB"
    echo "  - 镜像: CentOS-Stream-9.qcow2"
    echo ""
    
    ${MULTIPASS_BIN} launch \
        ${CENTOS_IMAGE} \
        --name ${VM_NAME} \
        --cpus 2 \
        --memory 2G \
        --disk 15G &
    
    LAUNCH_PID=$!
    echo "✓ 启动命令已执行 (PID: ${LAUNCH_PID})"
    echo ""
}

# 函数: 监控启动过程
monitor_startup() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  监控启动过程 (超时: ${TIMEOUT} 秒)                             ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    START_TIME=$(date +%s)
    COUNTER=0
    
    while true; do
        CURRENT_TIME=$(date +%s)
        ELAPSED=$((CURRENT_TIME - START_TIME))
        
        if [ $ELAPSED -ge $TIMEOUT ]; then
            echo ""
            echo "❌ 超时! 虚拟机启动超过 ${TIMEOUT} 秒"
            return 1
        fi
        
        # 检查状态
        STATE=$(${MULTIPASS_BIN} list 2>&1 | grep "${VM_NAME}" | awk '{print $2}' || echo "NotFound")
        
        # 检查 QEMU 进程
        QEMU_COUNT=$(ps aux | grep -c "[q]emu.*${VM_NAME}" || echo "0")
        
        # 检查 IP 地址
        IP=$(${MULTIPASS_BIN} list 2>&1 | grep "${VM_NAME}" | awk '{print $3}' || echo "--")
        
        # 显示进度
        printf "\r[%03d 秒] 状态: %-12s | IP: %-15s | QEMU 进程: %d" \
            $ELAPSED "$STATE" "$IP" $QEMU_COUNT
        
        # 检查是否成功启动
        if [ "$STATE" = "Running" ] && [ "$IP" != "--" ]; then
            echo ""
            echo ""
            echo "✅ 虚拟机启动成功!"
            echo "   - 状态: Running"
            echo "   - IP: ${IP}"
            echo "   - 耗时: ${ELAPSED} 秒"
            return 0
        fi
        
        # 检查是否失败
        if [ "$STATE" = "Stopped" ]; then
            echo ""
            echo ""
            echo "❌ 虚拟机启动失败 (状态: Stopped)"
            return 1
        fi
        
        sleep 2
        COUNTER=$((COUNTER + 1))
    done
}

# 函数: 获取详细信息
get_vm_info() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  虚拟机详细信息                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    ${MULTIPASS_BIN} info ${VM_NAME} 2>&1
    echo ""
}

# 函数: 测试基本功能
test_basic_functions() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  测试基本功能                                                  ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # 1. 测试系统信息
    echo "═══ 1. 系统信息 ═══"
    ${MULTIPASS_BIN} exec ${VM_NAME} -- cat /etc/os-release | grep -E "NAME|VERSION" || echo "❌ 失败"
    echo ""
    
    # 2. 测试网络
    echo "═══ 2. 网络连接 ═══"
    ${MULTIPASS_BIN} exec ${VM_NAME} -- ping -c 3 8.8.8.8 2>&1 | tail -3 || echo "❌ 失败"
    echo ""
    
    # 3. 测试 DNS
    echo "═══ 3. DNS 解析 ═══"
    ${MULTIPASS_BIN} exec ${VM_NAME} -- nslookup google.com 2>&1 | grep -A2 "Name:" || echo "❌ 失败"
    echo ""
    
    # 4. 测试包管理器
    echo "═══ 4. DNF 包管理器 ═══"
    ${MULTIPASS_BIN} exec ${VM_NAME} -- dnf --version || echo "❌ 失败"
    echo ""
}

# 函数: 诊断信息
show_diagnostics() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  诊断信息                                                      ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    echo "═══ QEMU 进程 ═══"
    ps aux | grep "[q]emu.*${VM_NAME}" | head -3 || echo "无 QEMU 进程"
    echo ""
    
    echo "═══ 虚拟机列表 ═══"
    ${MULTIPASS_BIN} list 2>&1
    echo ""
}

# 主流程
main() {
    echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # 步骤 1: 清理
    cleanup_old_vm
    
    # 步骤 2: 创建虚拟机
    create_vm
    
    # 步骤 3: 监控启动
    if monitor_startup; then
        # 启动成功
        get_vm_info
        test_basic_functions
        
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║  ✅ 测试完成!                                                  ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "虚拟机 ${VM_NAME} 可以正常使用了!"
        echo ""
        echo "连接命令:"
        echo "  ${MULTIPASS_BIN} shell ${VM_NAME}"
        echo ""
        echo "清理命令:"
        echo "  ${MULTIPASS_BIN} delete ${VM_NAME} --purge"
        echo ""
    else
        # 启动失败
        echo ""
        show_diagnostics
        
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║  ❌ 启动失败!                                                  ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "可能的原因:"
        echo "  1. CentOS cloud-init 初始化时间过长"
        echo "  2. 网络配置问题"
        echo "  3. 镜像兼容性问题"
        echo ""
        echo "建议:"
        echo "  1. 尝试增加超时时间: TIMEOUT=300"
        echo "  2. 检查 multipassd 日志输出"
        echo "  3. 使用 Ubuntu 测试验证 Multipass 是否正常"
        echo ""
        echo "清理命令:"
        echo "  ${MULTIPASS_BIN} delete ${VM_NAME} --purge"
        echo "  sudo pkill -f 'qemu.*${VM_NAME}'"
        echo ""
    fi
    
    echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 执行主流程
main
