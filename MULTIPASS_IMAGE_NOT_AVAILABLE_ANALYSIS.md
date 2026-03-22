# Multipass "Image: Not Available" 问题分析

**问题**: `mp list` 显示 `Image: Not Available`  
**虚拟机**: centos-official  
**日期**: 2026-03-22

---

## 🔍 问题现象

```bash
$ mp list
Name                    State             IPv4             Image
centos-official         Running           192.168.252.3    Not Available
```

**对比**: Ubuntu 虚拟机显示正常
```bash
ubuntu-verify           Running           192.168.252.2    Ubuntu 24.04 LTS
```

---

## 🎯 根本原因

### 原因分析

`Image: Not Available` 的原因是 **Multipass 无法从镜像名称映射到显示名称**。

**关键区别**:

| 虚拟机 | 创建方式 | Image 列显示 | 原因 |
|--------|---------|-------------|------|
| **ubuntu-verify** | `multipass launch ubuntu` | `Ubuntu 24.04 LTS` ✅ | 使用官方镜像别名 |
| **centos-official** | `multipass launch file:///.../CentOS-xxx.qcow2` | `Not Available` ❌ | 使用本地文件路径 |

---

## 📊 详细信息对比

### CentOS 虚拟机 (显示 "Not Available")

```bash
$ multipass info centos-official

Name:           centos-official
State:          Running
Release:        CentOS Stream 9          ← ✅ 正确识别系统
Image hash:     084336da04f4             ← ✅ 有镜像哈希
IPv4:           192.168.252.3
```

**关键发现**:
- ✅ `Release` 字段正确识别为 `CentOS Stream 9`
- ✅ `Image hash` 存在
- ❌ `list` 命令的 `Image` 列无法显示

---

### Ubuntu 虚拟机 (正常显示)

```bash
$ multipass info ubuntu-verify

Name:           ubuntu-verify
Release:        Ubuntu 24.04.4 LTS
Image hash:     99e1d482b958 (24.04 LTS)  ← 包含镜像别名
```

**差异**:
- Ubuntu 的 `Image hash` 包含 `(24.04 LTS)` 别名信息
- CentOS 的 `Image hash` 只有哈希值,没有别名

---

## 💡 为什么会这样?

### Multipass 镜像管理机制

```
┌─────────────────────────────────────────────────────┐
│         Multipass 镜像系统                           │
├─────────────────────────────────────────────────────┤
│                                                      │
│  1. 官方镜像别名 (有映射)                            │
│     ubuntu → Ubuntu 22.04 LTS                       │
│     22.04  → Ubuntu 22.04 LTS                       │
│     24.04  → Ubuntu 24.04 LTS                       │
│     ✅ list 显示: "Ubuntu 24.04 LTS"                │
│                                                      │
│  2. 本地文件路径 (无映射)                            │
│     file:///path/to/CentOS-Stream-9.qcow2           │
│     ❌ list 显示: "Not Available"                   │
│     ✅ info 显示: Release = CentOS Stream 9         │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### 技术细节

1. **官方镜像**
   - Multipass 维护一个镜像数据库 (来自 https://cloud-images.ubuntu.com)
   - 包含镜像别名 → 显示名称的映射
   - 例: `ubuntu` → `Ubuntu 22.04 LTS`

2. **本地文件**
   - 使用 `file://` 协议启动
   - Multipass **不会**创建镜像别名
   - 只记录文件路径和哈希
   - `list` 命令找不到别名 → 显示 `Not Available`

3. **实际信息**
   - 虚拟机内部的 OS 信息 **正常识别** (通过 cloud-init)
   - `multipass info` 可以显示 `Release: CentOS Stream 9`
   - 只是 `list` 命令的显示问题

---

## ✅ 这是正常行为!

### 重要说明

**这不是 bug 或错误配置!** 这是 Multipass 的预期行为:

| 影响 | 说明 |
|------|------|
| **功能** | ✅ 完全不影响虚拟机功能 |
| **性能** | ✅ 不影响启动速度或运行 |
| **操作** | ✅ 所有命令正常工作 |
| **显示** | ⚠️ 只是 `list` 列表的显示问题 |

---

## 🔧 解决方案

### 方案 1: 接受现状 (推荐) ⭐⭐⭐⭐⭐

**最简单的方案**: 不需要修复

