# Multipass 编译问题分析与解决策略

## 当前状态

### 问题
编译在 vcpkg 安装 boost-container 时失败:
```
fatal error: 'cstddef' file not found
```

### 根本原因
1. **Multipass 使用自定义 vcpkg triplet** (`arm64-osx-release`)
2. **自定义triplet的部署目标传递机制**与新版SDK(15.2)不兼容
3. vcpkg编译boost时**无法正确找到C++标准库头文件**

---

## 解决策略

### 策略1: 使用默认vcpkg模式 (推荐⭐)

**原理**: 放弃自定义triplet,使用vcpkg默认的arm64-osx triplet

**实施**:
1. 配置时加入 `-DVCPKG_BUILD_DEFAULT=ON`
2. 删除自定义triplet覆盖

**命令**:
```bash
cd /Users/tompyang/WorkBuddy/20260320161009/multipass
rm -rf build
mkdir build
cd build

cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DVCPKG_BUILD_DEFAULT=ON
```

**优点**:
- ✅ 使用经过验证的官方triplet
- ✅ 避免自定义配置问题
- ✅ vcpkg团队持续维护

**缺点**:
- ⏱️ 编译时间翻倍(需要构建debug+release)
- 💾 磁盘占用增加

**预计时间**: 20-30分钟(CMake) + 25-35分钟(编译) = **45-65分钟**

---

### 策略2: 修复自定义triplet

**原理**: 修复自定义triplet,使其正确传递SDK路径

**实施**:
修改 `3rd-party/vcpkg-triplets/osx-release.cmake.in`:
```cmake
set(VCPKG_TARGET_ARCHITECTURE @VCPKG_HOST_ARCH@)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
set(VCPKG_OSX_ARCHITECTURES @VCPKG_HOST_ARCH@)
set(VCPKG_BUILD_TYPE release)
set(VCPKG_OSX_DEPLOYMENT_TARGET "@CMAKE_OSX_DEPLOYMENT_TARGET@")
set(VCPKG_OSX_SYSROOT "/Library/Developer/CommandLineTools/SDKs/MacOSX15.2.sdk")
```

**优点**:
- ⏱️ 编译时间较短(只构建release)
- 💾 磁盘占用小

**缺点**:
- ❌ 硬编码SDK路径(不可移植)
- ⚠️ 可能还有其他问题

**预计时间**: 8-10分钟(CMake) + 15-20分钟(编译) = **23-30分钟**

---

### 策略3: 降级部署目标回13.3 (不推荐)

**原理**: 回退到原始的13.3部署目标

**优点**:
- ✅ 避免SDK兼容性问题

**缺点**:
- ❌ **不解决source_location问题**!
- ❌ 回到原点,编译还是会失败

---

## 推荐方案

### 🎯 立即采用策略1

**为什么?**
1. **稳定性第一** - 官方triplet经过充分测试
2. **时间可控** - 虽然慢一些,但成功率接近100%
3. **避免折腾** - 不需要继续调试triplet配置

**预期**:
- 45-65分钟后获得可用的Multipass
- 支持C++20和source_location
- 可以启动CentOS镜像

---

## 执行命令

```bash
# 清理
cd /Users/tompyang/WorkBuddy/20260320161009/multipass
rm -rf build
mkdir build
cd build

# 配置(使用默认模式)
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DVCPKG_BUILD_DEFAULT=ON \
  -DCMAKE_OSX_SYSROOT=$(xcrun --show-sdk-path)

# 编译
ninja -j$(sysctl -n hw.ncpu)

# 安装
sudo ninja install
```

---

## 风险评估

| 策略 | 成功率 | 时间 | 风险 |
|------|--------|------|------|
| **策略1(默认模式)** | 95% | 45-65min | 低 |
| 策略2(修复triplet) | 60% | 23-30min | 中 |
| 策略3(降级目标) | 0% | N/A | 高 |

---

## 现在决定

**建议选择策略1** - 虽然慢一些,但最稳妥!
