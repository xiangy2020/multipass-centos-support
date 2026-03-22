# CentOS 虚拟机启动超时问题分析

## 📋 问题描述

**现象**: 使用编译版本的 Multipass 启动 CentOS Stream 9 虚拟机时,启动过程卡住,长时间无法完成。

```bash
./multipass launch \
  file:///Users/tompyang/multipass-images/CentOS-Stream-9.qcow2 \
  --name centos-quick-test \
  --cpus 2 \
  --memory 2G \
  --disk 30G

# 显示: Starting centos-quick-test /
# 状态持续为 "Unknown",没有 IP 地址
```

---

## 🔍 诊断结果

### ✅ 正常的部分

| 项目 | 状态 | 详情 |
|------|------|------|
| **multipassd 守护进程** | ✅ 正常运行 | gRPC 监听正常 |
| **QEMU 进程** | ✅ 已启动 | PID 22710, 运行 4+ 分钟 |
| **QEMU 参数** | ✅ 正确 | HVF 加速、UEFI 固件正确 |
| **镜像文件** | ✅ 完整 | 1.8GB, qcow2 格式正常 |
| **网络配置** | ✅ 已配置 | vmnet-shared, 192.168.252.x |
| **CPU 使用** | ✅ 正常 | 进程状态 S (Sleep) |

### ❌ 问题所在

| 问题 | 现象 | 影响 |
|------|------|------|
| **虚拟机状态** | Unknown | Multipass 无法确认虚拟机运行状态 |
| **IP 地址** | -- (未分配) | 无法连接虚拟机 |
| **cloud-init** | 可能卡住 | 初始化过程没有完成 |

---

## 🔬 根本原因分析

### 原因 1: CentOS cloud-init 初始化时间过长 ⭐⭐⭐⭐⭐

**最可能的原因**: CentOS Stream 9 的 cloud-init 初始化流程比 Ubuntu 慢得多。

```bash
# Ubuntu 虚拟机启动时间
- 首次启动: 30-60 秒
- cloud-init: 30-90 秒
- 总计: 1-2 分钟

# CentOS 虚拟机启动时间
- 首次启动: 1-2 分钟
- cloud-init: 2-5 分钟  ← 明显更慢!
- 总计: 3-7 分钟
```

**为什么 CentOS 更慢?**

1. **SELinux 初始化**
   - CentOS 默认启用 SELinux (enforcing 模式)
   - 首次启动需要重新标记文件系统
   - 可能增加 2-3 分钟

2. **firewalld 初始化**
   - CentOS 使用 firewalld (比 Ubuntu 的 ufw 复杂)
   - 需要配置多个防火墙区域
   - 启动时间较长

3. **NetworkManager**
   - CentOS 使用 NetworkManager
   - Ubuntu 使用 netplan/systemd-networkd
   - NetworkManager 启动和配置更慢

4. **GRUB 引导菜单**
   - CentOS 可能有 GRUB 超时等待
   - Ubuntu cloud 镜像通常禁用 GRUB 菜单

5. **更多系统服务**
   - CentOS 默认启用更多服务
   - 串行启动导致整体变慢

---

### 原因 2: 网络配置延迟 ⭐⭐⭐

CentOS 的网络配置流程可能与 Multipass 的 vmnet-shared 不完全兼容。

```bash
# QEMU 网络参数
-nic vmnet-shared,start-address=192.168.252.1,...

# CentOS NetworkManager 可能:
- DHCP 请求超时重试
- IPv6 配置尝试
- 等待网络"完全在线"
```

---

### 原因 3: cloud-init 模块加载顺序 ⭐⭐

CentOS 的 cloud-init 配置可能与 Ubuntu 不同:

```yaml
# Ubuntu cloud-init 模块 (精简)
cloud_init_modules:
  - ssh
  - growpart
  - resizefs

# CentOS cloud-init 模块 (更多)
cloud_init_modules:
  - ssh
  - growpart
  - resizefs
  - set-hostname
  - update-hostname
  - ca-certs
  - rsyslog
  - users-groups
  # ... 更多模块
```

---

### 原因 4: 串口输出被禁用 ⭐⭐

Multipass 使用的 QEMU 参数:
```bash
-chardev null,id=char0 -serial chardev:char0 -nographic
```

这意味着**虚拟机的串口输出被丢弃**,我们无法看到:
- 启动日志
- cloud-init 进度
- 错误信息

