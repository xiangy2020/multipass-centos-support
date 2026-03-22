# CentOS SSH 登录问题 - 完整解决方案

## 🎯 问题描述

**错误信息**:
```bash
$ ssh root@192.168.252.3
root@192.168.252.3: Permission denied (publickey,gssapi-keyex,gssapi-with-mic).
```

**核心原因**: CentOS 虚拟机默认配置了以下安全策略:
1. ❌ **禁用 root 用户 SSH 登录** (`PermitRootLogin no`)
2. ❌ **禁用密码认证** (`PasswordAuthentication no`)
3. ✅ **只允许公钥认证** (`PubkeyAuthentication yes`)
4. ✅ **默认用户是 `ubuntu`**, 不是 `root`

---

## ✅ 解决方案 (4 种方法)

### 方法 1: 使用 multipass shell (最简单) ⭐⭐⭐⭐⭐

**推荐指数**: ⭐⭐⭐⭐⭐

```bash
# 直接进入虚拟机 (自动处理 SSH 密钥)
mp shell centos-official

# 进入后自动切换到 root (如果需要)
sudo su -
```

**优势**:
- ✅ 零配置
- ✅ 自动处理 SSH 密钥
- ✅ 最安全的方法

**使用示例**:
```bash
$ mp shell centos-official
Welcome to CentOS Stream 9

ubuntu@centos-official:~$ whoami
ubuntu

ubuntu@centos-official:~$ sudo su -
root@centos-official:~# whoami
root
```

---

### 方法 2: 使用正确的用户名 ubuntu ⭐⭐⭐⭐

**推荐指数**: ⭐⭐⭐⭐

**问题**: 您使用了 `root@192.168.252.3`  
**正确**: 应该使用 `ubuntu@192.168.252.3`

```bash
# 错误 ❌
ssh root@192.168.252.3

# 正确 ✅ (但还需要 SSH 密钥)
ssh ubuntu@192.168.252.3
```

**但是!** 这样还是会失败,因为需要 Multipass 的 SSH 密钥。

---

### 方法 3: 配置 SSH 密钥登录 ⭐⭐⭐

**推荐指数**: ⭐⭐⭐

#### 步骤 1: 复制您的公钥到虚拟机

```bash
# 1. 生成 SSH 密钥 (如果还没有)
ssh-keygen -t ed25519 -C "your_email@example.com"

# 2. 查看您的公钥
cat ~/.ssh/id_ed25519.pub

# 3. 使用 multipass 添加公钥到虚拟机
mp exec centos-official -- bash -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
mp exec centos-official -- bash -c "echo '$(cat ~/.ssh/id_ed25519.pub)' >> ~/.ssh/authorized_keys"
mp exec centos-official -- bash -c "chmod 600 ~/.ssh/authorized_keys"
```

#### 步骤 2: 测试 SSH 登录

```bash
# 使用 ubuntu 用户登录
ssh ubuntu@192.168.252.3

# 登录后切换到 root
sudo su -
```

---

### 方法 4: 启用 root SSH 登录 (不推荐) ⭐

**推荐指数**: ⭐ (降低安全性)

**警告**: 这会降低系统安全性,只建议用于测试环境。

#### 步骤 1: 修改 SSH 配置

```bash
# 进入虚拟机
mp shell centos-official

# 切换到 root
sudo su -

# 备份配置文件
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# 修改配置
sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 重启 SSH 服务
systemctl restart sshd

# 设置 root 密码
passwd root
# 输入两次密码,例如: root123
```

#### 步骤 2: 测试登录

```bash
# 退出虚拟机
exit
exit

# 使用 root 和密码登录
ssh root@192.168.252.3
# 输入密码: root123
```

---

## 📊 方法对比

| 方法 | 难度 | 安全性 | 速度 | 推荐场景 |
|------|------|--------|------|----------|
| **方法 1: mp shell** | ⭐ | ⭐⭐⭐⭐⭐ | ⚡⚡⚡ | 日常使用 |
| **方法 2: ubuntu 用户** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⚡⚡ | 需要密钥 |
| **方法 3: 配置密钥** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⚡⚡ | 频繁 SSH |
| **方法 4: 启用 root** | ⭐⭐⭐⭐ | ⭐⭐ | ⚡ | 仅测试环境 |

---

## 🔍 深入理解: 为什么不能用 root 登录?

### CentOS Cloud Image 默认配置

```bash
# /etc/ssh/sshd_config
PermitRootLogin no              # 禁止 root SSH 登录
PasswordAuthentication no       # 禁止密码认证
PubkeyAuthentication yes        # 只允许公钥认证
```

### 为什么这样设计?

1. **安全性**: root 用户是最高权限,禁止直接登录可以防止暴力破解
2. **最佳实践**: 使用普通用户登录,需要时使用 `sudo`
3. **云环境标准**: 所有主流云平台 (AWS, GCP, Azure) 都采用这种配置

### Multipass 的处理方式

```
┌─────────────────────────────────────────────────────────┐
│  Multipass 创建虚拟机时                                  │
├─────────────────────────────────────────────────────────┤
│  1. 生成 SSH 密钥对                                     │
│     /var/root/Library/.../ssh-keys/id_rsa              │
│                                                         │
│  2. 创建 ubuntu 用户                                    │
│                                                         │
│  3. 注入公钥到 ubuntu 用户                              │
│     /home/ubuntu/.ssh/authorized_keys                  │
│                                                         │
│  4. 配置 ubuntu 用户 sudo 免密                          │
│     ubuntu ALL=(ALL) NOPASSWD:ALL                      │
│                                                         │
│  5. mp shell 使用私钥自动登录                          │
└─────────────────────────────────────────────────────────┘
```

