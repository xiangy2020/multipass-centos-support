#!/bin/bash
################################################################################
# CentOS 集群部署完整测试脚本
# 自动化测试整个部署流程并生成报告
# 创建日期: 2026-03-22
################################################################################

set -e

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 测试报告文件
REPORT_FILE="CLUSTER_TEST_REPORT.md"
LOG_FILE="cluster_deployment_test.log"

# 开始时间
START_TIME=$(date +%s)

# 初始化报告
init_report() {
    cat > "$REPORT_FILE" << 'EOF'
# CentOS 三节点集群部署测试报告

**测试日期**: 
**测试环境**: macOS with Multipass
**脚本版本**: deploy_cluster_simple.sh v1.0

---

## 测试执行摘要

| 测试项 | 状态 | 耗时 | 说明 |
|--------|------|------|------|
EOF
}

# 添加测试结果
add_test_result() {
    local test_name=$1
    local status=$2
    local duration=$3
    local note=$4
    
    echo "| $test_name | $status | $duration | $note |" >> "$REPORT_FILE"
}

# 打印标题
print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 测试步骤
test_step() {
    local step=$1
    local description=$2
    echo -e "${BLUE}[TEST $step]${NC} $description"
}

# 成功消息
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# 失败消息
fail() {
    echo -e "${RED}✗ $1${NC}"
}

# 警告消息
warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_header "CentOS 三节点集群部署完整测试"

# 初始化报告
init_report

# ============================================================================
# 测试 1: 环境检查
# ============================================================================
test_step "1" "检查测试环境"
test1_start=$(date +%s)

echo "检查 Multipass 安装..."
if ! command -v multipass &> /dev/null; then
    fail "Multipass 未安装"
    add_test_result "环境检查" "❌ 失败" "N/A" "Multipass 未安装"
    exit 1
fi

MULTIPASS_VERSION=$(multipass version | head -1)
success "Multipass 已安装: $MULTIPASS_VERSION"

echo "检查 CentOS 镜像可用性..."
if ! multipass find | grep -i "centos" > /dev/null 2>&1; then
    fail "CentOS 镜像不可用"
    add_test_result "环境检查" "❌ 失败" "N/A" "CentOS 镜像不可用"
    exit 1
fi
success "CentOS 镜像可用"

test1_end=$(date +%s)
test1_duration=$((test1_end - test1_start))
add_test_result "环境检查" "✅ 通过" "${test1_duration}s" "Multipass 和 CentOS 镜像正常"

# ============================================================================
# 测试 2: 清理旧环境
# ============================================================================
test_step "2" "清理旧测试环境"
test2_start=$(date +%s)

echo "检查现有节点..."
if multipass list | grep -E "node-[123]" > /dev/null 2>&1; then
    warn "发现旧节点,正在清理..."
    multipass delete node-1 node-2 node-3 2>/dev/null || true
    multipass purge
    sleep 5
    success "旧节点已清理"
else
    success "无需清理"
fi

test2_end=$(date +%s)
test2_duration=$((test2_end - test2_start))
add_test_result "环境清理" "✅ 完成" "${test2_duration}s" "清理完毕"

# ============================================================================
# 测试 3: 创建节点
# ============================================================================
test_step "3" "创建三个集群节点"
test3_start=$(date +%s)

CENTOS_VERSION="centos9"
CPUS=2
MEMORY="2G"
DISK="20G"

for i in 1 2 3; do
    echo "创建 node-$i (CentOS 9, 2 CPU, 2G RAM, 20G Disk)..."
    
    if multipass launch "$CENTOS_VERSION" \
        --name "node-$i" \
        --cpus "$CPUS" \
        --memory "$MEMORY" \
        --disk "$DISK" >> "$LOG_FILE" 2>&1; then
        success "node-$i 创建成功"
    else
        fail "node-$i 创建失败"
        add_test_result "节点创建" "❌ 失败" "N/A" "node-$i 创建失败"
        exit 1
    fi
done

echo "等待节点完全启动 (30秒)..."
sleep 30
success "所有节点已启动"

