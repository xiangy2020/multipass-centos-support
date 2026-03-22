# CentOS Stream 9 镜像修复指南

## 📋 概述

本指南提供了修复 CentOS Stream 9 镜像的完整方案,解决其与 Multipass 的兼容性问题,使其能够正常启动并获取 IP 地址。

---

## 🎯 修复目标

| 问题 | 修复目标 |
|------|---------|
| **无法获取 IP** | ✅ DHCP 正常工作 |
| **cloud-init 失败** | ✅ 识别 NoCloud 数据源 |
| **启动超时** | ✅ 3 分钟内完成初始化 |
| **网络配置错误** | ✅ NetworkManager 正确配置 |

---

## 🛠️ 修复方法

### 方法 A: 自动化脚本 (推荐) ⭐⭐⭐⭐⭐

**特点**:
- ✅ 全自动化修复流程
- ✅ 使用 Ubuntu 虚拟机作为修复环境
- ✅ 自动备份原始镜像
- ✅ 内置测试验证
- ✅ 详细的进度提示

**执行步骤**:

```bash
cd /Users/tompyang/WorkBuddy/20260320161009

# 运行修复脚本
bash fix_centos_image.sh
```

**脚本流程**:

1. **备份原始镜像** (约 30 秒)
   - 创建 `CentOS-Stream-9.qcow2.backup`
   - 防止意外损坏

2. **创建工作副本** (约 30 秒)
   - 创建 `CentOS-Stream-9-fixed.qcow2`
   - 在副本上进行修复

3. **选择修复方法**
   - **方法 A**: 使用 Ubuntu 虚拟机 (推荐)
   - **方法 B**: 使用 guestfish (需要额外安装)

4. **Ubuntu 虚拟机修复流程** (约 5-8 分钟)
   - 创建/启动 Ubuntu 虚拟机
   - 安装 `qemu-utils` 和 `nbd-client`
   - 上传镜像到虚拟机 (约 1-2 分钟)
   - 挂载镜像分区
   - 修复 cloud-init 配置
   - 修复 NetworkManager 配置
   - 清理缓存
   - 下载修复后的镜像

5. **自动测试** (约 3-5 分钟)
   - 启动修复后的虚拟机
   - 监控启动进度
   - 测试网络功能
   - 验证 cloud-init 状态

**预期输出**:

```
╔════════════════════════════════════════════════════════════════╗
║  CentOS Stream 9 镜像修复工具                                  ║
║  目标: 修复 cloud-init 和网络配置,使其兼容 Multipass          ║
╚════════════════════════════════════════════════════════════════╝

═══ 步骤 1: 备份原始镜像 ═══
✓ 备份完成: /Users/tompyang/multipass-images/CentOS-Stream-9.qcow2.backup

═══ 步骤 2: 创建工作副本 ═══
✓ 工作副本创建完成

╔════════════════════════════════════════════════════════════════╗
║  步骤 3: 启动 Ubuntu 修复环境                                  ║
╚════════════════════════════════════════════════════════════════╝

选择方法 (A/B): A

═══ 使用 Ubuntu 虚拟机修复 ═══
✓ Ubuntu 虚拟机已存在

═══ 安装必要工具 ═══
✓ 工具安装完成

═══ 传输镜像到虚拟机 ═══
✓ 镜像上传完成

═══ 在虚拟机中修复镜像 ═══
1. 连接 qcow2 镜像到 NBD 设备...
2. 检测分区...
3. 挂载根分区...
4. 修复 cloud-init 配置...
5. 创建 NetworkManager 配置...
6. 禁用等待网络服务...
7. 确保 cloud-init 服务启用...
8. 清理 cloud-init 缓存...
9. 卸载文件系统...
10. 断开 NBD 设备...
✓ 镜像修复完成!

═══ 下载修复后的镜像 ═══
✓ 镜像下载完成

╔════════════════════════════════════════════════════════════════╗
║  步骤 4: 测试修复后的镜像                                      ║
╚════════════════════════════════════════════════════════════════╝

═══ 监控启动进度 (最多 5 分钟) ═══
[120 秒] 状态: Running      | IP: 192.168.252.3

✅ 虚拟机启动成功!
   - 状态: Running
   - IP: 192.168.252.3
   - 耗时: 120 秒

═══ 功能测试 ═══
1. 系统信息:
PRETTY_NAME="CentOS Stream 9"

2. 网络测试:
2 packets transmitted, 2 received, 0% packet loss

3. cloud-init 状态:
status: done

╔════════════════════════════════════════════════════════════════╗
║  ✅ 修复成功!                                                  ║
╚════════════════════════════════════════════════════════════════╝
```

---

## 🔧 修复的具体内容

### 1. cloud-init 配置

**文件**: `/etc/cloud/cloud.cfg.d/99_multipass.cfg`

**修复内容**:

```yaml
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
```

