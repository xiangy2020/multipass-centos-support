#!/bin/bash

###############################################################################
# 从源码编译 Multipass 支持 CentOS - 修复版
###############################################################################

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  从源码编译 Multipass (macOS 14.0 部署目标)                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# 工作目录
MULTIPASS_DIR="/Users/tompyang/WorkBuddy/20260320161009/multipass"
BUILD_DIR="$MULTIPASS_DIR/build"

cd "$MULTIPASS_DIR"

# 显示环境信息
echo "[0/5] 环境信息"
echo "  编译器: $(clang++ --version | head -1)"
echo "  SDK: $(xcrun --show-sdk-path)"
echo "  SDK版本: $(xcrun --show-sdk-version)"
echo "  系统: $(sw_vers -productVersion)"
echo ""

# 验证 CMakeLists.txt 修改
echo "[1/5] 验证 CMakeLists.txt 修改..."
if grep -q 'CMAKE_OSX_DEPLOYMENT_TARGET "14.0"' CMakeLists.txt; then
    echo "  ✓ 部署目标已设置为 14.0"
else
    echo "  ✗ 部署目标不正确,正在修正..."
    sed -i.bak 's/CMAKE_OSX_DEPLOYMENT_TARGET "13.3"/CMAKE_OSX_DEPLOYMENT_TARGET "14.0"/' CMakeLists.txt
    echo "  ✓ 已修正为 14.0"
fi
echo ""

# 清理旧构建
echo "[2/5] 清理旧构建..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
echo "  ✓ build 目录已重置"
echo ""

# 清理 vcpkg 缓存(避免冲突)
echo "清理 vcpkg 缓存..."
rm -rf ~/.cache/vcpkg
echo "  ✓ vcpkg 缓存已清理"
echo ""

# CMake 配置
echo "[3/5] 配置 CMake (预计 8-10 分钟)..."
echo "  开始时间: $(date '+%H:%M:%S')"
cd "$BUILD_DIR"

# 显式设置环境变量确保使用正确的SDK
export SDKROOT="$(xcrun --show-sdk-path)"
export MACOSX_DEPLOYMENT_TARGET="14.0"

echo "  SDKROOT: $SDKROOT"
echo "  MACOSX_DEPLOYMENT_TARGET: $MACOSX_DEPLOYMENT_TARGET"
echo ""

if cmake .. \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DCMAKE_OSX_SYSROOT="$SDKROOT" \
    2>&1 | tee cmake_config.log; then
    
    echo ""
    echo "  ✓ CMake 配置成功"
    echo "  完成时间: $(date '+%H:%M:%S')"
else
    echo ""
    echo "  ✗ CMake 配置失败"
    echo ""
    echo "请检查日志: $BUILD_DIR/cmake_config.log"
    echo "或: $BUILD_DIR/vcpkg-manifest-install.log"
    exit 1
fi
echo ""

# 编译
echo "[4/5] 编译 Multipass (预计 15-20 分钟)..."
echo "  使用 $(sysctl -n hw.ncpu) 个CPU核心"
echo "  开始时间: $(date '+%H:%M:%S')"
echo ""

if ninja -j$(sysctl -n hw.ncpu) 2>&1 | tee ninja_build.log; then
    echo ""
    echo "  🎉 编译成功!"
    echo "  完成时间: $(date '+%H:%M:%S')"
else
    echo ""
    echo "  ✗ 编译失败"
    echo ""
    echo "请检查日志: $BUILD_DIR/ninja_build.log"
    exit 1
fi
echo ""

# 显示编译结果
echo "[5/5] 编译结果"
echo ""
if [[ -f "$BUILD_DIR/bin/multipass" ]]; then
    echo "  ✓ multipass 二进制文件已生成"
    ls -lh "$BUILD_DIR/bin/multipass"
    echo ""
    echo "  版本信息:"
    "$BUILD_DIR/bin/multipass" version || true
else
    echo "  ✗ 未找到 multipass 二进制文件"
    exit 1
fi
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ✓ 编译完成!                                                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "下一步: 安装 Multipass"
echo ""
echo "  sudo ninja -C $BUILD_DIR install"
echo ""
echo "或者直接使用编译后的版本:"
echo ""
echo "  $BUILD_DIR/bin/multipass version"
echo ""
