#!/bin/bash

# ╔════════════════════════════════════════════════════════════════╗
# ║  CentOS 镜像修复脚本 - 使用 Ubuntu 虚拟机方法                 ║
# ╚════════════════════════════════════════════════════════════════╝

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MULTIPASS_BIN="${SCRIPT_DIR}/multipass/build/bin"
ORIGINAL_IMAGE="/Users/tompyang/multipass-images/CentOS-Stream-9.qcow2"
BACKUP_IMAGE="${ORIGINAL_IMAGE}.backup"
FIXED_IMAGE="/Users/tompyang/multipass-images/CentOS-Stream-9-fixed.qcow2"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  CentOS Stream 9 镜像修复工具 (Ubuntu 虚拟机方法)             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ═══════════════════════════════════════════════════════════════════
# 步骤 1: 备份原始镜像
# ═══════════════════════════════════════════════════════════════════
echo "═══ 步骤 1: 备份原始镜像 ═══"
if [ ! -f "${BACKUP_IMAGE}" ]; then
    echo "正在备份..."
    cp "${ORIGINAL_IMAGE}" "${BACKUP_IMAGE}"
    echo "✓ 备份完成: ${BACKUP_IMAGE}"
else
    echo "✓ 备份已存在: ${BACKUP_IMAGE}"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# 步骤 2: 创建工作副本
# ═══════════════════════════════════════════════════════════════════
echo "═══ 步骤 2: 创建工作副本 ═══"
if [ -f "${FIXED_IMAGE}" ]; then
    echo "⚠️  删除旧的修复版本..."
    rm -f "${FIXED_IMAGE}"
fi

echo "正在复制镜像..."
cp "${ORIGINAL_IMAGE}" "${FIXED_IMAGE}"
echo "✓ 工作副本创建完成"
echo ""

# ═══════════════════════════════════════════════════════════════════
# 步骤 3: 检查/启动 Ubuntu 虚拟机
# ═══════════════════════════════════════════════════════════════════
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  步骤 3: 准备 Ubuntu 修复环境                                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

cd "${MULTIPASS_BIN}"
VM_EXISTS=$(./multipass list 2>&1 | grep -c "ubuntu-verify" || true)

if [ "$VM_EXISTS" -eq 0 ]; then
    echo "❌ Ubuntu 虚拟机不存在,正在创建..."
    ./multipass launch ubuntu --name ubuntu-verify --cpus 2 --memory 4G --disk 20G
    echo "✓ Ubuntu 虚拟机创建完成"
else
    echo "✓ Ubuntu 虚拟机已存在"
    VM_STATE=$(./multipass list | grep "ubuntu-verify" | awk '{print $2}')
    if [ "$VM_STATE" != "Running" ]; then
        echo "启动虚拟机..."
        ./multipass start ubuntu-verify
        sleep 3
    fi
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# 步骤 4: 安装必要工具
# ═══════════════════════════════════════════════════════════════════
echo "═══ 步骤 4: 在 Ubuntu 中安装修复工具 ═══"
./multipass exec ubuntu-verify -- bash -c "
    set -e
    echo '→ 更新包管理器...'
    sudo apt update -qq 2>&1 | tail -1
    
    echo '→ 安装 qemu-utils...'
    sudo apt install -y qemu-utils 2>&1 | tail -1
    
    echo '→ 加载 nbd 内核模块...'
    sudo modprobe nbd max_part=8 2>/dev/null || true
    
    echo '✓ 工具准备完成'
"
echo ""

# ═══════════════════════════════════════════════════════════════════
# 步骤 5: 传输镜像到虚拟机
# ═══════════════════════════════════════════════════════════════════
echo "═══ 步骤 5: 传输镜像到虚拟机 ═══"
echo "正在上传 1.8GB 镜像,预计需要 1-2 分钟..."
echo ""
./multipass transfer "${FIXED_IMAGE}" ubuntu-verify:/tmp/centos-image.qcow2
echo ""
echo "✓ 镜像上传完成"
echo ""

# ═══════════════════════════════════════════════════════════════════
# 步骤 6: 在虚拟机中修复镜像
# ═══════════════════════════════════════════════════════════════════
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  步骤 6: 修复镜像配置                                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

