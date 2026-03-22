# 方案B: 完整编译 Multipass 支持 CentOS - 执行计划

## 📋 问题分析

### 根本原因
Multipass 的 `CMakeLists.txt` 第51行设置了:
```cmake
set(CMAKE_OSX_DEPLOYMENT_TARGET "13.3" CACHE STRING "macOS Deployment Target")
```

这导致:
1. 编译器运行在 macOS 13.3 兼容模式
2. 限制了 C++20 新特性(包括 `<source_location>`)的使用
3. 即使 Clang 16.0.0 支持,也无法启用

### 解决方案
**将部署目标升级到 14.0** - 这是支持完整 C++20 特性的最低版本

---

## 🔧 修复步骤

### 步骤1: 修改 CMakeLists.txt (必须)

**文件**: `/Users/tompyang/WorkBuddy/20260320161009/multipass/CMakeLists.txt`

**第51行**,从:
```cmake
set(CMAKE_OSX_DEPLOYMENT_TARGET "13.3" CACHE STRING "macOS Deployment Target")
```

改为:
```cmake
set(CMAKE_OSX_DEPLOYMENT_TARGET "14.0" CACHE STRING "macOS Deployment Target")
```

**原因**: 
- macOS 14.0 (Sonoma) 完全支持 C++20
- 您的系统是 macOS 14.6 (darwin23.6.0),完全兼容
- SDK 15.2 包含完整的 C++20 标准库

---

### 步骤2: 清理并重新配置

```bash
cd /Users/tompyang/WorkBuddy/20260320161009/multipass
rm -rf build
mkdir build
cd build
```

**重新配置 CMake**:
```bash
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0
```

**预计耗时**: 8-10分钟 (vcpkg会重新验证依赖)

---

### 步骤3: 编译

```bash
ninja -j$(sysctl -n hw.ncpu)
```

**预计耗时**: 15-20分钟

**编译目标数**: 约 580 个

---

### 步骤4: 安装

```bash
sudo ninja install
```

或者使用相对路径安装(不需要sudo):
```bash
ninja install
```

---

### 步骤5: 验证

```bash
# 检查版本
/usr/local/bin/multipass version

# 验证 CentOS 支持
/usr/local/bin/multipass launch \
  file://$HOME/multipass-images/CentOS-7.qcow2 \
  --name centos-test \
  --cpus 2 \
  --memory 2G
```

---

## 🎯 自动化脚本

我已准备好自动执行脚本:
- `build_multipass_from_source.sh` - 完整编译脚本

---

## ⚠️ 可能的问题和解决方案

### 问题1: vcpkg 缓存冲突
**症状**: "Mismatched triplet" 错误

**解决**:
```bash
rm -rf ~/.cache/vcpkg
rm -rf multipass/build/vcpkg_installed
```

### 问题2: 编译器找不到头文件
**症状**: "fatal error: 'iostream' file not found"

**解决**:
```bash
# 验证 SDK
xcrun --show-sdk-path
ls -la /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk

# 如果符号链接错误,重建
sudo rm /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
sudo ln -s MacOSX15.2.sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
```

### 问题3: 链接错误
**症状**: "Undefined symbols" 或 "ld: library not found"

**解决**:
```bash
# 清理并使用 Release-only 模式
cmake .. -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DVCPKG_BUILD_DEFAULT=OFF
```

---

## 📊 预计时间线

| 步骤 | 时间 | 累计 |
|------|------|------|
| 修改 CMakeLists.txt | 1分钟 | 1分钟 |
| 清理环境 | 1分钟 | 2分钟 |
| CMake 配置 | 8-10分钟 | 12分钟 |
| 编译 | 15-20分钟 | 32分钟 |
| 安装 | 2分钟 | 34分钟 |
| 测试 | 3分钟 | 37分钟 |

**总计: 约35-40分钟**

---

## ✅ 成功标志

编译成功后会看到:
```
[580/580] Linking CXX executable bin/multipass
```

安装成功后:
```bash
$ multipass version
multipass   1.16.1+mac
multipassd  1.16.1+mac
```

CentOS 启动成功:
```bash
$ multipass list
Name          State      IPv4           Release
centos-test   Running    192.168.64.x   CentOS 7.x
```

---

## 🚀 现在开始执行!
