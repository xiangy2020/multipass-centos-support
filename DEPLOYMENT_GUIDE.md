# Multipass CentOS 支持部署指南

## 🎯 部署目标

将改造后的 CentOS 支持集成到你的 Multipass 安装中。

## 📋 前置要求

- Multipass 已安装并正常运行
- 对应操作系统的管理员权限
- 基本的命令行操作知识

## 🚀 快速部署

### 方法 1: 直接替换配置文件 (推荐)

这是最简单快速的方法,只需替换一个 JSON 文件。

#### Linux 系统

```bash
# 1. 备份原始配置
sudo cp /var/snap/multipass/common/data/distributions/distribution-info.json \
       /var/snap/multipass/common/data/distributions/distribution-info.json.backup

# 2. 复制新配置
sudo cp multipass/data/distributions/distribution-info.json \
       /var/snap/multipass/common/data/distributions/

# 3. 重启 Multipass 守护进程
sudo snap restart multipass

# 4. 验证
multipass find centos
```

#### macOS 系统

```bash
# 1. 查找 Multipass 数据目录
MULTIPASS_DATA="$HOME/Library/Application Support/multipassd"

# 2. 备份原始配置
cp "$MULTIPASS_DATA/distributions/distribution-info.json" \
   "$MULTIPASS_DATA/distributions/distribution-info.json.backup"

# 3. 复制新配置
cp multipass/data/distributions/distribution-info.json \
   "$MULTIPASS_DATA/distributions/"

# 4. 重启 Multipass
sudo launchctl unload /Library/LaunchDaemons/com.canonical.multipassd.plist
sudo launchctl load /Library/LaunchDaemons/com.canonical.multipassd.plist

# 5. 验证
multipass find centos
```

#### Windows 系统

```powershell
# 以管理员身份运行 PowerShell

# 1. 查找 Multipass 数据目录
$DataDir = "$env:ProgramData\Multipassd\data"

# 2. 备份原始配置
Copy-Item "$DataDir\distributions\distribution-info.json" `
          "$DataDir\distributions\distribution-info.json.backup"

# 3. 复制新配置
Copy-Item "multipass\data\distributions\distribution-info.json" `
          "$DataDir\distributions\"

# 4. 重启 Multipass 服务
Restart-Service Multipass

# 5. 验证
multipass find centos
```

### 方法 2: 从源码编译 (高级)

如果你希望从源码完整构建 Multipass:

#### 1. 克隆改造后的代码

```bash
# 假设你已经有了改造后的代码
cd /path/to/multipass
```

#### 2. 安装构建依赖

**Linux (Ubuntu/Debian)**:
```bash
sudo apt update
sudo apt install -y build-essential cmake git \
    libglib2.0-dev libqt6core6 libqt6network6 \
    libqt6gui6 qt6-base-dev
```

**macOS**:
```bash
brew install cmake qt@6 pkg-config
```

**Windows**:
- 安装 Visual Studio 2019 或更新版本
- 安装 Qt 6.9.1
- 安装 CMake

#### 3. 构建 Multipass

```bash
# 创建构建目录
mkdir build && cd build

# 配置
cmake .. -DCMAKE_BUILD_TYPE=Release

# 编译
cmake --build . -j$(nproc)

# 安装
sudo cmake --install .
```

#### 4. 验证安装

```bash
multipass version
multipass find centos
```

## 🧪 验证部署

### 自动化测试

运行提供的测试脚本:

```bash
cd /Users/tompyang/WorkBuddy/20260320161009
./test_centos_support.sh
```

### 手动测试

```bash
# 1. 检查镜像列表
multipass find | grep centos

# 预期输出:
# centos     centos-stream     9     CentOS Stream 9

# 2. 启动测试虚拟机
multipass launch centos --name test-centos

# 3. 查看虚拟机信息
multipass info test-centos

# 4. 连接到虚拟机
multipass shell test-centos

# 5. 在虚拟机内验证系统
cat /etc/os-release
# 应该显示 CentOS Stream 9

# 6. 清理
multipass delete test-centos
multipass purge
```

## 🔧 故障排除

### 问题 1: 找不到 CentOS 镜像

**症状**:
```
$ multipass find | grep centos
(无输出)
```

**解决方案**:

1. **检查配置文件是否正确复制**:
   ```bash
   # Linux (Snap)
   sudo cat /var/snap/multipass/common/data/distributions/distribution-info.json | grep CentOS
   
   # macOS
   cat "$HOME/Library/Application Support/multipassd/distributions/distribution-info.json" | grep CentOS
   ```

2. **验证 JSON 格式**:
   ```bash
   # Linux
   sudo jq . /var/snap/multipass/common/data/distributions/distribution-info.json
   
   # macOS
   jq . "$HOME/Library/Application Support/multipassd/distributions/distribution-info.json"
   ```

3. **重启 Multipass 守护进程**:
   ```bash
   # Linux
   sudo snap restart multipass
   
   # macOS
   sudo launchctl kickstart -k system/com.canonical.multipassd
   
   # Windows (PowerShell 管理员)
   Restart-Service Multipass
   ```

### 问题 2: 虚拟机启动失败

**症状**:
```
$ multipass launch centos
launch failed: error downloading image: ...
```

**解决方案**:

1. **检查网络连接**:
   ```bash
   curl -I https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2
   ```

2. **检查防火墙设置**:
   - 确保允许 HTTPS 出站连接
   - 特别注意企业网络的代理设置

3. **手动下载镜像测试**:
   ```bash
   wget https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2
   ```

4. **查看 Multipass 日志**:
   ```bash
   # Linux
   sudo journalctl -u snap.multipass.multipassd
   
   # macOS
   sudo log show --predicate 'process == "multipassd"' --last 1h
   
   # Windows
   Get-EventLog -LogName Application -Source Multipass
   ```