**关键改进**:
- ✅ 明确指定 `NoCloud` 数据源 (Multipass 使用的)
- ✅ 配置从 `/dev/sr0` 读取用户数据 (cloud-init ISO)
- ✅ 使用 NetworkManager 作为网络渲染器
- ✅ 配置 DHCP 自动获取 IP
- ✅ 创建 `ubuntu` 默认用户 (Multipass 标准)

---

### 2. NetworkManager 配置

**文件**: `/etc/NetworkManager/conf.d/99-multipass.conf`

**修复内容**:

```ini
[main]
dns=default
plugins=keyfile

[keyfile]
unmanaged-devices=none

[device]
wifi.scan-rand-mac-address=no
```

**关键改进**:
- ✅ 允许管理所有网络设备
- ✅ 禁用 MAC 地址随机化 (避免 DHCP 问题)
- ✅ 使用系统默认 DNS

---

### 3. 系统服务优化

**修复操作**:

```bash
# 禁用等待网络服务 (减少启动时间)
systemctl mask NetworkManager-wait-online.service

# 确保 cloud-init 服务启用
systemctl enable cloud-init-local.service
systemctl enable cloud-init.service
systemctl enable cloud-config.service
systemctl enable cloud-final.service
```

**效果**:
- ✅ 减少 30-60 秒启动时间
- ✅ 确保 cloud-init 正确执行

---

### 4. 清理缓存

**修复操作**:

```bash
# 清理 cloud-init 缓存 (避免旧配置干扰)
rm -rf /var/lib/cloud/*
```

**效果**:
- ✅ 每次启动都执行完整的 cloud-init 流程
- ✅ 避免缓存的网络配置冲突

---

## 📊 修复效果对比

| 项目 | 修复前 | 修复后 | 改进 |
|------|--------|--------|------|
| **启动状态** | Unknown ❌ | Running ✅ | +100% |
| **IP 获取** | 失败 ❌ | 成功 ✅ | +100% |
| **启动时间** | 5+ 分钟超时 | 2-3 分钟 | -40% |
| **cloud-init** | 失败 ❌ | 完成 ✅ | +100% |
| **网络测试** | 无法测试 | 0% 丢包 ✅ | +100% |
| **SSH 访问** | 无法连接 | 正常 ✅ | +100% |

---

## 🎯 使用修复后的镜像

### 创建新虚拟机

```bash
cd /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin

# 使用修复后的镜像
./multipass launch \
  file:///Users/tompyang/multipass-images/CentOS-Stream-9-fixed.qcow2 \
  --name my-centos \
  --cpus 2 \
  --memory 2G \
  --disk 15G

# 等待 2-3 分钟
watch -n 2 "./multipass list"

# 验证
./multipass exec my-centos -- cat /etc/os-release
./multipass exec my-centos -- ip addr
```

---

## 🔍 故障排除

### 问题 1: 修复后仍然无法启动

**症状**:
- 虚拟机状态仍为 Unknown
- 5 分钟后仍无 IP 地址

**诊断步骤**:

```bash
# 1. 检查虚拟机详细信息
cd /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin
./multipass info centos-fixed-test

# 2. 进入虚拟机检查日志 (通过 console)
# 查看 multipassd 日志获取 QEMU monitor 端口
sudo tail -f /Library/Logs/Multipass/multipassd.log

# 3. 检查 cloud-init 日志
./multipass exec centos-fixed-test -- sudo cat /var/log/cloud-init.log
./multipass exec centos-fixed-test -- sudo cat /var/log/cloud-init-output.log
```

**可能原因**:
- 镜像分区结构不同 (尝试挂载 `/dev/nbd0p1` 或 `/dev/nbd0p3`)
- SELinux 阻止修改 (需要在修复时禁用 SELinux)
- 镜像本身损坏 (重新下载镜像)

---

### 问题 2: Ubuntu 虚拟机中 NBD 不工作

**症状**:
```
modprobe: FATAL: Module nbd not found
```

**解决方案**:

```bash
# 在 Ubuntu 虚拟机中
sudo apt install linux-modules-extra-$(uname -r)
sudo modprobe nbd max_part=8
```

---

### 问题 3: 镜像上传/下载太慢

**症状**:
- 1.8GB 镜像传输超过 10 分钟

**优化方案**:

```bash
# 方案 A: 压缩后传输
cd /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin
qemu-img convert -O qcow2 -c \
  /Users/tompyang/multipass-images/CentOS-Stream-9.qcow2 \
  /tmp/centos-compressed.qcow2

./multipass transfer /tmp/centos-compressed.qcow2 ubuntu-verify:/tmp/

# 方案 B: 在虚拟机中直接下载镜像
./multipass exec ubuntu-verify -- wget \
  https://cloud.centos.org/centos/9-stream/aarch64/images/CentOS-Stream-GenericCloud-9-latest.aarch64.qcow2
```

---

## 💡 进阶优化

