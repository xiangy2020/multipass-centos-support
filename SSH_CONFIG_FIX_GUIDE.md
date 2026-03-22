# SSH 配置失败问题分析和解决方案

## 🔴 问题描述

运行 `enable_root_ssh.sh` 脚本时，在重启 SSH 服务步骤失败：

```bash
═══ 6. 重启 SSH 服务 ═══
exec failed: ssh connection failed: 'Socket error: Connection reset by peer'
✗ SSH 服务重启失败
```

**后续问题**:
- 虚拟机无法正常连接
- 无法停止虚拟机（超时）
- 发现有 2 个 QEMU 进程在运行

---

## 🔍 根本原因

### 原因 1: SSH 配置语法错误

`sed` 命令可能修改了 SSH 配置文件导致语法错误，SSH 服务无法启动。

**常见错误**:
- 重复的配置项
- 配置项格式错误
- 配置文件被破坏

### 原因 2: 多个 Multipass 进程冲突

发现系统中有 2 个不同的 Multipass 在运行：
1. **编译版**: `/Users/tompyang/WorkBuddy/.../multipass/build/bin/qemu-system-aarch64`
2. **官方版**: `/Library/Application Support/com.canonical.multipass/bin/qemu-system-aarch64`

**冲突导致**:
- 虚拟机状态不一致
- 无法正常管理虚拟机
- 进程僵死

---

## ✅ 解决方案

### 方案 1: 强制清理并重新创建虚拟机 (推荐) ⭐⭐⭐⭐⭐

**步骤**:

```bash
# 1. 强制杀死所有相关进程
sudo killall -9 qemu-system-aarch64
sudo pkill -9 -f "centos-official"

# 2. 删除损坏的虚拟机
mp delete centos-official --purge

# 3. 重新创建虚拟机
mp launch file:///Users/tompyang/Downloads/CentOS-Stream-GenericCloud-9-latest.aarch64.qcow2 \
    --name centos-official \
    --memory 2G \
    --cpus 2 \
    --disk 20G

# 4. 等待启动完成
mp list

# 5. 使用改进的脚本配置 root SSH
bash enable_root_ssh_v2.sh
```

---

### 方案 2: 手动恢复 SSH 配置

如果虚拟机还能访问：

```bash
# 1. 使用 multipass 直接修复配置文件
mp exec centos-official -- sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config

# 2. 重启虚拟机
mp restart centos-official

# 3. 使用改进的方法配置
```

---

### 方案 3: 使用更安全的配置方法

我创建了改进版的脚本 `enable_root_ssh_v2.sh`，特点：

1. ✅ 先验证配置语法
2. ✅ 使用更安全的配置方法
3. ✅ 失败时自动回滚
4. ✅ 详细的错误日志

---

## 🛠️ 改进版脚本特点

### 改进 1: 配置文件验证

```bash
# 修改配置后先验证语法
mp exec "${VM_NAME}" -- sudo sshd -t

# 如果验证失败，自动恢复备份
if [ $? -ne 0 ]; then
    echo "✗ SSH 配置验证失败，恢复备份"
    mp exec "${VM_NAME}" -- sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
    exit 1
fi
```

### 改进 2: 更安全的重启方法

```bash
# 不使用 systemctl restart（会断开连接）
# 使用 reload（平滑重启）
mp exec "${VM_NAME}" -- sudo systemctl reload sshd

# 或者在后台重启
mp exec "${VM_NAME}" -- sudo bash -c "nohup systemctl restart sshd &"
```

### 改进 3: 使用配置文件追加而不是修改

```bash
# 不修改原文件，创建新的配置片段
mp exec "${VM_NAME}" -- sudo bash -c "cat > /etc/ssh/sshd_config.d/99-root-login.conf << 'EOF'
PermitRootLogin yes
PasswordAuthentication yes
EOF"

# 验证
mp exec "${VM_NAME}" -- sudo sshd -t

# 重启
mp exec "${VM_NAME}" -- sudo systemctl reload sshd
```

---

## 🚀 立即修复步骤

### 步骤 1: 清理僵死进程

```bash
# 查看当前进程
ps aux | grep -i "centos-official" | grep qemu

# 强制杀死（需要 sudo）
sudo killall -9 qemu-system-aarch64

# 确认已清理
mp list
```

### 步骤 2: 删除损坏的虚拟机