### 问题 3: 镜像哈希验证失败

**症状**:
```
launch failed: Downloaded image hash does not match
```

**解决方案**:

1. **更新哈希值**:
   编辑 `distribution-info.json`,将 `id` 字段更新为实际的 SHA256 哈希值。

2. **计算镜像哈希**:
   ```bash
   wget https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2
   sha256sum CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2
   ```

3. **临时跳过验证** (不推荐,仅用于测试):
   将 `id` 字段设置为空字符串 `""`。

### 问题 4: Cloud-Init 失败

**症状**:
虚拟机启动了,但无法连接或配置不正确。

**解决方案**:

1. **查看 Cloud-Init 日志**:
   ```bash
   multipass exec your-vm-name -- cat /var/log/cloud-init.log
   multipass exec your-vm-name -- cat /var/log/cloud-init-output.log
   ```

2. **检查 Cloud-Init 状态**:
   ```bash
   multipass exec your-vm-name -- cloud-init status --long
   ```

3. **手动重新运行 Cloud-Init**:
   ```bash
   multipass exec your-vm-name -- sudo cloud-init clean
   multipass exec your-vm-name -- sudo cloud-init init
   ```

## 📍 配置文件位置参考

| 操作系统 | 安装方式 | 配置文件路径 |
|---------|---------|-------------|
| **Linux** | Snap | `/var/snap/multipass/common/data/distributions/` |
| **Linux** | Debian/Ubuntu 包 | `/var/lib/multipass/data/distributions/` |
| **macOS** | PKG 安装器 | `~/Library/Application Support/multipassd/distributions/` |
| **Windows** | MSI 安装器 | `%ProgramData%\Multipassd\data\distributions\` |

## 🔄 回滚到原始版本

如果出现问题,需要恢复到原始状态:

```bash
# Linux
sudo cp /var/snap/multipass/common/data/distributions/distribution-info.json.backup \
       /var/snap/multipass/common/data/distributions/distribution-info.json
sudo snap restart multipass

# macOS
cp "$HOME/Library/Application Support/multipassd/distributions/distribution-info.json.backup" \
   "$HOME/Library/Application Support/multipassd/distributions/distribution-info.json"
sudo launchctl kickstart -k system/com.canonical.multipassd

# Windows (PowerShell)
Copy-Item "$env:ProgramData\Multipassd\data\distributions\distribution-info.json.backup" `
          "$env:ProgramData\Multipassd\data\distributions\distribution-info.json"
Restart-Service Multipass
```

## 🚀 性能优化建议

### 1. 使用本地镜像缓存

如果需要频繁创建 CentOS 虚拟机,建议预先下载镜像:

```bash
# 手动下载并缓存
mkdir -p ~/.multipass/cache
cd ~/.multipass/cache
wget https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2
```

### 2. 配置国内镜像源 (仅限中国大陆用户)

如果从官方源下载速度慢,可以配置使用国内镜像:

1. **修改 distribution-info.json**,将 `image_location` 替换为镜像站 URL
2. 常见的 CentOS 镜像站:
   - 阿里云: `https://mirrors.aliyun.com/centos-stream/`
   - 清华大学: `https://mirrors.tuna.tsinghua.edu.cn/centos-stream/`
   - 中科大: `https://mirrors.ustc.edu.cn/centos-stream/`

**注意**: 确保镜像站提供 Cloud Images。

### 3. 调整虚拟机资源

根据实际需求调整虚拟机配置:

```bash
# 低资源配置 (适合测试)
multipass launch centos --name test --cpus 1 --memory 512M --disk 5G

# 标准配置 (适合开发)
multipass launch centos --name dev --cpus 2 --memory 2G --disk 20G

# 高性能配置 (适合生产测试)
multipass launch centos --name prod --cpus 4 --memory 8G --disk 50G
```

## 📚 进阶配置

### 使用 Cloud-Init 自定义虚拟机

创建 `cloud-config.yaml`:

```yaml
#cloud-config
users:
  - name: developer
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAAB3Nza...your-public-key

packages:
  - git
  - vim
  - htop
  - docker

runcmd:
  - systemctl start docker
  - systemctl enable docker
  - usermod -aG docker developer
```

使用配置启动虚拟机:

```bash
multipass launch centos --name custom-vm --cloud-init cloud-config.yaml
```

### 配置共享目录

```bash
# 在宿主机和虚拟机之间共享目录
multipass mount /path/on/host my-centos-vm:/path/in/vm

# 查看挂载点
multipass info my-centos-vm

# 卸载
multipass unmount my-centos-vm:/path/in/vm
```

## ✅ 部署检查清单

完成部署后,确认以下项目:

- [ ] `multipass find` 列出 CentOS 镜像
- [ ] `multipass launch centos` 能成功启动虚拟机
- [ ] `multipass shell` 能连接到虚拟机
- [ ] 虚拟机内 `/etc/os-release` 显示 CentOS Stream
- [ ] 虚拟机能访问外网 (`ping 8.8.8.8`)
- [ ] DNF 软件包管理器正常工作
- [ ] Cloud-Init 日志无错误

## 📞 获取帮助

如果遇到无法解决的问题:

1. **查看官方文档**: https://multipass.run/docs
2. **搜索已知问题**: https://github.com/canonical/multipass/issues
3. **社区论坛**: https://discourse.ubuntu.com/c/multipass/21
4. **提交 Bug 报告**: https://github.com/canonical/multipass/issues/new

---

**部署指南版本**: 1.0  
**最后更新**: 2026-03-22  
**适用版本**: Multipass 1.x (基于 latest main 分支)