./multipass exec ubuntu-verify -- bash -c '
set -e

echo "1. 连接 qcow2 镜像到 NBD 设备..."
sudo qemu-nbd --connect=/dev/nbd0 /tmp/centos-image.qcow2
sleep 2

echo "2. 检测分区..."
sudo fdisk -l /dev/nbd0 | grep "^/dev/nbd0"

echo ""
echo "3. 尝试挂载根分区..."
sudo mkdir -p /mnt/centos

# 尝试不同的分区
MOUNTED=0
for partition in /dev/nbd0p3 /dev/nbd0p1 /dev/nbd0p2; do
    if sudo mount $partition /mnt/centos 2>/dev/null; then
        echo "✓ 成功挂载: $partition"
        MOUNTED=1
        break
    fi
done

if [ $MOUNTED -eq 0 ]; then
    echo "❌ 无法挂载任何分区"
    sudo qemu-nbd --disconnect /dev/nbd0
    exit 1
fi

echo ""
echo "4. 创建 cloud-init 配置..."
sudo mkdir -p /mnt/centos/etc/cloud/cloud.cfg.d
sudo tee /mnt/centos/etc/cloud/cloud.cfg.d/99_multipass.cfg > /dev/null << "EOF"
# Multipass 兼容配置
datasource_list: [ NoCloud, ConfigDrive, None ]
datasource:
  NoCloud:
    seedfrom: /dev/sr0
  ConfigDrive:
    dsmode: local

# 网络配置
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    enp0s1:
      dhcp4: true
      dhcp6: false
      optional: true

# 禁用不必要的模块
cloud_init_modules:
  - migrator
  - seed_random
  - bootcmd
  - write-files
  - growpart
  - resizefs
  - set_hostname
  - update_hostname
  - update_etc_hosts
  - rsyslog
  - users-groups
  - ssh

cloud_config_modules:
  - ssh-import-id
  - locale
  - set-passwords
  - runcmd

cloud_final_modules:
  - scripts-vendor
  - scripts-per-once
  - scripts-per-boot
  - scripts-per-instance
  - scripts-user
  - ssh-authkey-fingerprints
  - final-message

# 系统信息
system_info:
  distro: centos
  default_user:
    name: ubuntu
    lock_passwd: True
    gecos: Ubuntu
    groups: [adm, audio, cdrom, dialout, floppy, video, plugdev, dip, netdev]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
EOF
echo "✓ cloud-init 配置已创建"

echo ""
echo "5. 创建 NetworkManager 配置..."
sudo mkdir -p /mnt/centos/etc/NetworkManager/conf.d
sudo tee /mnt/centos/etc/NetworkManager/conf.d/99-multipass.conf > /dev/null << "EOF"
[main]
dns=default
plugins=keyfile

[keyfile]
unmanaged-devices=none

[device]
wifi.scan-rand-mac-address=no
EOF
echo "✓ NetworkManager 配置已创建"

