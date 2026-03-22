# CentOS 多版本支持完整指南

**更新日期**: 2026-03-22  
**支持版本**: CentOS 7, 8, Stream 8, Stream 9

---

## 📊 CentOS 版本支持总览

### ✅ 完全支持的版本 (4 个版本)

| 版本 | 别名 | ARM64 | x86_64 | 状态 | 推荐度 |
|------|------|-------|--------|------|--------|
| **CentOS Stream 9** | `centos`, `centos9` | ✅ | ✅ | 🌟 **活跃维护** | ⭐⭐⭐⭐⭐ |
| **CentOS Stream 8** | `centos-stream-8` | ✅ | ✅ | ⚠️ **EOL (2024)** | ⭐⭐⭐⭐ |
| **CentOS 8** | `centos8` | ✅ | ✅ | ❌ **EOL (2021)** | ⭐⭐⭐ |
| **CentOS 7** | `centos7` | ❌ | ✅ | ⚠️ **EOL (2024)** | ⭐⭐⭐ |

---

## 🚀 快速启动指南

### 方式 1: Linux 用户 (使用别名,最简单)

部署配置文件后,可以使用简单的别名:

```bash
# CentOS Stream 9 (推荐)
multipass launch centos --name my-centos9

# CentOS Stream 8
multipass launch centos-stream-8 --name my-centos8

# CentOS 8
multipass launch centos8 --name my-centos8-old

# CentOS 7
multipass launch centos7 --name my-centos7
```

### 方式 2: macOS/Windows 用户 (使用完整 URL)

#### CentOS Stream 9 (推荐)

```bash
# ARM64 (Apple Silicon Mac)
multipass launch https://cloud.centos.org/centos/9-stream/aarch64/images/CentOS-Stream-GenericCloud-9-latest.aarch64.qcow2 \
  --name centos9 --cpus 2 --memory 2G --disk 10G

# x86_64 (Intel Mac / Windows)
multipass launch https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2 \
  --name centos9 --cpus 2 --memory 2G --disk 10G
```

#### CentOS Stream 8

```bash
# ARM64
multipass launch https://cloud.centos.org/centos/8-stream/aarch64/images/CentOS-Stream-GenericCloud-8-latest.aarch64.qcow2 \
  --name centos8-stream --cpus 2 --memory 2G --disk 10G

# x86_64
multipass launch https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2 \
  --name centos8-stream --cpus 2 --memory 2G --disk 10G
```

#### CentOS 8 (标准版)

```bash
# ARM64
multipass launch https://cloud.centos.org/centos/8/aarch64/images/CentOS-8-GenericCloud-8.4.2105-20210603.0.aarch64.qcow2 \
  --name centos8 --cpus 2 --memory 2G --disk 10G

# x86_64
multipass launch https://cloud.centos.org/centos/8/x86_64/images/CentOS-8-GenericCloud-8.4.2105-20210603.0.x86_64.qcow2 \
  --name centos8 --cpus 2 --memory 2G --disk 10G
```

#### CentOS 7

```bash
# x86_64 (CentOS 7 没有 ARM64 官方云镜像)
multipass launch https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2 \
  --name centos7 --cpus 2 --memory 2G --disk 10G
```

---

## 📋 版本详细信息

### 1. CentOS Stream 9 (推荐) ⭐⭐⭐⭐⭐

**状态**: 🌟 **活跃维护,官方推荐**

| 属性 | 详情 |
|------|------|
| **发布时间** | 2021年11月 |
| **维护状态** | ✅ 持续更新 |
| **内核版本** | 5.14.0-687.el9 (示例) |
| **包管理** | DNF 4.14.0 (yum 兼容) |
| **Python 版本** | Python 3.9+ |
| **架构支持** | x86_64, aarch64 |
| **镜像大小** | 1.46 GB |

**特性**:
- ✅ SELinux Enforcing 模式
- ✅ Systemd 252+
- ✅ 最新安全更新
- ✅ 与 RHEL 9 兼容

**适用场景**:
- ✅ 新项目开发
- ✅ 容器化应用
- ✅ 云原生应用
- ✅ 学习最新技术

**测试状态**: ✅ **已完整测试,15/16 项通过 (94%)**

**镜像 URL**:
```
ARM64:  https://cloud.centos.org/centos/9-stream/aarch64/images/CentOS-Stream-GenericCloud-9-latest.aarch64.qcow2
x86_64: https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2
```

---

### 2. CentOS Stream 8 ⭐⭐⭐⭐

**状态**: ⚠️ **EOL (2024年5月),仍可用于测试**

| 属性 | 详情 |
|------|------|
| **发布时间** | 2019年9月 |
| **EOL 时间** | 2024年5月31日 |
| **内核版本** | 4.18.0-x.el8 |
| **包管理** | DNF 4.x (yum 兼容) |
| **Python 版本** | Python 3.6 |
| **架构支持** | x86_64, aarch64 |
| **镜像大小** | 1.73 GB |