**理由**:
1. ✅ 虚拟机功能完全正常
2. ✅ 可以用 `multipass info` 查看详细信息
3. ✅ 可以用虚拟机名称识别
4. ✅ 对实际使用没有影响

**使用技巧**:
```bash
# 查看所有虚拟机 (包含简单信息)
mp list

# 查看特定虚拟机详细信息
mp info centos-official  # 显示完整的 Release 信息

# 使用脚本美化输出 (见方案 4)
```

---

### 方案 2: 使用官方镜像别名 ⭐⭐⭐

**原理**: 从官方源下载,让 Multipass 记录别名

**步骤**:

1. 检查是否有 CentOS 官方别名:
```bash
multipass find | grep -i centos
```

**预期结果**: 可能没有 CentOS 官方别名 (Multipass 主要支持 Ubuntu)

2. 如果有,使用别名创建:
```bash
multipass launch centos:stream9 --name my-centos
```

**问题**: Multipass 官方**不提供 CentOS 镜像别名**,所以此方案不可行。

---

### 方案 3: 创建本地镜像别名 ⭐⭐

**原理**: 修改 Multipass 的镜像数据库,添加自定义别名

**难度**: 高  
**风险**: 可能在 Multipass 更新后失效

**不推荐**: 维护成本高,收益低

---

### 方案 4: 创建自定义列表命令 ⭐⭐⭐⭐

**推荐!** 创建一个美化的列表脚本

**创建脚本**: `~/.local/bin/mp-list-pretty`

```bash
#!/bin/bash

# 美化的 multipass list 命令

echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
echo "║  Multipass 虚拟机列表                                                          ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# 获取虚拟机列表
VMS=$(multipass list --format json 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for vm in data.get('list', []):
        print(vm['name'])
except:
    pass
")

if [ -z "$VMS" ]; then
    echo "没有运行的虚拟机"
    exit 0
fi

# 打印表头
printf "%-20s %-12s %-18s %-25s\n" "名称" "状态" "IP 地址" "系统版本"
echo "────────────────────────────────────────────────────────────────────────────────"

# 遍历虚拟机
for vm in $VMS; do
    # 获取详细信息
    INFO=$(multipass info "$vm" 2>/dev/null)
    
    STATE=$(echo "$INFO" | grep "State:" | awk '{print $2}')
    IP=$(echo "$INFO" | grep "IPv4:" | awk '{print $2}' | head -1)
    RELEASE=$(echo "$INFO" | grep "Release:" | cut -d: -f2- | xargs)
    
    # 如果 RELEASE 为空,使用 Image hash
    if [ -z "$RELEASE" ]; then
        RELEASE="未知"
    fi
    
    # 打印信息
    printf "%-20s %-12s %-18s %-25s\n" "$vm" "$STATE" "${IP:-未分配}" "$RELEASE"
done

echo ""
```

**安装**:
```bash
# 创建脚本
cat > ~/.local/bin/mp-list-pretty << 'EOF'
[上面的脚本内容]
EOF

# 设置权限
chmod +x ~/.local/bin/mp-list-pretty

# 添加别名到 ~/.zshrc
echo "alias mpl='mp-list-pretty'" >> ~/.zshrc
source ~/.zshrc
```

**使用**:
```bash
# 使用美化列表
mpl

# 或
mp-list-pretty
```

**输出示例**:
```
╔═══════════════════════════════════════════════════════════════════════════════╗
║  Multipass 虚拟机列表                                                          ║
╚═══════════════════════════════════════════════════════════════════════════════╝

名称                  状态          IP 地址             系统版本
────────────────────────────────────────────────────────────────────────────────
centos-official      Running       192.168.252.3       CentOS Stream 9
ubuntu-verify        Running       192.168.252.2       Ubuntu 24.04.4 LTS
```

---

### 方案 5: 使用 JSON 格式 ⭐⭐⭐

**原理**: JSON 格式包含更多信息

```bash
# JSON 格式输出
multipass list --format json | python3 -m json.tool

# 或使用 jq (需要安装)
multipass list --format json | jq '.list[] | {name, state, ipv4}'
```

---

## 📊 方案对比

