#!/bin/bash

# ╔════════════════════════════════════════════════════════════════╗
# ║  CentOS 镜像修复脚本 - 使修复后的镜像兼容 Multipass            ║
# ╚════════════════════════════════════════════════════════════════╝

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MULTIPASS_BIN="${SCRIPT_DIR}/multipass/build/bin"
ORIGINAL_IMAGE="/Users/tompyang/multipass-images/CentOS-Stream-9.qcow2"
BACKUP_IMAGE="${ORIGINAL_IMAGE}.backup"
FIXED_IMAGE="/Users/tompyang/multipass-images/CentOS-Stream-9-fixed.qcow2"
MOUNT_POINT="/tmp/centos-mount"
NBD_DEVICE="/dev/nbd0"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  CentOS Stream 9 镜像修复工具                                  ║"
echo "║  目标: 修复 cloud-init 和网络配置,使其兼容 Multipass          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ═══════════════════════════════════════════════════════════════════
# 步骤 1: 备份原始镜像
# ═══════════════════════════════════════════════════════════════════
echo "═══ 步骤 1: 备份原始镜像 ═══"
if [ -f "${BACKUP_IMAGE}" ]; then
    echo "⚠️  备份已存在: ${BACKUP_IMAGE}"
    read -p "是否覆盖? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp "${ORIGINAL_IMAGE}" "${BACKUP_IMAGE}"
        echo "✓ 已覆盖备份"
    else
        echo "✓ 使用现有备份"
    fi
else
    echo "正在备份..."
    cp "${ORIGINAL_IMAGE}" "${BACKUP_IMAGE}"
    echo "✓ 备份完成: ${BACKUP_IMAGE}"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# 步骤 2: 创建工作副本
# ═══════════════════════════════════════════════════════════════════
echo "═══ 步骤 2: 创建工作副本 ═══"
if [ -f "${FIXED_IMAGE}" ]; then
    echo "⚠️  修复镜像已存在,删除旧版本..."
    rm -f "${FIXED_IMAGE}"
fi

echo "正在复制镜像..."
cp "${ORIGINAL_IMAGE}" "${FIXED_IMAGE}"
echo "✓ 工作副本创建完成"
echo ""

# ═══════════════════════════════════════════════════════════════════
# 步骤 3: 使用 Ubuntu 虚拟机作为修复环境
# ═══════════════════════════════════════════════════════════════════
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  步骤 3: 启动 Ubuntu 修复环境                                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "由于 macOS 不支持直接挂载 qcow2,我们使用两种方法:"
echo "  方法 A: 使用 Ubuntu 虚拟机作为修复环境 (推荐)"
echo "  方法 B: 使用 guestfish (需要安装 libguestfs)"
echo ""

read -p "选择方法 (A/B): " -n 1 -r
echo
echo ""

if [[ $REPLY =~ ^[Aa]$ ]]; then
    # ═══ 方法 A: 使用 Ubuntu 虚拟机 ═══
    echo "═══ 使用 Ubuntu 虚拟机修复 ═══"
    
    # 检查 ubuntu-verify 是否存在
    VM_EXISTS=$(cd "${MULTIPASS_BIN}" && ./multipass list 2>&1 | grep -c "ubuntu-verify" || true)
    
    if [ "$VM_EXISTS" -eq 0 ]; then
        echo "创建 Ubuntu 修复环境..."
        cd "${MULTIPASS_BIN}"
        ./multipass launch ubuntu --name ubuntu-verify --cpus 2 --memory 4G --disk 20G
        echo "✓ Ubuntu 虚拟机创建完成"
    else
        echo "✓ Ubuntu 虚拟机已存在"
        cd "${MULTIPASS_BIN}"
        VM_STATE=$(./multipass list | grep "ubuntu-verify" | awk '{print $2}')
        if [ "$VM_STATE" != "Running" ]; then
            echo "启动虚拟机..."
            ./multipass start ubuntu-verify
        fi
    fi
    
    echo ""
    echo "═══ 安装必要工具 ═══"
    cd "${MULTIPASS_BIN}"
    ./multipass exec ubuntu-verify -- bash -c "
        set -e
        echo '正在更新包管理器...'
        sudo apt update -qq
        
        echo '安装 qemu-utils 和 nbd 工具...'
        sudo apt install -y qemu-utils nbd-client cloud-init
        
        echo '加载 nbd 内核模块...'
        sudo modprobe nbd max_part=8
        
        echo '✓ 工具安装完成'
    "
    
    echo ""
    echo "═══ 传输镜像到虚拟机 ═══"
    echo "正在上传镜像 (1.8GB,需要 1-2 分钟)..."
    cd "${MULTIPASS_BIN}"
    ./multipass transfer "${FIXED_IMAGE}" ubuntu-verify:/tmp/centos-image.qcow2
    echo "✓ 镜像上传完成"
    
    echo ""
    echo "═══ 在虚拟机中修复镜像 ═══"
    cd "${MULTIPASS_BIN}"
    ./multipass exec ubuntu-verify -- bash -c '
        set -e
        
        echo "1. 连接 qcow2 镜像到 NBD 设备..."
        sudo qemu-nbd --connect=/dev/nbd0 /tmp/centos-image.qcow2
        sleep 2
        
        echo "2. 检测分区..."
        sudo fdisk -l /dev/nbd0
        
        echo "3. 挂载根分区..."
        sudo mkdir -p /mnt/centos
        sudo mount /dev/nbd0p1 /mnt/centos || sudo mount /dev/nbd0p3 /mnt/centos
        
        echo "4. 修复 cloud-init 配置..."
        sudo tee /mnt/centos/etc/cloud/cloud.cfg.d/99_multipass.cfg > /dev/null << "EOF"