**特性**:
- ✅ SELinux 支持
- ✅ Systemd 239
- ⚠️ 不再接收安全更新
- ✅ 与 RHEL 8 兼容

**适用场景**:
- ⚠️ 测试旧版本兼容性
- ⚠️ 维护旧项目
- ❌ 不推荐用于生产环境

**镜像 URL**:
```
ARM64:  https://cloud.centos.org/centos/8-stream/aarch64/images/CentOS-Stream-GenericCloud-8-latest.aarch64.qcow2
x86_64: https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2
```

---

### 3. CentOS 8 (标准版) ⭐⭐⭐

**状态**: ❌ **EOL (2021年12月),仅用于历史项目**

| 属性 | 详情 |
|------|------|
| **发布时间** | 2019年9月 |
| **EOL 时间** | 2021年12月31日 |
| **最后版本** | 8.4.2105 |
| **内核版本** | 4.18.0-305.el8 |
| **包管理** | DNF 4.2.x (yum 兼容) |
| **Python 版本** | Python 3.6 |
| **架构支持** | x86_64, aarch64 |
| **镜像大小** | 1.16-1.31 GB |

**特性**:
- ✅ 稳定的最终版本
- ❌ 不再接收任何更新
- ⚠️ 仓库已归档

**适用场景**:
- ⚠️ 维护停止更新的旧项目
- ⚠️ 测试特定版本兼容性
- ❌ **强烈不推荐**新项目使用

**镜像 URL**:
```
ARM64:  https://cloud.centos.org/centos/8/aarch64/images/CentOS-8-GenericCloud-8.4.2105-20210603.0.aarch64.qcow2
x86_64: https://cloud.centos.org/centos/8/x86_64/images/CentOS-8-GenericCloud-8.4.2105-20210603.0.x86_64.qcow2
```

---

### 4. CentOS 7 ⭐⭐⭐

**状态**: ⚠️ **EOL (2024年6月),长期支持版本**

| 属性 | 详情 |
|------|------|
| **发布时间** | 2014年7月 |
| **EOL 时间** | 2024年6月30日 |
| **最后版本** | 7.9.2009 |
| **内核版本** | 3.10.0-1160.el7 |
| **包管理** | YUM 3.4.x |
| **Python 版本** | Python 2.7 (默认) |
| **架构支持** | x86_64 only ⚠️ |
| **镜像大小** | 902 MB |

**特性**:
- ✅ 经典版本,广泛使用
- ⚠️ 使用 YUM (非 DNF)
- ⚠️ Python 2 为默认版本
- ❌ 不再接收安全更新

**适用场景**:
- ⚠️ 维护遗留系统
- ⚠️ 兼容性测试
- ❌ **不推荐**新项目使用

**重要提示**:
- ❌ **无 ARM64 官方云镜像**
- ⚠️ 仅支持 x86_64 架构
- ⚠️ Python 2 已停止支持

**镜像 URL**:
```
x86_64: https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2
```

---

## 🔧 配置文件支持

### 完整的 `distribution-info.json`

配置文件已扩展支持所有 4 个版本:

```json
{
    "CentOS-7": {
        "aliases": "centos7, centos-7",
        "items": { ... }
    },
    "CentOS-8": {
        "aliases": "centos8, centos-8",
        "items": { ... }
    },
    "CentOS-Stream-8": {
        "aliases": "centos-stream-8, centos-stream8",
        "items": { ... }
    },
    "CentOS-Stream-9": {
        "aliases": "centos, centos-stream, centos9, centos-stream-9",
        "items": { ... }
    }
}
```

### Linux 部署步骤

```bash
# 1. 复制配置文件
sudo cp multipass/data/distributions/distribution-info.json \
     /var/snap/multipass/common/data/distributions/

# 2. 重启 Multipass
sudo snap restart multipass

# 3. 验证
multipass find | grep -i centos
```

---

## 📊 版本对比表

### 功能对比

| 特性 | CentOS 7 | CentOS 8 | Stream 8 | Stream 9 |
|------|----------|----------|----------|----------|
| **维护状态** | ❌ EOL | ❌ EOL | ⚠️ EOL | ✅ 活跃 |
| **包管理器** | YUM 3.x | DNF 4.x | DNF 4.x | DNF 4.x |
| **Systemd** | 219 | 239 | 239 | 252+ |
| **SELinux** | ✅ | ✅ | ✅ | ✅ |
| **Python 默认** | 2.7 | 3.6 | 3.6 | 3.9+ |
| **内核** | 3.10 | 4.18 | 4.18 | 5.14+ |
| **ARM64** | ❌ | ✅ | ✅ | ✅ |
| **x86_64** | ✅ | ✅ | ✅ | ✅ |