---

## 🎮 实战示例

### 示例 1: 快速执行命令

```bash
# 方法 A: 使用 mp exec
mp exec centos-official -- sudo yum install -y nginx

# 方法 B: 使用 mp shell + heredoc
mp shell centos-official << 'EOF'
sudo yum install -y nginx
sudo systemctl start nginx
sudo systemctl status nginx
EOF
```

---

### 示例 2: 传输文件

```bash
# 方法 A: 使用 mp transfer
mp transfer ~/myfile.txt centos-official:/home/ubuntu/
mp transfer centos-official:/home/ubuntu/result.txt ~/

# 方法 B: 配置 SSH 密钥后使用 scp
scp ~/myfile.txt ubuntu@192.168.252.3:/home/ubuntu/
scp ubuntu@192.168.252.3:/home/ubuntu/result.txt ~/
```

---

### 示例 3: 运行长时间任务

```bash
# 使用 mp shell 进入虚拟机
mp shell centos-official

# 在虚拟机内使用 screen 或 tmux
sudo yum install -y screen
screen -S mytask

# 运行长时间任务
./long_running_script.sh

# 断开 (Ctrl+A, D)
# 重新连接
screen -r mytask
```

---

## 🛠️ 自动化脚本: 配置 SSH 密钥登录

如果您想要方便地使用 `ssh ubuntu@192.168.252.3` 登录,可以使用以下脚本:

```bash
#!/bin/bash

VM_NAME="centos-official"
VM_IP="192.168.252.3"

echo "═══ 配置 SSH 密钥登录 ═══"
echo ""

# 1. 检查本地 SSH 密钥
if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "生成 SSH 密钥..."
    ssh-keygen -t ed25519 -C "multipass-centos" -f ~/.ssh/id_ed25519 -N ""
fi

# 2. 获取公钥
PUB_KEY=$(cat ~/.ssh/id_ed25519.pub)

# 3. 添加到虚拟机
echo "添加公钥到虚拟机..."
mp exec "${VM_NAME}" -- bash -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
mp exec "${VM_NAME}" -- bash -c "echo '${PUB_KEY}' >> ~/.ssh/authorized_keys"
mp exec "${VM_NAME}" -- bash -c "chmod 600 ~/.ssh/authorized_keys"

# 4. 测试连接
echo ""
echo "✓ 配置完成!"
echo ""
echo "测试连接:"
echo "  ssh ubuntu@${VM_IP}"
echo ""
echo "切换到 root:"
echo "  sudo su -"
```

保存为 `setup_ssh_centos.sh` 并执行:

```bash
chmod +x setup_ssh_centos.sh
./setup_ssh_centos.sh
```

---

## 🎯 快速参考

### 最常用的命令

```bash
# 进入虚拟机 (推荐)
mp shell centos-official

# 执行单个命令
mp exec centos-official -- sudo yum update -y

# 以 root 身份执行命令
mp exec centos-official -- sudo su - -c "whoami"

# 传输文件
mp transfer local-file.txt centos-official:/home/ubuntu/
mp transfer centos-official:/home/ubuntu/remote-file.txt ./

# 查看虚拟机信息
mp info centos-official

# 停止/启动虚拟机
mp stop centos-official
mp start centos-official
```

---

## 🔧 常见问题排查

### 问题 1: mp shell 连接超时

```bash
# 检查虚拟机状态
mp list
mp info centos-official

# 重启虚拟机
mp restart centos-official

# 检查 SSH 服务
mp exec centos-official -- sudo systemctl status sshd
```

---

### 问题 2: sudo 需要密码

```bash
# 检查 sudo 配置
mp exec centos-official -- sudo cat /etc/sudoers.d/90-cloud-init-users

# 应该包含:
# ubuntu ALL=(ALL) NOPASSWD:ALL
```

---

### 问题 3: SSH 密钥权限错误

```bash
# 修复权限
mp exec centos-official -- chmod 700 ~/.ssh
mp exec centos-official -- chmod 600 ~/.ssh/authorized_keys
```

---

## 📚 相关文档

| 文档 | 说明 |
|------|------|
| **CENTOS_OFFICIAL_CLOUD_IMAGE_REPORT.md** | CentOS 镜像测试报告 |
| **MULTIPASS_COMPILED_USAGE_GUIDE.md** | Multipass 详细使用指南 |
| **CLUSTER_DEPLOYMENT_GUIDE.md** | 集群部署指南 |

---

## 🎉 总结

### 回答您的问题: "为啥没法登录"

**原因**:
1. ❌ 使用了错误的用户名 `root` (应该是 `ubuntu`)
2. ❌ CentOS 禁止 root SSH 登录
3. ❌ 没有提供 SSH 密钥

**最佳解决方案**:

```bash
# 最简单: 使用 multipass shell
mp shell centos-official

# 需要 root? 使用 sudo
mp exec centos-official -- sudo whoami
```

**如果需要直接 SSH**:

```bash
# 1. 配置 SSH 密钥 (一次性)
mp exec centos-official -- bash -c "echo '$(cat ~/.ssh/id_ed25519.pub)' >> ~/.ssh/authorized_keys"

# 2. 使用 ubuntu 用户登录
ssh ubuntu@192.168.252.3

# 3. 切换到 root
sudo su -
```

---

## 🚀 立即开始

**推荐方式** (零配置):

```bash
# 进入虚拟机
mp shell centos-official

# 查看系统信息
cat /etc/os-release

# 安装软件
sudo yum install -y nginx

# 查看 IP
ip addr show

# 退出
exit
```

**这是最简单、最安全的方法!** 🎉