# Multipass 兼容配置
datasource_list: [ NoCloud, ConfigDrive, None ]
datasource:
  NoCloud:
    # 允许从 ISO 读取用户数据
    seedfrom: /dev/sr0
  ConfigDrive:
    # 允许从 ConfigDrive 读取
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
  - ca-certs
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

        echo "5. 创建 NetworkManager 配置..."
        sudo tee /mnt/centos/etc/NetworkManager/conf.d/99-multipass.conf > /dev/null << "EOF"
[main]
dns=default
plugins=keyfile

[keyfile]
unmanaged-devices=none

[device]
wifi.scan-rand-mac-address=no
EOF

        echo "6. 禁用等待网络服务..."
        sudo chroot /mnt/centos systemctl mask NetworkManager-wait-online.service || true
        
        echo "7. 确保 cloud-init 服务启用..."
        sudo chroot /mnt/centos systemctl enable cloud-init-local.service
        sudo chroot /mnt/centos systemctl enable cloud-init.service
        sudo chroot /mnt/centos systemctl enable cloud-config.service
        sudo chroot /mnt/centos systemctl enable cloud-final.service
        
        echo "8. 清理 cloud-init 缓存..."
        sudo rm -rf /mnt/centos/var/lib/cloud/*
        
        echo "9. 卸载文件系统..."
        sudo umount /mnt/centos
        
        echo "10. 断开 NBD 设备..."
        sudo qemu-nbd --disconnect /dev/nbd0
        
        echo "✓ 镜像修复完成!"
    '
    
    echo ""
    echo "═══ 下载修复后的镜像 ═══"
    cd "${MULTIPASS_BIN}"
    ./multipass transfer ubuntu-verify:/tmp/centos-image.qcow2 "${FIXED_IMAGE}"
    echo "✓ 镜像下载完成"
    
    echo ""
    echo "═══ 清理虚拟机 ═══"
    ./multipass exec ubuntu-verify -- rm -f /tmp/centos-image.qcow2
    echo "✓ 清理完成"
    
else
    # ═══ 方法 B: 使用 guestfish ═══
    echo "═══ 使用 guestfish 修复 ═══"
    
    # 检查是否安装 libguestfs
    if ! command -v guestfish &> /dev/null; then
        echo "❌ guestfish 未安装"
        echo ""
        echo "请先安装 libguestfs:"
        echo "  brew install libguestfs"
        echo ""
        exit 1
    fi
    
    echo "正在修复镜像..."
    
    # 创建修复脚本
    cat > /tmp/fix_centos.fish << 'EOF'
# 启动镜像
launch
mount /dev/sda3 /

# 创建 cloud-init 配置
write /etc/cloud/cloud.cfg.d/99_multipass.cfg "# Multipass 兼容配置
datasource_list: [ NoCloud, ConfigDrive, None ]
datasource:
  NoCloud:
    seedfrom: /dev/sr0
  ConfigDrive:
    dsmode: local

network:
  version: 2
  renderer: NetworkManager
  ethernets:
    enp0s1:
      dhcp4: true
      dhcp6: false
      optional: true
"

# 清理 cloud-init 缓存
rm-rf /var/lib/cloud

# 关闭
umount-all
exit
EOF
    
    guestfish -a "${FIXED_IMAGE}" -f /tmp/fix_centos.fish
    rm /tmp/fix_centos.fish
    
    echo "✓ 镜像修复完成"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  步骤 4: 测试修复后的镜像                                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

read -p "是否立即测试修复后的镜像? (y/n) " -n 1 -r
echo
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "═══ 启动测试虚拟机 ═══"
    cd "${MULTIPASS_BIN}"
    
    # 删除旧的测试虚拟机
    ./multipass delete centos-fixed-test --purge 2>/dev/null || true
    
    # 启动新虚拟机
    echo "启动修复后的 CentOS 虚拟机..."
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
        ./multipass exec centos-fixed-test -- ping -c 2 8.8.8.8
        
        echo ""
        echo "3. cloud-init 状态:"
        ./multipass exec centos-fixed-test -- cloud-init status
        
        echo ""
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║  ✅ 修复成功!                                                  ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "修复后的镜像: ${FIXED_IMAGE}"
        echo "原始镜像备份: ${BACKUP_IMAGE}"
        echo ""
        echo "您现在可以使用修复后的镜像创建 CentOS 虚拟机:"
        echo "  ./multipass launch file://${FIXED_IMAGE} --name my-centos"
        echo ""
        
    else
        echo ""
        echo "❌ 5 分钟超时,虚拟机仍未完全启动"
        echo ""
        echo "可能的原因:"
        echo "  1. 修复不完整,需要进一步调整"
        echo "  2. 镜像本身有其他问题"
        echo "  3. 需要更长的初始化时间"
        echo ""
        echo "建议:"
        echo "  1. 查看 multipassd 日志获取详细错误"
        echo "  2. 尝试使用官方 CentOS Cloud 镜像"
        echo "  3. 继续使用 Ubuntu (已验证正常)"
        echo ""
    fi
else
    echo "✓ 跳过测试"
    echo ""
    echo "修复后的镜像: ${FIXED_IMAGE}"
    echo "原始镜像备份: ${BACKUP_IMAGE}"
    echo ""
    echo "手动测试命令:"
    echo "  cd ${MULTIPASS_BIN}"
    echo "  ./multipass launch file://${FIXED_IMAGE} --name centos-fixed-test"
    echo ""
fi

echo "═══ 完成 ═══"