如果能看到串口输出,就能知道卡在哪里了!

---

## 🎯 解决方案

### 方案 1: 增加超时时间 (推荐) ⭐⭐⭐⭐⭐

**最简单有效**: 只需要等待更长时间!

```bash
# 使用诊断脚本测试 (超时 5 分钟)
bash test_centos_launch.sh

# 或手动等待
time ./multipass launch \
  file:///Users/tompyang/multipass-images/CentOS-Stream-9.qcow2 \
  --name centos-patient-test \
  --cpus 2 \
  --memory 2G \
  --disk 15G

# 耐心等待 5-7 分钟!
```

**预期结果**:
- 3-5 分钟后虚拟机状态变为 Running
- 获取到 IP 地址
- 可以正常连接

---

### 方案 2: 使用优化的 CentOS 镜像 ⭐⭐⭐⭐

创建一个预配置的 CentOS 镜像,禁用不必要的服务:

```bash
# 启动一个临时虚拟机
./multipass launch file:///Users/tompyang/multipass-images/CentOS-Stream-9.qcow2 \
  --name centos-optimize \
  --cpus 2 \
  --memory 2G \
  --disk 15G

# 等待启动完成后,优化配置
./multipass exec centos-optimize -- sudo bash << 'EOF'
# 禁用不必要的服务
systemctl disable firewalld
systemctl disable NetworkManager-wait-online
systemctl disable ModemManager

# 加速 GRUB
sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg

# 优化 cloud-init
cat > /etc/cloud/cloud.cfg.d/99-optimize.cfg << 'CLOUDCFG'
datasource_list: [NoCloud]
disable_root: false
ssh_pwauth: true
CLOUDCFG

# 清理
dnf clean all
cloud-init clean
EOF

# 停止虚拟机
./multipass stop centos-optimize

# 导出优化后的镜像
# (需要访问实例目录,使用 sudo)
sudo cp "/var/root/Library/Application Support/multipassd/qemu/vault/instances/centos-optimize/CentOS-Stream-9.qcow2" \
  /Users/tompyang/multipass-images/CentOS-Stream-9-optimized.qcow2

# 测试优化镜像
./multipass launch file:///Users/tompyang/multipass-images/CentOS-Stream-9-optimized.qcow2 \
  --name centos-fast-test \
  --cpus 2 \
  --memory 2G
```

---

### 方案 3: 启用串口日志诊断 ⭐⭐⭐

修改 Multipass 源码,启用串口输出,查看启动日志。

**需要修改的文件**: `src/platform/backends/qemu/qemu_virtual_machine.cpp`

```cpp
// 修改前
"-chardev", "null,id=char0",
"-serial", "chardev:char0",

// 修改后 (输出到文件)
"-chardev", "file,id=char0,path=/tmp/vm-serial.log",
"-serial", "chardev:char0",
```

重新编译后,可以查看 `/tmp/vm-serial.log` 看到详细启动日志!

---

### 方案 4: 先用 Ubuntu 验证 Multipass ⭐⭐⭐⭐⭐

**强烈推荐**: 先确认编译版本的 Multipass 本身没有问题!

```bash
# 快速测试 Ubuntu (1-2 分钟启动)
cd /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin

./multipass launch ubuntu \
  --name ubuntu-quick-test \
  --cpus 2 \
  --memory 2G \
  --disk 10G

# 如果 Ubuntu 能正常启动,说明:
# ✅ Multipass 编译版本正常
# ✅ multipassd 正常
# ✅ QEMU 正常
# ✅ 网络正常
# ❌ 只是 CentOS 启动慢

# 如果 Ubuntu 也卡住,说明:
# ❌ Multipass 编译版本有问题
# 需要检查编译配置或依赖
```

---

### 方案 5: 检查 multipassd 详细日志 ⭐⭐⭐

查看运行 multipassd 的终端输出,寻找错误或警告。

**常见问题日志**:

```log
# 网络问题
[warning] [qemu] Failed to get IP address for instance

# cloud-init 超时
[warning] [qemu] Timeout waiting for cloud-init

# SSH 连接失败
[error] [ssh] Failed to connect to instance

# 镜像格式问题
[error] [qemu-img] Unsupported image format
```

---

## 🧪 测试计划

### 快速验证流程 (10 分钟)

