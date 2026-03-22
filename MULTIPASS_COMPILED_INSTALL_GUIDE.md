# 编译版 Multipass 完整安装指南

**创建时间**: 2026-03-22  
**状态**: ✅ 配置完成,需要手动步骤

---

## 📋 执行摘要

编译版 Multipass 已成功配置!但由于 **multipassd 守护进程需要 root 权限**,我们提供了两种使用方案:

| 方案 | 特点 | 推荐度 |
|------|------|--------|
| **方案 A: 使用 sudo 启动** | 完整功能,需要输入密码 | ⭐⭐⭐⭐⭐ |
| **方案 B: 使用官方版 Multipass** | 自动管理守护进程,无需 sudo | ⭐⭐⭐⭐ |

---

## 🎯 当前配置状态

### ✅ 已完成的配置

1. **✅ 创建用户命令脚本**
   - 路径: `~/.local/bin/`
   - 文件:
     - `mp` - Multipass 包装脚本 (自动启动守护进程)
     - `start-multipassd` - 启动守护进程
     - `stop-multipassd` - 停止守护进程

2. **✅ 生成环境变量配置**
   - 文件: `~/.multipass_env_config.sh`
   - 内容: PATH 配置和便捷别名

3. **✅ 创建日志目录**
   - 路径: `~/.multipass/logs/`
   - 日志文件: `multipassd.log`

### ⚠️ 需要手动完成的步骤