```bash
# 删除虚拟机（保留数据可选）
mp delete centos-official

# 或者完全删除
mp delete centos-official --purge
```

### 步骤 3: 重新创建虚拟机

```bash
# 使用之前下载的 CentOS 镜像
mp launch file:///Users/tompyang/Downloads/CentOS-Stream-GenericCloud-9-latest.aarch64.qcow2 \
    --name centos-official \
    --memory 2G \
    --cpus 2 \
    --disk 20G

# 等待启动（约 20 秒）
sleep 20

# 检查状态
mp list
mp info centos-official
```

### 步骤 4: 使用改进的方法配置 root SSH

```bash
# 方法 A: 使用改进版脚本
bash enable_root_ssh_v2.sh

# 方法 B: 手动配置（更安全）
mp shell centos-official << 'EOF'
# 创建配置文件
sudo mkdir -p /etc/ssh/sshd_config.d
sudo bash -c 'cat > /etc/ssh/sshd_config.d/99-root-login.conf << EOL
PermitRootLogin yes
PasswordAuthentication yes
EOL'

# 验证配置
sudo sshd -t

# 如果验证成功，重启 SSH
if [ $? -eq 0 ]; then
    sudo systemctl reload sshd
    echo "✓ SSH 配置成功"
else
    sudo rm /etc/ssh/sshd_config.d/99-root-login.conf
    echo "✗ SSH 配置失败"
fi

# 设置 root 密码
echo 'root:root123' | sudo chpasswd

exit
EOF

# 测试登录
ssh root@192.168.252.3
```

---

## 📊 问题预防

### 最佳实践 1: 使用配置片段

**推荐**: 使用 `/etc/ssh/sshd_config.d/` 目录

```bash
# ✅ 好的做法
echo "PermitRootLogin yes" | sudo tee /etc/ssh/sshd_config.d/99-root-login.conf

# ❌ 坏的做法
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
```

**优势**:
- 不修改原始配置
- 容易回滚（删除文件即可）
- 配置隔离，不会冲突

### 最佳实践 2: 始终验证配置

```bash
# 修改配置后立即验证
sudo sshd -t

# 只有验证成功才重启
if [ $? -eq 0 ]; then
    sudo systemctl reload sshd
fi
```

### 最佳实践 3: 使用 reload 而不是 restart

```bash
# ✅ 推荐: 平滑重启
sudo systemctl reload sshd

# ⚠️ 谨慎使用: 会断开所有连接
sudo systemctl restart sshd
```

---

## 🔧 改进版脚本: enable_root_ssh_v2.sh

我已经创建了改进版脚本，主要改进：

1. ✅ 使用配置片段而不是修改主配置
2. ✅ 每次修改后都验证配置语法
3. ✅ 使用 reload 而不是 restart
4. ✅ 失败时自动回滚
5. ✅ 详细的错误信息

**使用方法**:

```bash
chmod +x enable_root_ssh_v2.sh
bash enable_root_ssh_v2.sh
```

---

## 🎯 当前建议

### 立即执行

```bash
# 1. 清理僵死进程
sudo killall -9 qemu-system-aarch64

# 2. 删除损坏的虚拟机
mp delete centos-official --purge

# 3. 重新创建
mp launch file:///Users/tompyang/Downloads/CentOS-Stream-GenericCloud-9-latest.aarch64.qcow2 \
    --name centos-official \
    --memory 2G \
    --cpus 2

# 4. 使用改进的脚本
bash enable_root_ssh_v2.sh
```

---

## 📚 相关文档

- `ENABLE_ROOT_SSH_LOGIN_GUIDE.md` - Root SSH 登录指南
- `CENTOS_SSH_LOGIN_GUIDE.md` - CentOS SSH 通用指南
- `enable_root_ssh.sh` - 原始脚本（已知问题）
- `enable_root_ssh_v2.sh` - 改进版脚本（推荐使用）

---

## 🎉 总结

**问题**: SSH 配置失败导致虚拟机无法连接

**根本原因**: 
- SSH 配置被破坏
- 多个 Multipass 进程冲突

**解决方案**:
1. ✅ 清理僵死进程
2. ✅ 删除并重新创建虚拟机
3. ✅ 使用改进版脚本配置

**预防措施**:
- 使用配置片段而不是修改主配置
- 始终验证配置语法
- 使用 reload 而不是 restart