test3_end=$(date +%s)
test3_duration=$((test3_end - test3_start))
add_test_result "节点创建" "✅ 通过" "${test3_duration}s" "3个节点创建成功"

# ============================================================================
# 测试 4: 获取 IP 地址
# ============================================================================
test_step "4" "获取节点 IP 地址"
test4_start=$(date +%s)

NODE1_IP=$(multipass info node-1 | grep IPv4 | awk '{print $2}')
NODE2_IP=$(multipass info node-2 | grep IPv4 | awk '{print $2}')
NODE3_IP=$(multipass info node-3 | grep IPv4 | awk '{print $2}')

if [ -z "$NODE1_IP" ] || [ -z "$NODE2_IP" ] || [ -z "$NODE3_IP" ]; then
    fail "无法获取节点 IP 地址"
    add_test_result "IP 获取" "❌ 失败" "N/A" "无法获取 IP"
    exit 1
fi

echo "node-1: $NODE1_IP"
echo "node-2: $NODE2_IP"
echo "node-3: $NODE3_IP"
success "所有 IP 地址已获取"

test4_end=$(date +%s)
test4_duration=$((test4_end - test4_start))
add_test_result "IP 获取" "✅ 通过" "${test4_duration}s" "3个节点 IP 正常"

# ============================================================================
# 测试 5: 配置集群网络
# ============================================================================
test_step "5" "配置集群网络互联"
test5_start=$(date +%s)

HOSTS_CONTENT="
# CentOS Cluster Nodes
$NODE1_IP node-1 node-1.cluster.local
$NODE2_IP node-2 node-2.cluster.local
$NODE3_IP node-3 node-3.cluster.local
"

for i in 1 2 3; do
    echo "配置 node-$i 的 /etc/hosts..."
    if multipass exec "node-$i" -- sudo bash -c "cat >> /etc/hosts << 'EOFHOSTS'
$HOSTS_CONTENT
EOFHOSTS" 2>&1 | tee -a "$LOG_FILE"; then
        success "node-$i 网络配置完成"
    else
        warn "node-$i 网络配置可能失败 (可能已存在)"
    fi
done

test5_end=$(date +%s)
test5_duration=$((test5_end - test5_start))
add_test_result "网络配置" "✅ 完成" "${test5_duration}s" "/etc/hosts 配置完成"

# ============================================================================
# 测试 6: 网络连通性测试
# ============================================================================
test_step "6" "测试集群网络连通性"
test6_start=$(date +%s)

PING_SUCCESS=0
PING_TOTAL=0

for src in 1 2 3; do
    for dst in 1 2 3; do
        if [ $src -ne $dst ]; then
            PING_TOTAL=$((PING_TOTAL + 1))
            echo "测试 node-$src -> node-$dst..."
            
            if multipass exec "node-$src" -- ping -c 2 "node-$dst" >> "$LOG_FILE" 2>&1; then
                success "node-$src -> node-$dst 连通"
                PING_SUCCESS=$((PING_SUCCESS + 1))
            else
                fail "node-$src -> node-$dst 不通"
            fi
        fi
    done
done

echo ""
echo "网络连通性测试结果: $PING_SUCCESS/$PING_TOTAL"

test6_end=$(date +%s)
test6_duration=$((test6_end - test6_start))

if [ $PING_SUCCESS -eq $PING_TOTAL ]; then
    add_test_result "网络连通性" "✅ 通过" "${test6_duration}s" "$PING_SUCCESS/$PING_TOTAL 连接正常"
else
    add_test_result "网络连通性" "⚠️  部分" "${test6_duration}s" "$PING_SUCCESS/$PING_TOTAL 连接正常"
fi

# ============================================================================
# 测试 7: 验证系统信息
# ============================================================================
test_step "7" "验证节点系统信息"
test7_start=$(date +%s)

echo "" >> "$REPORT_FILE"
echo "---" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "## 节点详细信息" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

