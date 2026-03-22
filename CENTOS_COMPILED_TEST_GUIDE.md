# CentOS 9 虚拟机完整功能测试指南 (编译版本)

**测试时间**: 2026-03-22  
**目标**: 验证编译版本的 Multipass 对 CentOS 9 的完整支持

---

## 📋 测试准备

### 前置条件

1. ✅ **编译产物就绪**
   ```bash
   /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin/
   ├── multipass (24MB)
   ├── multipassd (26MB)
   └── qemu-system-aarch64 (31MB)
   ```

2. ✅ **CentOS 镜像已下载**
   ```bash
   /Users/tompyang/multipass-images/CentOS-Stream-9.qcow2
   ```

3. ✅ **旧版本已卸载**
   - Homebrew 安装的 Multipass 已移除

---

## 🚀 快速测试 (5 分钟)

### 方法 1: 自动化测试脚本

```bash
# 1. 在终端 1 中启动 multipassd (需要保持运行)
cd /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin
sudo ./multipassd --verbosity info

# 2. 在终端 2 中运行测试脚本
cd /Users/tompyang/WorkBuddy/20260320161009
bash test_centos_compiled.sh
```

测试脚本将自动验证:
- ✅ 虚拟机创建
- ✅ 系统启动
- ✅ 网络连接
- ✅ SSH 执行
- ✅ 包管理器
- ✅ 文件传输

---

## 🔧 手动测试 (更详细)

### 步骤 1: 启动 multipassd

**⚠️ 重要**: multipassd 必须以 root 权限运行

```bash
cd /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin
sudo ./multipassd --verbosity debug
```

**为什么需要 sudo?**
- 访问 HyperKit/HVF (macOS 虚拟化框架)
- 管理网络 (vmnet-shared)
- 创建系统级资源

**保持此终端运行!** 在新终端中继续后续步骤。

---

### 步骤 2: 验证 multipassd 连接

```bash
cd /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin

# 检查版本
./multipass version

# 应该输出:
# multipass   1.17.0-dev.2057+ga6255be2.mac
# multipassd  1.17.0-dev.2057+ga6255be2.mac
```

---

### 步骤 3: 创建 CentOS 虚拟机

```bash
cd /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin

./multipass launch \
  file:///Users/tompyang/multipass-images/CentOS-Stream-9.qcow2 \
  --name centos-test \
  --cpus 2 \
  --memory 2G \
  --disk 10G
```

**预期输出**:
```
Creating centos-test
Preparing image for centos-test  ✓
Starting centos-test  |
```

**耗时**: 约 2-3 分钟

---

### 步骤 4: 检查虚拟机状态

```bash
./multipass list
```

**预期输出**:
```
Name          State      IPv4           Image
centos-test   Running    10.x.x.x      CentOS Stream 9
```

---

### 步骤 5: 获取虚拟机详细信息

```bash
./multipass info centos-test
```

**预期输出**:
```
Name:           centos-test
State:          Running
Snapshots:      0
IPv4:           10.x.x.x
Release:        CentOS Stream 9
Image hash:     4d1a204dcc5e
CPU(s):         2
Load:           0.01 0.05 0.03
Disk usage:     1.8GiB out of 9.5GiB
Memory usage:   300.5MiB out of 1.9GiB
Mounts:         --
```

---

### 步骤 6: 测试基本功能

#### 6.1 系统识别

```bash
./multipass exec centos-test -- cat /etc/os-release
```

**预期输出**:
```
NAME="CentOS Stream"
VERSION="9"
ID="centos"
ID_LIKE="rhel fedora"
...
```

#### 6.2 网络连接

```bash
./multipass exec centos-test -- ping -c 3 8.8.8.8
```

**预期**: 3 个 ping 包成功

#### 6.3 DNS 解析

```bash
./multipass exec centos-test -- nslookup google.com
```

**预期**: 成功解析域名

#### 6.4 系统信息

```bash
# 内核版本
./multipass exec centos-test -- uname -a

# CPU 信息
./multipass exec centos-test -- lscpu

# 内存信息
./multipass exec centos-test -- free -h

# 磁盘信息
./multipass exec centos-test -- df -h
```

---

### 步骤 7: 测试包管理器

```bash
# 更新软件包列表
./multipass exec centos-test -- sudo dnf check-update

# 安装测试软件
./multipass exec centos-test -- sudo dnf install -y htop

# 验证安装
./multipass exec centos-test -- htop --version
```

**预期**: htop 成功安装并可执行

---

### 步骤 8: 测试文件传输

```bash
# 创建测试文件
echo "测试内容" > /tmp/test.txt

# 上传到虚拟机
./multipass transfer /tmp/test.txt centos-test:/tmp/

# 验证
./multipass exec centos-test -- cat /tmp/test.txt

# 从虚拟机下载
./multipass exec centos-test -- "echo '来自虚拟机' > /tmp/from_vm.txt"
./multipass transfer centos-test:/tmp/from_vm.txt /tmp/
cat /tmp/from_vm.txt
```

**预期**: 文件上传/下载成功,内容正确

---

### 步骤 9: 测试交互式 Shell

```bash
./multipass shell centos-test
```

**在虚拟机中测试**:
```bash
# 查看当前用户
whoami

# 查看当前目录
pwd

# 列出文件
ls -la

# 查看环境
env | head -10

# 退出
exit
```

**预期**: shell 正常工作,命令正常执行

---

### 步骤 10: 测试虚拟机管理

```bash
# 停止虚拟机
./multipass stop centos-test

# 检查状态
./multipass list
# 应该显示: State = Stopped

# 重新启动
./multipass start centos-test

# 检查状态
./multipass list
# 应该显示: State = Running
```

