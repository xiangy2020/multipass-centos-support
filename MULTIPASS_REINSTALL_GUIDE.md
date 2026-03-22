# ⚠️ CRITICAL: CommandLineTools 安装损坏

## 🔍 问题诊断

### 发现的问题
```bash
# 检查发现
$ ls /Library/Developer/CommandLineTools/usr/include/c++/v1/ | wc -l
11  # ❌ 应该有 180+ 个文件!

# 关键文件缺失
$ ls -la /Library/Developer/CommandLineTools/usr/include/c++/v1/cstddef
No such file or directory  # ❌ 核心头文件不存在!

# 对比 SDK 中的 C++ 头文件
$ ls /Library/Developer/CommandLineTools/SDKs/MacOSX15.2.sdk/usr/include/c++/v1/ | wc -l
185  # ✓ SDK 中是完整的
```

### 根本原因
**Command Line Tools 16.2 升级时没有正确安装 C++ 标准库头文件**

这导致:
- ✗ clang++ 找不到基本的C++头文件(如 `<cstddef>`, `<iostream>`)
- ✗ vcpkg 无法编译任何C++依赖包
- ✗ Multipass 编译完全被阻塞

---

## 🔧 解决方案

### 方案1: 重新安装 CommandLineTools (推荐⭐)

#### 步骤1: 完全删除现有的

```bash
sudo rm -rf /Library/Developer/CommandLineTools
```

#### 步骤2: 重新安装

**方式A: 使用 softwareupdate (推荐)**
```bash
# 查看可用版本
softwareupdate --list

# 安装 16.2
sudo softwareupdate --install 'Command Line Tools for Xcode-16.2'
```

**方式B: 使用 xcode-select**
```bash
xcode-select --install
# 在弹出窗口点击"安装"
```

#### 步骤3: 验证安装

```bash
# 检查版本
clang++ --version
# 应显示: Apple clang version 16.0.0

# 测试C++编译
echo '#include <cstddef>
#include <iostream>
int main() { std::cout << "OK" << std::endl; return 0; }' | clang++ -x c++ -std=c++20 - -o /tmp/test && /tmp/test
# 应输出: OK

# 检查头文件数量
ls /Library/Developer/CommandLineTools/usr/include/c++/v1/ | wc -l
# 应该 > 180
```

---

### 方案2: 手动复制头文件 (临时解决)

**仅用于紧急情况!不推荐长期使用!**

```bash
# 从 SDK 复制头文件到 CommandLineTools
sudo cp -R /Library/Developer/CommandLineTools/SDKs/MacOSX15.2.sdk/usr/include/c++/v1/* \
         /Library/Developer/CommandLineTools/usr/include/c++/v1/

# 验证
ls /Library/Developer/CommandLineTools/usr/include/c++/v1/cstddef
```

**警告**: 这可能导致版本不匹配或其他问题!

---

## 📊 预计时间

| 方案 | 时间 | 成功率 |
|------|------|--------|
| **方案1 (重装)** | 10-15分钟 | 99% |
| 方案2 (复制) | 2分钟 | 70% |

---

## ✅ 完成后

重新执行 Multipass 编译:

```bash
cd /Users/tompyang/WorkBuddy/20260320161009/multipass
rm -rf build
mkdir build
cd build

# 配置 (release-only 模式)
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0

# 编译
ninja -j$(sysctl -n hw.ncpu)

# 安装
sudo ninja install
```

---

## 🎯 现在执行

**强烈推荐方案1 - 完全重装 CommandLineTools**

这将确保所有工具链完整且一致!