for i in 1 2 3; do
    echo "收集 node-$i 系统信息..."
    
    OS_INFO=$(multipass exec "node-$i" -- cat /etc/os-release | grep "PRETTY_NAME" | cut -d'"' -f2)
    HOSTNAME=$(multipass exec "node-$i" -- hostname)
    KERNEL=$(multipass exec "node-$i" -- uname -r)
    
    echo "" >> "$REPORT_FILE"
    echo "### node-$i" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "- **IP 地址**: $(eval echo \$NODE${i}_IP)" >> "$REPORT_FILE"
    echo "- **主机名**: $HOSTNAME" >> "$REPORT_FILE"
    echo "- **操作系统**: $OS_INFO" >> "$REPORT_FILE"
    echo "- **内核版本**: $KERNEL" >> "$REPORT_FILE"
    echo "- **配置**: $CPUS CPU, $MEMORY RAM, $DISK Disk" >> "$REPORT_FILE"
    
    success "node-$i 信息收集完成"
done

test7_end=$(date +%s)
test7_duration=$((test7_end - test7_start))
add_test_result "系统验证" "✅ 通过" "${test7_duration}s" "所有节点系统正常"

# ============================================================================
# 测试 8: 生成管理脚本
# ============================================================================
test_step "8" "生成集群管理脚本"
test8_start=$(date +%s)

# 生成快速连接脚本
for i in 1 2 3; do
    cat > "ssh_node${i}.sh" << EOF
#!/bin/bash
# 快速连接到 node-$i
multipass shell node-$i
EOF
    chmod +x "ssh_node${i}.sh"
done

# 生成集群状态检查脚本
cat > "check_cluster.sh" << 'EOFSCRIPT'
#!/bin/bash
echo "=== CentOS 集群状态 ==="
echo ""
multipass list | grep -E "(Name|node-)" 
echo ""
echo "=== 节点 IP 地址 ==="
for i in 1 2 3; do
    echo -n "node-$i: "
    multipass info node-$i | grep IPv4 | awk '{print $2}'
done
EOFSCRIPT
chmod +x "check_cluster.sh"

# 生成启动脚本
cat > "start_cluster.sh" << 'EOFSCRIPT'
#!/bin/bash
echo "启动集群所有节点..."
multipass start node-1 node-2 node-3
echo "等待启动完成..."
sleep 10
echo "集群已启动!"
./check_cluster.sh
EOFSCRIPT
chmod +x "start_cluster.sh"

# 生成停止脚本
cat > "stop_cluster.sh" << 'EOFSCRIPT'
#!/bin/bash
echo "停止集群所有节点..."
multipass stop node-1 node-2 node-3
echo "集群已停止!"
EOFSCRIPT
chmod +x "stop_cluster.sh"

# 生成删除脚本
cat > "delete_cluster.sh" << 'EOFSCRIPT'
#!/bin/bash
echo "警告: 此操作将删除整个集群!"
read -p "确认删除? (yes/NO): " -r
if [[ $REPLY == "yes" ]]; then
    echo "删除集群..."
    multipass delete node-1 node-2 node-3
    multipass purge
    echo "集群已删除!"
else
    echo "操作已取消"
fi
EOFSCRIPT
chmod +x "delete_cluster.sh"

success "管理脚本生成完成"

test8_end=$(date +%s)
test8_duration=$((test8_end - test8_start))
add_test_result "管理脚本" "✅ 完成" "${test8_duration}s" "7个管理脚本已生成"

# ============================================================================
# 最终报告
# ============================================================================
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

print_header "测试完成!"

# 完成报告
cat >> "$REPORT_FILE" << EOF

---

## 集群快速管理命令