| 方案 | 难度 | 效果 | 推荐度 |
|------|------|------|--------|
| **方案 1: 接受现状** | ⭐ | 无变化 | ⭐⭐⭐⭐⭐ |
| **方案 2: 官方别名** | - | - | ❌ 不可用 |
| **方案 3: 修改数据库** | ⭐⭐⭐⭐⭐ | 完美 | ⭐⭐ (风险高) |
| **方案 4: 自定义脚本** | ⭐⭐ | 优秀 | ⭐⭐⭐⭐ |
| **方案 5: JSON 格式** | ⭐ | 一般 | ⭐⭐⭐ |

---

## 🎯 我的建议

### 推荐方案: 方案 1 + 方案 4

**理由**:
1. **方案 1** - 接受 `Not Available` 的显示
   - 不影响实际使用
   - 可以用 `mp info` 查看详细信息
   
2. **方案 4** - 创建美化脚本 (可选)
   - 如果经常查看虚拟机列表
   - 提供更友好的显示
   - 一次配置,永久使用

---

## 🔍 深入理解

### Multipass 的镜像别名来源

```bash
# 查看可用的官方镜像
multipass find

# 输出示例:
# Image                       Aliases           Version          Description
# core                        core16            20200818         Ubuntu Core 16
# core18                                        20211124         Ubuntu Core 18
# core20                                        20230119         Ubuntu Core 20
# core22                                        20230717         Ubuntu Core 22
# 20.04                       focal             20231211         Ubuntu 20.04 LTS
# 22.04                       jammy,lts         20240319         Ubuntu 22.04 LTS
# 23.10                       mantic            20240215         Ubuntu 23.10
# 24.04                       noble             20240612         Ubuntu 24.04 LTS
# ...
```

**观察**:
- ✅ 所有官方镜像都有 `Aliases` 和 `Version`
- ✅ 这些信息被用于 `list` 命令的 `Image` 列
- ❌ CentOS 不在此列表中

---

### 为什么 `multipass info` 可以显示?

```bash
$ multipass info centos-official
Release:        CentOS Stream 9  ← 来自 cloud-init
```

**原因**:
1. 虚拟机启动后,cloud-init 收集系统信息
2. Multipass 通过 cloud-init 获取 `/etc/os-release`
3. `multipass info` 显示从虚拟机内部获取的信息
4. 但 `multipass list` 只查询本地镜像数据库

---

## ✅ 结论

### 关键要点

1. **这不是错误**
   - 使用本地镜像文件的正常行为
   - Ubuntu 官方镜像也会这样 (如果用 `file://` 启动)

2. **不影响功能**
   - 虚拟机完全正常工作
   - 所有命令都可用
   - 性能无影响

3. **解决方法**
   - **简单**: 接受现状,使用 `mp info` 查看详情
   - **进阶**: 创建自定义列表脚本

4. **根本原因**
   - Multipass 不为本地文件创建镜像别名
   - 只有官方镜像才有别名映射

---

## 🎓 学习要点

### Multipass 镜像类型

```
┌────────────────────────────────────────────────┐
│  类型 1: 官方镜像 (有别名)                      │
│  ├── multipass launch ubuntu                  │
│  ├── multipass launch 24.04                   │
│  └── list 显示: "Ubuntu 24.04 LTS" ✅          │
├────────────────────────────────────────────────┤
│  类型 2: URL 镜像 (无别名)                     │
│  ├── multipass launch https://...             │
│  └── list 显示: "Not Available" ⚠️            │
├────────────────────────────────────────────────┤
│  类型 3: 本地文件 (无别名)                     │
│  ├── multipass launch file:///...             │
│  └── list 显示: "Not Available" ⚠️            │
└────────────────────────────────────────────────┘
```

---

## 🎉 总结

**回答您的问题**: `Image: Not Available` 的原因是:

1. 使用 `file://` 本地文件路径创建虚拟机
2. Multipass 没有为本地文件创建镜像别名
3. `list` 命令无法找到对应的显示名称

**这是正常的!** 虚拟机功能完全正常,只是显示问题。

**推荐**: 使用 `multipass info centos-official` 查看完整信息,包含正确的 `Release: CentOS Stream 9`。

---

## 📚 相关命令

```bash
# 查看详细信息 (显示正确的系统版本)
mp info centos-official

# 查看所有虚拟机
mp list

# 查看 JSON 格式 (包含更多信息)
mp list --format json

# 创建自定义列表命令
mp-list-pretty  # (需要先创建脚本)
```
