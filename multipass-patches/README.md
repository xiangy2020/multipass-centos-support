# Multipass CentOS 支持补丁文件

本目录包含为 Multipass 添加 CentOS 支持所需的关键改动文件。

## 📂 目录结构

```
multipass-patches/
├── data/distributions/
│   └── distribution-info.json       # CentOS 镜像配置
├── tools/distro-scraper/
│   ├── pyproject.toml               # CentOS 抓取器插件注册
│   └── scraper/scrapers/
│       └── centos.py                # CentOS 镜像抓取器
└── README.md                        # 本文件
```

## 🚀 如何应用这些补丁

### 方法 1: 直接使用配置文件 (推荐,最简单)

适用于 **Linux 用户** (Snap 安装的 Multipass):

```bash
# 1. 复制配置文件
sudo cp multipass-patches/data/distributions/distribution-info.json \
       /var/snap/multipass/common/data/distributions/

# 2. 重启 Multipass
sudo snap restart multipass

# 3. 验证
multipass find centos
multipass launch centos --name test-centos
```

### 方法 2: 从源码编译 (完整功能)

适用于需要镜像自动更新功能的开发者:

```bash
# 1. 克隆 Multipass 源码
git clone https://github.com/canonical/multipass.git
cd multipass

# 2. 应用补丁
cp ../multipass-patches/data/distributions/distribution-info.json \
   data/distributions/

cp ../multipass-patches/tools/distro-scraper/scraper/scrapers/centos.py \
   tools/distro-scraper/scraper/scrapers/

cp ../multipass-patches/tools/distro-scraper/pyproject.toml \
   tools/distro-scraper/

# 3. 编译和安装
# 参考 Multipass 官方文档:
# https://github.com/canonical/multipass#build-instructions
```

### 方法 3: macOS/Windows 用户

直接使用完整 URL 启动 CentOS 虚拟机:

```bash
# CentOS Stream 9 (ARM64 - Apple Silicon)
multipass launch https://cloud.centos.org/centos/9-stream/aarch64/images/CentOS-Stream-GenericCloud-9-latest.aarch64.qcow2 \
  --name centos9

# CentOS Stream 9 (x86_64 - Intel)
multipass launch https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2 \
  --name centos9
```

## 📋 改动说明

### 1. distribution-info.json

添加了 4 个 CentOS 版本的配置:
- **CentOS-7**: CentOS 7 (仅 x86_64)
- **CentOS-8**: CentOS 8.4 (ARM64 和 x86_64)
- **CentOS-Stream-8**: CentOS Stream 8 (ARM64 和 x86_64)
- **CentOS-Stream-9**: CentOS Stream 9 (ARM64 和 x86_64)

### 2. centos.py

新增的 CentOS 镜像抓取器,功能包括:
- 自动发现最新镜像
- 多架构支持 (ARM64 和 x86_64)
- SHA256 校验和验证
- 错误处理和日志记录

### 3. pyproject.toml

注册 CentOS 抓取器为可加载插件:
```toml
[project.entry-points."dist_scraper.scrapers"]
centos = "scraper.scrapers.centos:CentOSScraper"
```

## ✅ 支持的版本

| 版本 | 别名 | ARM64 | x86_64 | 状态 |
|------|------|-------|--------|------|
| CentOS Stream 9 | `centos`, `centos9` | ✅ | ✅ | 活跃维护 |
| CentOS Stream 8 | `centos-stream-8` | ✅ | ✅ | EOL (2024) |
| CentOS 8 | `centos8` | ✅ | ✅ | EOL (2021) |
| CentOS 7 | `centos7` | ❌ | ✅ | EOL (2024) |

## 🧪 测试

这些补丁已经过完整的 16 项功能测试,测试通过率 **94%**。

详细测试报告请参阅:
- [CENTOS_FINAL_TEST_REPORT.md](../CENTOS_FINAL_TEST_REPORT.md)
- [CENTOS_TEST_EXECUTION.md](../CENTOS_TEST_EXECUTION.md)

## 📖 更多信息

- [项目主页 README](../README.md)
- [部署指南](../DEPLOYMENT_GUIDE.md)
- [多版本支持指南](../CENTOS_MULTI_VERSION_GUIDE.md)
- [技术总结](../MULTIPASS_CENTOS_SUMMARY.md)

## 📄 许可证

这些补丁文件遵循 Multipass 项目的 GPL-3.0 许可证。