echo ""
echo "6. 清理 cloud-init 缓存..."
sudo rm -rf /mnt/centos/var/lib/cloud/* 2>/dev/null || true
echo "✓ 缓存已清理"

echo ""
echo "7. 卸载文件系统..."
sudo sync
sudo umount /mnt/centos
echo "✓ 文件系统已卸载"

echo ""
echo "8. 断开 NBD 设备..."
sudo qemu-nbd --disconnect /dev/nbd0
echo "✓ NBD 已断开"

echo ""
echo "✓✓✓ 镜像修复完成! ✓✓✓"
'

echo ""
echo "✓ 修复流程完成"
echo ""

# ═══════════════════════════════════════════════════════════════════
# 步骤 7: 下载修复后的镜像
# ═══════════════════════════════════════════════════════════════════
echo "═══ 步骤 7: 下载修复后的镜像 ═══"
echo "正在下载,预计需要 1-2 分钟..."
echo ""
cd "${MULTIPASS_BIN}"
./multipass transfer ubuntu-verify:/tmp/centos-image.qcow2 "${FIXED_IMAGE}"
echo ""
echo "✓ 镜像下载完成"
echo ""

# ═══════════════════════════════════════════════════════════════════
# 步骤 8: 清理虚拟机
# ═══════════════════════════════════════════════════════════════════
echo "═══ 步骤 8: 清理虚拟机临时文件 ═══"
./multipass exec ubuntu-verify -- rm -f /tmp/centos-image.qcow2
echo "✓ 清理完成"
echo ""

# ═══════════════════════════════════════════════════════════════════
# 步骤 9: 测试修复后的镜像
# ═══════════════════════════════════════════════════════════════════
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  步骤 9: 测试修复后的镜像                                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "修复后的镜像: ${FIXED_IMAGE}"
echo "原始镜像备份: ${BACKUP_IMAGE}"
echo ""
read -p "是否立即测试修复后的镜像? (y/n) " -n 1 -r
echo
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "═══ 启动测试虚拟机 ═══"
    cd "${MULTIPASS_BIN}"
    
    # 删除旧的测试虚拟机
    ./multipass delete centos-fixed-test --purge 2>/dev/null || true
    sleep 2
    
    # 启动新虚拟机
    echo "正在启动修复后的 CentOS 虚拟机..."
    ./multipass launch \
        "file://${FIXED_IMAGE}" \
        --name centos-fixed-test \
        --cpus 2 \
        --memory 2G \
        --disk 15G &
    
    LAUNCH_PID=$!
    
    echo ""
    echo "═══ 监控启动进度 (最多 5 分钟) ═══"
    echo ""
    
    START=$(date +%s)
    SUCCESS=0
    
    while [ $(($(date +%s) - START)) -lt 300 ]; do
        ELAPSED=$(($(date +%s) - START))
        
        STATE=$(./multipass list 2>&1 | grep "centos-fixed-test" | awk '{print $2}' || echo "NotFound")
        IP=$(./multipass list 2>&1 | grep "centos-fixed-test" | awk '{print $3}' || echo "--")
        
        printf "\r[%03d 秒] 状态: %-12s | IP: %-15s" $ELAPSED "$STATE" "$IP"
        
        if [ "$STATE" = "Running" ] && [ "$IP" != "--" ]; then
            echo ""
            echo ""
            echo "✅ 虚拟机启动成功!"
            echo "   - 状态: Running"
            echo "   - IP: ${IP}"
            echo "   - 耗时: ${ELAPSED} 秒"
            SUCCESS=1
            break
        fi
        
        sleep 2
    done
    
    echo ""
    
    if [ $SUCCESS -eq 1 ]; then
        echo ""
        echo "═══ 功能测试 ═══"
        echo ""
        
        echo "1. 系统信息:"
        ./multipass exec centos-fixed-test -- cat /etc/os-release | grep PRETTY_NAME
        
        echo ""
        echo "2. 网络测试:"
        ./multipass exec centos-fixed-test -- ping -c 2 8.8.8.8 | tail -2
        
        echo ""
        echo "3. cloud-init 状态:"
        ./multipass exec centos-fixed-test -- cloud-init status || echo "cloud-init 命令不可用"
        
        echo ""
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║  ✅ 修复成功!                                                  ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "您现在可以使用修复后的镜像创建 CentOS 虚拟机:"
        echo "  cd ${MULTIPASS_BIN}"
        echo "  ./multipass launch file://${FIXED_IMAGE} --name my-centos"
        echo ""
        
    else
        echo ""
        echo "❌ 5 分钟超时,虚拟机仍未完全启动"
        echo ""
        echo "建议检查:"
        echo "  1. 查看 multipassd 日志"
        echo "  2. 尝试手动启动并等待更长时间"
        echo "  3. 考虑使用官方 CentOS Cloud 镜像"
        echo ""
    fi
else
    echo "✓ 跳过测试"
    echo ""
    echo "手动测试命令:"
    echo "  cd ${MULTIPASS_BIN}"
    echo "  ./multipass launch file://${FIXED_IMAGE} --name centos-fixed-test"
    echo ""
fi

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  修复流程完成                                                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "文件位置:"
echo "  - 修复镜像: ${FIXED_IMAGE}"
echo "  - 原始备份: ${BACKUP_IMAGE}"
echo ""