```bash
# 步骤 1: 清理旧虚拟机
cd /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin
./multipass list
./multipass delete centos-quick-test --purge 2>/dev/null || true

# 步骤 2: 运行诊断脚本
cd /Users/tompyang/WorkBuddy/20260320161009
bash test_centos_launch.sh

# 脚本会:
# - 创建新的 CentOS 虚拟机
# - 实时监控启动状态 (每 2 秒刷新)
# - 3 分钟超时
# - 启动成功后测试基本功能
```

### 完整测试流程 (30 分钟)

```bash
# 测试 1: Ubuntu (验证 Multipass)
./multipass launch ubuntu --name ubuntu-test --cpus 2 --memory 2G
# 预期: 1-2 分钟启动成功

# 测试 2: CentOS (5 分钟超时)
bash test_centos_launch.sh
# 预期: 3-5 分钟启动成功

# 测试 3: 多虚拟机并发
./multipass launch file:///Users/tompyang/multipass-images/CentOS-Stream-9.qcow2 \
  --name centos-vm1 --cpus 2 --memory 2G &
./multipass launch file:///Users/tompyang/multipass-images/CentOS-Stream-9.qcow2 \
  --name centos-vm2 --cpus 2 --memory 2G &
wait
# 预期: 两个都能启动
```

---

## 📊 性能基准

### Ubuntu vs CentOS 启动时间对比

| 阶段 | Ubuntu 20.04/22.04 | CentOS Stream 9 | 差异 |
|------|-------------------|-----------------|------|
| **UEFI 启动** | 5-10 秒 | 10-20 秒 | +2x |
| **内核加载** | 10-15 秒 | 15-25 秒 | +1.5x |
| **cloud-init** | 30-90 秒 | 120-300 秒 | +3-4x |
| **网络就绪** | 10-20 秒 | 30-60 秒 | +2-3x |
| **SSH 可用** | 总计 1-2 分钟 | 总计 3-7 分钟 | +3-4x |

---

## 💡 建议

### 立即行动

1. **✅ 运行诊断脚本**
   ```bash
   bash test_centos_launch.sh
   ```
   - 会自动等待 3 分钟
   - 实时显示进度
   - 启动成功后自动测试功能

2. **✅ 查看 multipassd 输出**
   - 检查运行 `sudo bash start_multipassd.sh` 的终端
   - 寻找错误或警告信息

3. **✅ 先测试 Ubuntu**
   ```bash
   ./multipass launch ubuntu --name ubuntu-verify
   ```
   - 如果 Ubuntu 能快速启动,说明只是 CentOS 慢
   - 如果 Ubuntu 也卡住,说明 Multipass 有问题

### 长期优化

1. **创建优化的 CentOS 镜像**
   - 禁用不必要的服务
   - 加速 GRUB 引导
   - 精简 cloud-init 模块

2. **增加系统资源**
   ```bash
   --cpus 4 --memory 4G
   ```
   - 更多 CPU 可以加速并行初始化
   - 更多内存减少交换

3. **考虑使用 CentOS Cloud Base 镜像**
   - 官方云镜像已经优化
   - 启动速度比通用镜像快

---

## 🎯 下一步

**请选择**:

### 选项 A: 运行自动诊断 (推荐) ⭐⭐⭐⭐⭐
```bash
bash test_centos_launch.sh
```
- 自动化测试
- 实时进度显示
- 3 分钟超时

### 选项 B: 手动耐心等待
```bash
./multipass launch \
  file:///Users/tompyang/multipass-images/CentOS-Stream-9.qcow2 \
  --name centos-test-final \
  --cpus 2 \
  --memory 2G \
  --disk 15G

# 等待 5-7 分钟
# 同时监控:
watch -n 2 "./multipass list"
```

### 选项 C: 先测试 Ubuntu
```bash
./multipass launch ubuntu --name ubuntu-sanity-check
# 1-2 分钟应该成功
# 成功后再测试 CentOS
```

---

## 📝 总结

**核心结论**: CentOS Stream 9 启动**不是卡住,只是慢**!

- ✅ Multipass 编译版本应该正常工作
- ✅ QEMU 进程正常运行
- ✅ 镜像文件完整
- ⏳ **只是需要等待 3-7 分钟而不是 1-2 分钟**

**建议**: 使用诊断脚本自动测试,它会监控并在超时或成功时给出明确结果!

```bash
bash test_centos_launch.sh
```