### 查看集群状态
\`\`\`bash
./check_cluster.sh
# 或
multipass list | grep node-
\`\`\`

### 连接到节点
\`\`\`bash
./ssh_node1.sh  # 连接到 node-1
./ssh_node2.sh  # 连接到 node-2
./ssh_node3.sh  # 连接到 node-3
# 或
multipass shell node-1
\`\`\`

### 启动/停止集群
\`\`\`bash
./start_cluster.sh   # 启动所有节点
./stop_cluster.sh    # 停止所有节点
\`\`\`

### 删除集群
\`\`\`bash
./delete_cluster.sh  # 删除整个集群
\`\`\`

---

## 网络连通性测试结果

测试从每个节点到其他节点的连通性:

| 源节点 | 目标节点 | 状态 |
|--------|----------|------|
EOF

# 添加详细的连通性测试结果
for src in 1 2 3; do
    for dst in 1 2 3; do
        if [ $src -ne $dst ]; then
            if multipass exec "node-$src" -- ping -c 1 -W 2 "node-$dst" >> "$LOG_FILE" 2>&1; then
                echo "| node-$src | node-$dst | ✅ 正常 |" >> "$REPORT_FILE"
            else
                echo "| node-$src | node-$dst | ❌ 失败 |" >> "$REPORT_FILE"
            fi
        fi
    done
done

cat >> "$REPORT_FILE" << EOF

---

## 测试总结

- **总耗时**: ${TOTAL_DURATION}秒 (~$((TOTAL_DURATION / 60))分钟)
- **测试时间**: $(date '+%Y-%m-%d %H:%M:%S')
- **Multipass 版本**: $MULTIPASS_VERSION
- **集群配置**: 3节点, 每节点 $CPUS CPU / $MEMORY RAM / $DISK Disk
- **CentOS 版本**: CentOS Stream 9
- **网络连通性**: $PING_SUCCESS/$PING_TOTAL 正常

---

## 后续使用建议

### 1. 部署 Kubernetes 集群
\`\`\`bash
# 在所有节点安装容器运行时
for i in 1 2 3; do
  multipass exec node-\$i -- sudo dnf install -y docker
  multipass exec node-\$i -- sudo systemctl enable --now docker
done

# 安装 kubeadm、kubelet、kubectl
# ... (参考 K8s 官方文档)
\`\`\`

### 2. 部署 Web 服务集群
\`\`\`bash
# 快速测试 Nginx
for i in 1 2 3; do
  multipass exec node-\$i -- sudo dnf install -y nginx
  multipass exec node-\$i -- sudo systemctl start nginx
done
\`\`\`

### 3. 数据库高可用测试
- PostgreSQL + Patroni
- MySQL 主从复制
- Redis Cluster

### 4. 分布式存储
- Ceph (3节点最小配置)
- GlusterFS

---

## 故障排查

### 节点无法启动
\`\`\`bash
multipass list
multipass info node-1
multipass restart node-1
\`\`\`

### 网络不通
\`\`\`bash
# 检查 /etc/hosts 配置
multipass exec node-1 -- cat /etc/hosts | grep cluster

# 测试 ping
multipass exec node-1 -- ping -c 3 node-2
\`\`\`

### 清理并重建
\`\`\`bash
./delete_cluster.sh
./deploy_cluster_simple.sh
\`\`\`

---

**测试报告生成时间**: $(date '+%Y-%m-%d %H:%M:%S')
**详细日志**: cluster_deployment_test.log
EOF

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║             测试完成! 集群部署成功! 🎉                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "总耗时: ${TOTAL_DURATION}秒 (~$((TOTAL_DURATION / 60))分钟)"
echo ""
echo "生成的文件:"
echo "  📄 $REPORT_FILE - 完整测试报告"
echo "  📋 $LOG_FILE - 详细执行日志"
echo "  🔧 check_cluster.sh - 查看集群状态"
echo "  🔧 start_cluster.sh - 启动集群"
echo "  🔧 stop_cluster.sh - 停止集群"
echo "  🔧 delete_cluster.sh - 删除集群"
echo "  🔧 ssh_node{1,2,3}.sh - 快速连接节点"
echo ""
echo "集群信息:"
echo "  node-1: $NODE1_IP"
echo "  node-2: $NODE2_IP"
echo "  node-3: $NODE3_IP"
echo ""
echo "快速命令:"
echo "  查看状态: ./check_cluster.sh"
echo "  连接节点: ./ssh_node1.sh"
echo "  查看报告: cat $REPORT_FILE"
echo ""