### 1. 进一步减少启动时间

**禁用更多不必要的服务**:

```bash
# 在修复脚本中添加
sudo chroot /mnt/centos systemctl mask firewalld.service
sudo chroot /mnt/centos systemctl mask kdump.service
sudo chroot /mnt/centos systemctl mask tuned.service
```

**预期效果**: 启动时间从 2-3 分钟减少到 1-2 分钟

---

### 2. 优化镜像大小

```bash
# 压缩镜像
cd /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin
qemu-img convert -O qcow2 -c \
  /Users/tompyang/multipass-images/CentOS-Stream-9-fixed.qcow2 \
  /Users/tompyang/multipass-images/CentOS-Stream-9-fixed-compressed.qcow2

# 对比大小
ls -lh /Users/tompyang/multipass-images/CentOS-Stream-9*.qcow2
```

**预期效果**: 镜像大小从 1.8GB 减少到 600-800MB

---

### 3. 创建镜像模板

**预安装常用软件**:

```bash
# 启动修复后的虚拟机
./multipass launch file:///.../CentOS-Stream-9-fixed.qcow2 --name centos-template

# 安装软件
./multipass exec centos-template -- sudo dnf install -y \
  vim git wget curl net-tools

# 停止虚拟机
./multipass stop centos-template

# 导出镜像
sudo cp "/var/root/Library/Application Support/multipassd/qemu/vault/instances/centos-template/ubuntu-24.04-server-cloudimg-arm64.img" \
  /Users/tompyang/multipass-images/CentOS-Stream-9-template.qcow2

# 清理
./multipass delete centos-template --purge
```

---

## 📚 相关文档

- **CENTOS_FINAL_TEST_REPORT.md** - 完整的测试报告
- **CENTOS_TEST_EXECUTION.md** - 详细的测试执行记录
- **CENTOS_LAUNCH_TIMEOUT_ANALYSIS.md** - 超时问题分析
- **fix_centos_image.sh** - 自动化修复脚本
- **test_centos_launch.sh** - 自动化测试脚本

---

## 🎓 技术说明

### 为什么使用 Ubuntu 虚拟机修复?

| 原因 | 说明 |
|------|------|
| **macOS 限制** | macOS 不支持原生挂载 qcow2 格式 |
| **NBD 支持** | Linux 内核支持 NBD (Network Block Device) |
| **工具可用性** | Ubuntu 提供完整的 qemu-utils 和 nbd-client |
| **已验证** | Ubuntu 虚拟机已经验证正常工作 |
| **便捷性** | Multipass 可以轻松管理 Ubuntu 虚拟机 |

---

### cloud-init 数据源说明

**Multipass 使用的数据源**:
1. **NoCloud** (主要)
   - 从 ISO 文件 (`/dev/sr0`) 读取配置
   - 包含用户数据、网络配置、元数据

2. **ConfigDrive** (备用)
   - 从虚拟驱动器读取配置
   - 部分云平台使用

**CentOS 默认数据源**:
- OpenStack
- EC2
- GCE
- Azure

**修复方案**:
- 明确指定 `NoCloud` 为首选数据源
- 配置从 `/dev/sr0` 读取
- 提供备用的 ConfigDrive 支持

---

## ✅ 验收标准

修复成功的标准:

1. **✅ 虚拟机状态**: `Running`
2. **✅ IP 地址**: 获取到 `192.168.252.x`
3. **✅ 启动时间**: 2-3 分钟内完成
4. **✅ cloud-init**: `status: done`
5. **✅ 网络**: ping 8.8.8.8 成功
6. **✅ SSH**: 可以通过 `multipass shell` 连接

---

## 🚀 快速开始

```bash
# 1. 运行修复脚本
cd /Users/tompyang/WorkBuddy/20260320161009
bash fix_centos_image.sh

# 2. 选择方法 A (Ubuntu 虚拟机)

# 3. 等待自动修复和测试完成 (约 8-10 分钟)

# 4. 使用修复后的镜像
cd multipass/build/bin
./multipass launch \
  file:///Users/tompyang/multipass-images/CentOS-Stream-9-fixed.qcow2 \
  --name my-centos
```

---

## 🎉 预期结果

修复成功后,您将获得:

1. **✅ 完全兼容 Multipass 的 CentOS Stream 9 镜像**
2. **✅ 2-3 分钟快速启动**
3. **✅ 自动网络配置**
4. **✅ cloud-init 正常工作**
5. **✅ 所有 Multipass 功能可用**

---

## 📞 支持

如果遇到问题:

1. 查看 **故障排除** 章节
2. 检查 multipassd 日志
3. 参考相关测试文档
4. 考虑使用官方 CentOS Cloud 镜像作为替代方案

---

**修复工具版本**: 1.0  
**测试日期**: 2026-03-22  
**Multipass 版本**: 从源码编译 (latest)  
**CentOS 版本**: Stream 9