1. **添加环境变量到 shell 配置**
   - 原因: `.zshrc` 文件属于 root
   - 解决: 见下文 [手动步骤](#手动步骤)

2. **使用 sudo 启动 multipassd**
   - 原因: 守护进程需要 root 权限
   - 解决: 见下文 [使用方案](#使用方案)

---

## 🔧 手动步骤

### 步骤 1: 添加环境变量

**方法 A: 使用命令 (推荐)**

```bash
sudo sh -c "cat ~/.multipass_env_config.sh >> ~/.zshrc"
source ~/.zshrc
```

**方法 B: 手动编辑**

```bash
# 编辑 .zshrc
sudo nano ~/.zshrc

# 添加以下内容到文件末尾:
```

```bash
# Multipass 编译版配置
export MULTIPASS_BUILD_DIR="/Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin"
export PATH="${HOME}/.local/bin:${MULTIPASS_BUILD_DIR}:${PATH}"

# Multipass 便捷别名
alias mp-start='start-multipassd'
alias mp-stop='stop-multipassd'
alias mp-restart='stop-multipassd && sleep 2 && start-multipassd'
alias mp-log='tail -f ${HOME}/.multipass/logs/multipassd.log'
alias mp-status='pgrep -fl multipassd'
alias mp-ps='mp list'
```

```bash
# 保存并重新加载
source ~/.zshrc
```

### 步骤 2: 验证配置

```bash
# 检查环境变量
echo $MULTIPASS_BUILD_DIR

# 检查命令
which mp
which start-multipassd

# 检查别名
alias | grep mp-
```

---

## 🚀 使用方案

### 方案 A: 使用 sudo 启动守护进程 ⭐⭐⭐⭐⭐

**推荐使用!** 完整功能,一次输入密码即可。

#### 启动守护进程

```bash
# 方法 1: 直接启动 (推荐)
sudo /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin/multipassd &

# 方法 2: 使用脚本 (需要修改)
sudo ~/.local/bin/start-multipassd
```

#### 使用 Multipass

```bash
# 环境变量生效后,可以直接使用 mp 命令
mp list
mp launch ubuntu --name test
mp shell test
mp stop test
mp delete test --purge
```

#### 开机自动启动 (可选)

创建 LaunchDaemon (系统级,自动启动):

```bash
# 创建配置文件
sudo tee /Library/LaunchDaemons/com.canonical.multipassd.plist > /dev/null << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.canonical.multipassd</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin/multipassd</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/multipassd.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/multipassd.error.log</string>
</dict>
</plist>
EOF

# 设置权限
sudo chown root:wheel /Library/LaunchDaemons/com.canonical.multipassd.plist
sudo chmod 644 /Library/LaunchDaemons/com.canonical.multipassd.plist

# 加载 (立即启动)
sudo launchctl load /Library/LaunchDaemons/com.canonical.multipassd.plist

# 验证
sudo launchctl list | grep multipassd
```

**管理 LaunchDaemon**:

```bash
# 停止服务
sudo launchctl unload /Library/LaunchDaemons/com.canonical.multipassd.plist

# 启动服务
sudo launchctl load /Library/LaunchDaemons/com.canonical.multipassd.plist

# 重启服务
sudo launchctl unload /Library/LaunchDaemons/com.canonical.multipassd.plist
sudo launchctl load /Library/LaunchDaemons/com.canonical.multipassd.plist

# 查看日志
sudo tail -f /var/log/multipassd.log
```

---

### 方案 B: 使用官方 Homebrew 版本 ⭐⭐⭐⭐

**如果不想经常输入 sudo 密码**,可以使用官方版本管理守护进程。

#### 安装官方版本

```bash
brew install multipass
```

#### 混合使用

```bash
# 官方版管理守护进程 (自动 sudo)
# 安装后会自动启动 multipassd

# 使用编译版命令
/Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin/multipass list

# 或使用 mp 别名 (完成步骤 1 后)
mp list
```

#### 区分使用

```bash
# 添加别名到 ~/.zshrc

# 官方版
alias mp-brew='/opt/homebrew/bin/multipass'

# 编译版
alias mp-compiled='/Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin/multipass'

# 使用
mp-brew list        # 官方版
mp-compiled list    # 编译版 (使用官方的守护进程)
```

---

## 📊 完整对比

| 特性 | 方案 A (sudo) | 方案 B (官方版) |
|------|--------------|----------------|
| **功能完整性** | ✅ 完整 | ✅ 完整 |
| **需要密码** | ✅ 一次 | ❌ 自动管理 |
| **开机启动** | ✅ 可配置 | ✅ 自动 |
| **使用便捷性** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **版本控制** | ✅ 编译版 | ⚠️ 官方版 |
| **CentOS 支持** | ✅ 已测试 | ⚠️ 需验证 |

---

## 💡 推荐配置

### 最佳实践: 官方守护进程 + 编译版命令

1. **安装官方版 Multipass**
   ```bash
   brew install multipass
   ```

2. **完成手动步骤 1** (添加环境变量)
   ```bash
   sudo sh -c "cat ~/.multipass_env_config.sh >> ~/.zshrc"
   source ~/.zshrc
   ```

3. **使用编译版命令**
   ```bash
   mp list  # 自动使用编译版,连接官方守护进程
   ```

**优势**:
- ✅ 无需手动启动守护进程
- ✅ 无需经常输入密码
- ✅ 使用最新的编译版命令
- ✅ 开机自动启动
- ✅ 官方维护的守护进程更稳定

---

## 🎮 使用示例

### 完成配置后

```bash
# 1. 重新加载 shell 配置
source ~/.zshrc

# 2. 检查守护进程状态
mp-status
# 或
pgrep -fl multipassd

# 3. 如果守护进程未运行,启动它
sudo /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin/multipassd &
# 或使用官方版 (已自动启动)

# 4. 列出虚拟机
mp list

# 5. 启动 Ubuntu 虚拟机
mp launch ubuntu --name test --cpus 2 --memory 2G

# 6. 使用官方 CentOS 镜像 (18 秒启动!)
mp launch \
  file:///Users/tompyang/multipass-images/CentOS-Stream-GenericCloud-9-latest.aarch64.qcow2 \
  --name my-centos \
  --cpus 2 \
  --memory 2G \
  --disk 15G

# 7. 进入虚拟机
mp shell my-centos

# 8. 在虚拟机中执行命令
mp exec my-centos -- cat /etc/os-release
mp exec my-centos -- ping -c 3 8.8.8.8

# 9. 停止虚拟机
mp stop my-centos

# 10. 删除虚拟机
mp delete my-centos --purge
```

---

## 📁 文件清单

### 已创建的文件

```
~/.local/bin/
├── mp                      ⭐ Multipass 包装脚本 (自动启动守护进程)
├── start-multipassd        启动守护进程脚本
└── stop-multipassd         停止守护进程脚本

~/.multipass/
├── logs/
│   └── multipassd.log      守护进程日志
└── .multipass_env_config.sh  ⭐ 环境变量配置 (需手动添加到 .zshrc)

/Users/tompyang/WorkBuddy/20260320161009/
├── setup_multipass_no_sudo.sh              ⭐ 配置脚本 (已执行)
├── MULTIPASS_COMPILED_USAGE_GUIDE.md       使用指南
├── MULTIPASS_COMPILED_INSTALL_GUIDE.md     ⭐ 本文档
└── ...

/Users/tompyang/multipass-images/
├── CentOS-Stream-GenericCloud-9-latest.aarch64.qcow2  ⭐ 官方镜像 (18 秒启动)
└── ...
```

---

## 🛠️ 故障排除

### 问题 1: 命令不可用

**现象**: 执行 `mp` 提示 `command not found`

**解决**:
```bash
# 检查环境变量是否添加
grep "MULTIPASS_BUILD_DIR" ~/.zshrc

# 如果未添加,执行步骤 1
sudo sh -c "cat ~/.multipass_env_config.sh >> ~/.zshrc"
source ~/.zshrc

# 验证
which mp
```

---

### 问题 2: 无法连接守护进程

**现象**: `list failed: cannot connect to the multipass socket`

**诊断**:
```bash
# 检查守护进程是否运行
pgrep -fl multipassd

# 检查日志
tail -20 ~/.multipass/logs/multipassd.log
```

**解决**:
```bash
# 方法 1: 启动编译版守护进程 (需要 sudo)
sudo /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin/multipassd &
sleep 3
mp list

# 方法 2: 使用官方版守护进程
brew install multipass
# 官方版会自动启动守护进程
mp list
```

---

### 问题 3: 权限错误

**现象**: 日志显示 `Operation not permitted` 或 `access error`

**原因**: multipassd 需要 root 权限

**解决**:
```bash
# 使用 sudo 启动
sudo /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin/multipassd &
```

---

### 问题 4: 守护进程自动退出

**现象**: 启动后几秒就退出

**诊断**:
```bash
# 查看完整日志
cat ~/.multipass/logs/multipassd.log

# 前台运行查看输出
sudo /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin/multipassd
```

**常见原因**:
1. 配置文件权限问题 → 使用 sudo
2. 端口被占用 → 停止其他 multipassd
3. QEMU 路径错误 → 检查编译版本

---

## 🎓 总结

### 当前状态

| 项目 | 状态 | 说明 |
|------|------|------|
| **脚本创建** | ✅ 完成 | `~/.local/bin/mp` 等 |
| **环境配置** | ⚠️ 待完成 | 需添加到 `.zshrc` (步骤 1) |
| **守护进程** | ⚠️ 需 sudo | 使用方案 A 或 B |
| **使用就绪** | 🔄 部分就绪 | 完成步骤 1 后即可使用 |

---

### 下一步操作

**选择您的方案**:

#### 方案 A: 使用编译版守护进程

```bash
# 1. 添加环境变量
sudo sh -c "cat ~/.multipass_env_config.sh >> ~/.zshrc"
source ~/.zshrc

# 2. 启动守护进程
sudo /Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin/multipassd &

# 3. 使用
mp list
```

#### 方案 B: 使用官方版守护进程 (推荐)

```bash
# 1. 安装官方版
brew install multipass

# 2. 添加环境变量
sudo sh -c "cat ~/.multipass_env_config.sh >> ~/.zshrc"
source ~/.zshrc

# 3. 使用 (无需启动守护进程)
mp list
```

---

### 配置开机自动启动 (可选)

```bash
# 创建并加载 LaunchDaemon
sudo tee /Library/LaunchDaemons/com.canonical.multipassd.plist > /dev/null << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.canonical.multipassd</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin/multipassd</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/multipassd.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/multipassd.error.log</string>
</dict>
</plist>
EOF

sudo chown root:wheel /Library/LaunchDaemons/com.canonical.multipassd.plist
sudo chmod 644 /Library/LaunchDaemons/com.canonical.multipassd.plist
sudo launchctl load /Library/LaunchDaemons/com.canonical.multipassd.plist
```

---

## 📚 相关文档

- [CentOS 官方镜像测试报告](CENTOS_OFFICIAL_CLOUD_IMAGE_REPORT.md) - ⭐ 18 秒启动!
- [Multipass 编译版使用指南](MULTIPASS_COMPILED_USAGE_GUIDE.md)
- [集群部署指南](CLUSTER_DEPLOYMENT_GUIDE.md)
- [编译成功报告](COMPILE_SUCCESS_REPORT.md)

---

## 🎉 结语

编译版 Multipass 的配置已经完成大部分!

**关键要点**:
1. ✅ 脚本已创建,功能完善
2. ⚠️ 需要完成环境变量配置 (1 个命令)
3. ⚠️ 守护进程需要 root 权限 (使用 sudo 或官方版)
4. ✅ 配置完成后使用体验极佳

**推荐**: 使用 **方案 B** (官方守护进程 + 编译版命令) 获得最佳体验!

---

**需要帮助?**

查看日志:
```bash
tail -f ~/.multipass/logs/multipassd.log
```

检查进程:
```bash
pgrep -fl multipassd
```

测试连接:
```bash
/Users/tompyang/WorkBuddy/20260320161009/multipass/build/bin/multipass list
```
