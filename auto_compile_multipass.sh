#!/bin/bash
#
# 自动完成 Multipass 编译 - 处理 QEMU 依赖问题
#

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  自动完成 Multipass 编译 (处理 QEMU 依赖)                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

BUILD_DIR="/Users/tompyang/WorkBuddy/20260320161009/multipass/build"
QEMU_BUILD_DIR="$BUILD_DIR/3rd-party/qemu/qemu-prefix/src/qemu-build"

cd "$BUILD_DIR"

echo "═══ 步骤 1: 安装 QEMU 依赖 ═══"
echo ""

# 检查并安装 dtc (device tree compiler)
if ! brew list dtc &>/dev/null; then
    echo "安装 dtc..."
    brew install dtc
else
    echo "✓ dtc 已安装"
fi

# 检查并安装 libfdt
if ! brew list libfdt &>/dev/null; then
    echo "安装 libfdt..."
    brew install libfdt
else
    echo "✓ libfdt 已安装"
fi

echo ""
echo "═══ 步骤 2: 重新配置 QEMU ═══"
echo ""

# 清理 QEMU build 目录
if [ -d "$QEMU_BUILD_DIR" ]; then
    echo "清理 QEMU build 目录..."
    cd "$QEMU_BUILD_DIR"
    rm -rf *
    cd "$BUILD_DIR"
fi

# 重新配置 QEMU
cd "$BUILD_DIR"
echo "重新配置 QEMU..."
ninja qemu-configure 2>&1 | tail -20

echo ""
echo "═══ 步骤 3: 构建 QEMU ═══"
echo ""
ninja qemu-build 2>&1 | tee qemu_build.log | grep -E "^\[|error:|warning:" || true

echo ""
echo "═══ 步骤 4: 完成 Multipass 编译 ═══"
echo ""
ninja 2>&1 | tee -a compile.log | grep -E "^\[|error:|warning:|Linking" || true

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  编译完成检查                                                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

if [ -f "$BUILD_DIR/bin/multipass" ] || [ -f "$BUILD_DIR/bin/Multipass.app/Contents/MacOS/Multipass" ]; then
    echo "✓ Multipass 编译成功!"
    echo ""
    echo "二进制文件位置:"
    find "$BUILD_DIR/bin" -type f -name "multipass*" -o -name "multipassd" | head -10
else
    echo "❌ 编译失败,请查看日志:"
    echo "  - compile.log"
    echo "  - qemu_build.log"
    exit 1
fi
