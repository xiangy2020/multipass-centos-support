# 编译版 Multipass 使用指南

## 📋 目录

- [问题说明](#问题说明)
- [解决方案](#解决方案)
- [一键安装](#一键安装)
- [手动配置](#手动配置)
- [使用方法](#使用方法)
- [常见问题](#常见问题)
- [进阶配置](#进阶配置)

---

## 🎯 问题说明

### 当前问题

**编译版 Multipass 存在两个主要问题**:

1. **守护进程需要单独启动**
   ```bash
   # 需要先启动 multipassd
   cd /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin
   ./multipassd &
   
   # 然后才能使用 multipass
   ./multipass list
   ```
   
   **问题**: 每次重启终端都需要手动启动守护进程

2. **命令不在环境变量中**
   ```bash
   # 必须使用完整路径或先 cd 到目录
   cd /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin
   ./multipass list
   ```
   
   **问题**: 使用不便，无法在任何目录直接调用

---

## 💡 解决方案

我们提供 **一键安装脚本** 来解决这些问题:

### 功能特性

1. **✅ 自动启动守护进程**
   - 创建启动脚本 `start_multipassd`
   - 可选配置开机自动启动
   - 日志记录到 `~/.multipass/logs/`

2. **✅ 全局命令可用**
   - 创建符号链接到 `/usr/local/bin`
   - 命令名称: `multipass-compiled` (避免与官方版冲突)
   - 添加环境变量到 shell 配置

3. **✅ 便捷别名**
   - `mp` → `multipass-compiled`
   - `mpd` → `start_multipassd`
   - `mp-start` → 启动并列出虚拟机
   - `mp-stop` → 停止守护进程
   - `mp-log` → 查看日志

4. **✅ 完整管理**
   - 进程检测
   - 日志管理
   - 自动重启
   - 状态监控

---

## 🚀 一键安装

### 执行安装脚本

```bash
cd /Users/tompyang/WorkBuddy/20260320161009
bash install_multipass_compiled.sh
```

### 安装流程

脚本将自动完成以下步骤:

1. **验证编译文件** (5 秒)
   - 检查 `multipass` 可执行文件
   - 检查 `multipassd` 守护进程
   - 检查 `qemu-system-aarch64`

2. **清理旧进程** (2 秒)
   - 停止已运行的 `multipassd`
   - 确保干净启动

3. **创建启动脚本** (1 秒)
   - 生成 `start_multipassd`
   - 安装到 `/usr/local/bin`

4. **创建全局命令** (1 秒)
   - `multipass-compiled` 符号链接
   - `qemu-aarch64-compiled` 符号链接

5. **配置环境变量** (交互)
   - 自动检测 shell (zsh/bash)
   - 添加配置到 `.zshrc` 或 `.bash_profile`
   - 添加便捷别名

6. **配置自动启动** (可选,交互)
   - 创建 LaunchAgent
   - 开机自动启动 multipassd

7. **启动守护进程** (2 秒)
   - 启动 multipassd
   - 验证运行状态

8. **验证安装** (2 秒)
   - 测试命令可用性
   - 列出当前虚拟机

**总耗时**: 约 15-30 秒

---

## 📦 安装后的结构

### 文件布局

```
/usr/local/bin/
├── multipass-compiled       → 符号链接到编译的 multipass
├── qemu-aarch64-compiled    → 符号链接到编译的 qemu
└── start_multipassd         → 守护进程启动脚本

~/.multipass/logs/
├── multipassd.log           → 守护进程日志
└── multipassd.error.log     → 错误日志

~/.zshrc (或 ~/.bash_profile)
└── 添加环境变量和别名配置

~/Library/LaunchAgents/ (可选)
└── com.canonical.multipassd.plist → 开机自动启动配置
```

---

## 🎮 使用方法

### 基础命令

安装完成后，**重新加载 shell 配置**:

```bash
# 方法 1: 重新加载配置
source ~/.zshrc  # 或 source ~/.bash_profile

# 方法 2: 重启 shell
exec $SHELL

# 方法 3: 重新打开终端 (推荐)
```

### 启动守护进程

```bash
# 方法 1: 使用完整命令
start_multipassd

# 方法 2: 使用别名
mpd

# 方法 3: 启动并列出虚拟机
mp-start
```

**输出示例**:
```
启动 multipassd...
✓ multipassd 启动成功 (PID: 12345)
  日志文件: /Users/tompyang/.multipass/logs/multipassd.log
```

---

### 使用 Multipass

```bash
# 列出虚拟机
mp list
# 或
multipass-compiled list

# 启动 Ubuntu 虚拟机
mp launch ubuntu --name test --cpus 2 --memory 2G

# 使用官方 CentOS 镜像
mp launch \
  file:///Users/tompyang/multipass-images/CentOS-Stream-GenericCloud-9-latest.aarch64.qcow2 \
  --name my-centos \
  --cpus 2 \
  --memory 2G

# 进入虚拟机
mp shell test

# 在虚拟机中执行命令
mp exec test -- cat /etc/os-release

# 停止虚拟机
mp stop test

# 删除虚拟机
mp delete test --purge
```

---

### 管理守护进程

```bash
# 查看守护进程状态
ps aux | grep multipassd

# 查看实时日志
mp-log
# 或
tail -f ~/.multipass/logs/multipassd.log

# 停止守护进程
mp-stop
# 或
pkill -f multipassd

# 重启守护进程
mp-stop && mp-start
```

---

## 🔧 手动配置 (不推荐)

如果不想使用安装脚本，可以手动配置:

### 1. 创建启动脚本

```bash
cat > /tmp/start_multipassd.sh << 'EOF'
#!/bin/bash
MULTIPASSD_BIN="/Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin/multipassd"
LOG_DIR="${HOME}/.multipass/logs"
LOG_FILE="${LOG_DIR}/multipassd.log"

mkdir -p "${LOG_DIR}"

if pgrep -f multipassd > /dev/null; then
    echo "✓ multipassd 已在运行"
    exit 0
fi

nohup "${MULTIPASSD_BIN}" > "${LOG_FILE}" 2>&1 &
sleep 2

if pgrep -f multipassd > /dev/null; then
    echo "✓ multipassd 启动成功 (PID: $(pgrep -f multipassd))"
else
    echo "✗ multipassd 启动失败"
    exit 1
fi
EOF

sudo mv /tmp/start_multipassd.sh /usr/local/bin/start_multipassd
sudo chmod +x /usr/local/bin/start_multipassd
```

### 2. 创建符号链接

```bash
sudo ln -sf /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin/multipass \
    /usr/local/bin/multipass-compiled
```

### 3. 添加环境变量

编辑 `~/.zshrc`:

```bash
cat >> ~/.zshrc << 'EOF'

# Multipass 编译版配置
export MULTIPASS_BUILD_DIR="/Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin"
export PATH="${MULTIPASS_BUILD_DIR}:${PATH}"

alias mp='multipass-compiled'
alias mpd='start_multipassd'
alias mp-start='start_multipassd && sleep 2 && multipass-compiled list'
alias mp-stop='pkill -f multipassd'
alias mp-log='tail -f ${HOME}/.multipass/logs/multipassd.log'
EOF

source ~/.zshrc
```

---

## 🛠️ 常见问题

### Q1: 安装后命令不可用

**问题**: 执行 `mp` 或 `multipass-compiled` 提示 `command not found`

**解决**:
```bash
# 重新加载 shell 配置
source ~/.zshrc  # 或 ~/.bash_profile

# 验证环境变量
echo $PATH | grep multipass

# 验证符号链接
ls -l /usr/local/bin/multipass-compiled
```

---

### Q2: multipassd 启动失败

**问题**: 启动 multipassd 失败

**诊断**:
```bash
# 查看日志
cat ~/.multipass/logs/multipassd.log

# 检查端口占用
lsof -i :51001

# 手动启动测试
/Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin/multipassd
```

**常见原因**:
1. 端口被占用 → 停止其他 multipassd
2. 权限不足 → 检查目录权限
3. QEMU 路径错误 → 检查 qemu-system-aarch64

---

### Q3: 虚拟机启动超时

**问题**: `launch` 命令一直等待

**解决**:
```bash
# 检查守护进程状态
ps aux | grep multipassd

# 检查日志
mp-log

# 重启守护进程
mp-stop
mp-start
```

---

### Q4: 与官方版本冲突

**问题**: 同时安装了 Homebrew 版和编译版

**解决**:
```bash
# 使用编译版
multipass-compiled list
# 或
mp list

# 使用官方版
/opt/homebrew/bin/multipass list

# 卸载官方版 (可选)
brew uninstall multipass
```

---

### Q5: 开机自动启动不生效

**问题**: 配置了 LaunchAgent 但未自动启动

**诊断**:
```bash
# 检查 LaunchAgent
ls -l ~/Library/LaunchAgents/com.canonical.multipassd.plist

# 查看加载状态
launchctl list | grep multipassd

# 重新加载
launchctl unload ~/Library/LaunchAgents/com.canonical.multipassd.plist
launchctl load ~/Library/LaunchAgents/com.canonical.multipassd.plist

# 查看日志
cat ~/.multipass/logs/multipassd.log
```

---

## 🎓 进阶配置

### 自定义 multipassd 参数

编辑启动脚本:

```bash
sudo nano /usr/local/bin/start_multipassd
```

添加参数:
```bash
nohup "${MULTIPASSD_BIN}" \
  --verbosity debug \
  --address 127.0.0.1:51001 \
  > "${LOG_FILE}" 2>&1 &
```

---

### 配置日志轮转

防止日志文件过大:

```bash
cat > ~/Library/LaunchAgents/com.multipass.logrotate.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.multipass.logrotate</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>-c</string>
        <string>find ~/.multipass/logs -name "*.log" -size +100M -delete</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.multipass.logrotate.plist
```

---

### 多版本共存

如需同时使用官方版和编译版:

```bash
# 官方版别名
alias mp-brew='/opt/homebrew/bin/multipass'

# 编译版别名
alias mp-compiled='multipass-compiled'

# 添加到 ~/.zshrc
echo "alias mp-brew='/opt/homebrew/bin/multipass'" >> ~/.zshrc
echo "alias mp-compiled='multipass-compiled'" >> ~/.zshrc
```

---

### 性能优化

```bash
# 增加 QEMU 内存
export QEMU_DEFAULT_RAM_SIZE=4096

# 启用 KVM 加速 (Apple Silicon 上使用 hvf)
export QEMU_HVF_ENABLE=1

# 添加到 ~/.zshrc
cat >> ~/.zshrc << 'EOF'
# Multipass 性能优化
export QEMU_DEFAULT_RAM_SIZE=4096
export QEMU_HVF_ENABLE=1
EOF
```

---

## 📊 对比: 安装前后

| 项目 | 安装前 | 安装后 |
|------|--------|--------|
| **启动守护进程** | `cd .../build/bin && ./multipassd &` | `mp-start` |
| **使用命令** | `cd .../build/bin && ./multipass list` | `mp list` (任意目录) |
| **查看日志** | `?` (不知道在哪) | `mp-log` |
| **开机启动** | 手动 | 自动 (可选) |
| **命令长度** | 50+ 字符 | 7 字符 |
| **使用便捷性** | ⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## 🎉 完成!

### 快速测试

安装完成后，执行以下命令验证:

```bash
# 1. 重新加载 shell
source ~/.zshrc

# 2. 启动守护进程
mp-start

# 3. 创建测试虚拟机
mp launch ubuntu --name test-install

# 4. 验证
mp list
mp shell test-install -- cat /etc/os-release

# 5. 清理
mp delete test-install --purge
```

---

## 📚 相关文档

- [CentOS 官方镜像测试报告](CENTOS_OFFICIAL_CLOUD_IMAGE_REPORT.md)
- [集群部署指南](CLUSTER_DEPLOYMENT_GUIDE.md)
- [编译成功报告](COMPILE_SUCCESS_REPORT.md)
- [Multipass 官方文档](https://multipass.run/docs)

---

**需要帮助?** 查看日志文件或提出问题!

```bash
# 查看守护进程日志
cat ~/.multipass/logs/multipassd.log

# 查看错误日志
cat ~/.multipass/logs/multipassd.error.log

# 检查进程状态
ps aux | grep multipass
```