### 镜像大小对比

| 版本 | ARM64 | x86_64 |
|------|-------|--------|
| **CentOS 7** | N/A | 902 MB |
| **CentOS 8** | 1.16 GB | 1.31 GB |
| **Stream 8** | 1.73 GB | 1.73 GB |
| **Stream 9** | 1.46 GB | 1.46 GB |

---

## 💡 版本选择建议

### 🌟 新项目推荐

**首选: CentOS Stream 9**
```bash
multipass launch centos --name my-project
```

**理由**:
- ✅ 持续接收安全更新
- ✅ 最新的软件包和技术
- ✅ 与 RHEL 9 完全兼容
- ✅ 长期支持

### ⚠️ 维护旧项目

**根据原系统版本选择**:
```bash
# 如果原系统是 CentOS 8
multipass launch centos8 --name legacy-project

# 如果原系统是 CentOS 7
multipass launch centos7 --name old-project
```

**注意事项**:
- ⚠️ 考虑尽快升级到 Stream 9
- ⚠️ EOL 版本不再接收安全补丁
- ⚠️ 某些软件包仓库可能不可用

---

## 🔍 版本验证命令

启动虚拟机后,验证系统版本:

```bash
# 查看系统版本
multipass exec <vm-name> -- cat /etc/os-release

# 查看内核版本
multipass exec <vm-name> -- uname -r

# 查看包管理器版本
multipass exec <vm-name> -- yum --version

# 或 DNF
multipass exec <vm-name> -- dnf --version

# 查看 Python 版本
multipass exec <vm-name> -- python --version
multipass exec <vm-name> -- python3 --version

# 查看 SELinux 状态
multipass exec <vm-name> -- getenforce
```

---

## 🛠️ 常见问题解决

### 1. DNS 解析问题 (所有版本通用)

```bash
# 配置 DNS
multipass exec <vm-name> -- sudo bash -c \
  'echo "nameserver 8.8.8.8" > /etc/resolv.conf'
```

### 2. CentOS 8/Stream 8 仓库问题

```bash
# 切换到 Vault 镜像 (CentOS 8)
multipass exec centos8 -- sudo sed -i \
  's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*

multipass exec centos8 -- sudo sed -i \
  's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' \
  /etc/yum.repos.d/CentOS-*
```

### 3. CentOS 7 Python 3 支持

```bash
# 安装 Python 3
multipass exec centos7 -- sudo yum install -y python3

# 验证
multipass exec centos7 -- python3 --version
```

---

## 📚 版本历史

### CentOS 版本时间线

```
2014-07   CentOS 7 发布
2019-09   CentOS 8 发布
2019-09   CentOS Stream 8 发布
2021-11   CentOS Stream 9 发布
2021-12   CentOS 8 EOL ❌
2024-05   CentOS Stream 8 EOL ⚠️
2024-06   CentOS 7 EOL ⚠️
```

### 未来计划

- **CentOS Stream 9**: 持续维护至 RHEL 9 生命周期结束 (~2032年)
- **CentOS Stream 10**: 预计跟随 RHEL 10 发布

---

## 🎯 快速参考卡

### 别名速查表

| 命令 | 启动的版本 |
|------|-----------|
| `multipass launch centos` | CentOS Stream 9 (默认) |
| `multipass launch centos9` | CentOS Stream 9 |
| `multipass launch centos-stream-9` | CentOS Stream 9 |
| `multipass launch centos-stream-8` | CentOS Stream 8 |
| `multipass launch centos8` | CentOS 8.4 |
| `multipass launch centos7` | CentOS 7.9 |

### 架构支持速查

| 版本 | ARM64 (Apple Silicon) | x86_64 (Intel/AMD) |
|------|----------------------|-------------------|
| Stream 9 | ✅ | ✅ |
| Stream 8 | ✅ | ✅ |
| CentOS 8 | ✅ | ✅ |
| CentOS 7 | ❌ | ✅ |

---

## 📖 相关文档

- [CENTOS_FINAL_TEST_REPORT.md](CENTOS_FINAL_TEST_REPORT.md) - CentOS Stream 9 完整测试报告
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - 部署指南
- [README.md](README.md) - 项目说明

---

## 🎉 总结

### 支持情况

- ✅ **4 个 CentOS 版本完全支持**
- ✅ **3 个版本支持 ARM64**
- ✅ **所有版本支持 x86_64**
- ✅ **配置文件已完整扩展**

### 推荐使用

**新项目**: CentOS Stream 9 ⭐⭐⭐⭐⭐  
**测试兼容性**: 根据需要选择对应版本  
**旧项目维护**: 使用对应版本,但计划升级

---

**文档版本**: 1.0  
**最后更新**: 2026-03-22  
**维护者**: WorkBuddy AI Agent