---

## 📊 完整功能清单

### 核心功能

| 功能 | 测试命令 | 预期结果 |
|------|---------|---------|
| 虚拟机创建 | `multipass launch file://...` | ✅ 成功创建 |
| 虚拟机启动 | `multipass start <name>` | ✅ 状态变为 Running |
| 虚拟机停止 | `multipass stop <name>` | ✅ 状态变为 Stopped |
| 虚拟机删除 | `multipass delete <name>` | ✅ 成功删除 |
| 虚拟机列表 | `multipass list` | ✅ 显示所有虚拟机 |
| 虚拟机信息 | `multipass info <name>` | ✅ 显示详细信息 |
| 远程命令 | `multipass exec <name> -- <cmd>` | ✅ 命令执行成功 |
| 交互式 Shell | `multipass shell <name>` | ✅ 进入 shell |
| 文件上传 | `multipass transfer host:file vm:path` | ✅ 上传成功 |
| 文件下载 | `multipass transfer vm:file host:path` | ✅ 下载成功 |

### CentOS 特定功能

| 功能 | 测试命令 | 预期结果 |
|------|---------|---------|
| 镜像识别 | `launch file://centos.qcow2` | ✅ 识别为 CentOS |
| 系统启动 | 启动后检查 | ✅ CentOS 正常启动 |
| 网络配置 | `ip addr` | ✅ 获取 IPv4 地址 |
| DNS 配置 | `nslookup` | ✅ DNS 正常 |
| dnf 包管理 | `dnf install` | ✅ 可安装软件包 |
| yum 兼容 | `yum install` | ✅ yum 指向 dnf |
| SELinux | `sestatus` | ✅ SELinux 状态正常 |
| Firewall | `firewall-cmd` | ✅ 防火墙正常 |

---

## 🎯 高级测试

### 测试 1: 集群部署

```bash
cd /Users/tompyang/WorkBuddy/20260320161009

# 编辑部署脚本,指定编译版本
MULTIPASS_BIN="/Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin/multipass"

# 部署 3 节点集群
bash deploy_centos_cluster_final.sh
```

### 测试 2: 多虚拟机管理

```bash
# 创建多个虚拟机
for i in {1..3}; do
  ./multipass launch file:///Users/tompyang/multipass-images/CentOS-Stream-9.qcow2 \
    --name centos-node-$i \
    --cpus 2 \
    --memory 2G \
    --disk 10G
done

# 检查所有虚拟机
./multipass list

# 批量执行命令
for i in {1..3}; do
  ./multipass exec centos-node-$i -- hostname
done
```

### 测试 3: 快照功能

```bash
# 创建快照
./multipass snapshot centos-test --name snapshot1

# 查看快照
./multipass info centos-test

# 恢复快照
./multipass restore centos-test --name snapshot1
```

---

## 🐛 故障排查

### 问题 1: multipassd 连接失败

**症状**: `multipass: cannot connect to the multipass socket`

**解决**:
```bash
# 检查 multipassd 是否运行
ps aux | grep multipassd

# 如果没运行,启动它
cd /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin
sudo ./multipassd --verbosity debug
```

### 问题 2: 虚拟机状态 Unknown

**症状**: `State: Unknown`

**解决**:
```bash
# 停止并重启虚拟机
./multipass stop <name>
./multipass start <name>

# 如果还是失败,删除并重建
./multipass delete <name>
./multipass purge
./multipass launch ...
```

### 问题 3: 无法获取 IP 地址

**症状**: `IPv4: --`

**解决**:
```bash
# 等待 cloud-init 完成 (可能需要 2-3 分钟)
./multipass exec <name> -- cloud-init status --wait

# 检查网络
./multipass exec <name> -- ip addr
```

### 问题 4: 权限错误

**症状**: `Permission denied` 或 `Operation not permitted`

**解决**:
```bash
# multipassd 必须以 root 运行
sudo ./multipassd

# 检查系统安全设置
# System Settings > Privacy & Security > Full Disk Access
# 添加 Terminal.app
```

---

## 📝 测试报告模板

完成测试后,记录结果:

```markdown
# CentOS 9 虚拟机测试报告

**测试日期**: 2026-03-22
**Multipass 版本**: 1.17.0-dev.2057+ga6255be2.mac
**QEMU 版本**: 10.0.3

## 测试结果

| 测试项 | 状态 | 备注 |
|--------|------|------|
| 虚拟机创建 | ✅/❌ | |
| 虚拟机启动 | ✅/❌ | |
| 网络连接 | ✅/❌ | |
| SSH 执行 | ✅/❌ | |
| 包管理器 | ✅/❌ | |
| 文件传输 | ✅/❌ | |
| Shell 交互 | ✅/❌ | |

## 问题记录

[记录遇到的问题和解决方法]

## 结论

[总体评价]
```

---

## 🎉 测试完成后

### 清理测试虚拟机

```bash
# 停止虚拟机
./multipass stop centos-test

# 删除虚拟机
./multipass delete centos-test

# 清空回收站
./multipass purge
```

### 保留虚拟机

如果测试通过且虚拟机运行正常,可以保留用于开发:

```bash
# 查看运行的虚拟机
./multipass list

# 连接到虚拟机
./multipass shell centos-test

# 后续使用
./multipass exec centos-test -- <your-command>
```

---

## 📚 参考

- **编译文档**: [COMPILE_SUCCESS_REPORT.md](./COMPILE_SUCCESS_REPORT.md)
- **集群部署**: [deploy_centos_cluster_final.sh](./deploy_centos_cluster_final.sh)
- **Multipass 文档**: https://multipass.run/docs

---

**准备就绪!开始测试吧!** 🚀
