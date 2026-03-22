# CentOS 三节点集群项目总览

## 📖 项目更新

**更新日期**: 2026-03-22  
**新增功能**: 三节点 CentOS 集群部署支持

---

## 🎉 新增内容

### 1. 集群部署脚本

| 脚本文件 | 说明 | 用途 |
|---------|------|------|
| `deploy_cluster_simple.sh` | 简化版部署脚本 | 一键自动化部署 |
| `deploy_centos_cluster.sh` | 完整版部署脚本 | 高级自动化部署 (支持更多配置) |
| `check_cluster.sh` | 集群状态检查 | 查看所有节点状态 |
| `start_cluster.sh` | 集群启动脚本 | 启动所有节点 |
| `stop_cluster.sh` | 集群停止脚本 | 停止所有节点 |
| `delete_cluster.sh` | 集群删除脚本 | 完全删除集群 |
| `ssh_node1.sh` ~ `ssh_node3.sh` | SSH 连接脚本 | 快速连接到各节点 |

### 2. 集群部署文档

| 文档文件 | 说明 | 适用人群 |
|---------|------|----------|
| `CLUSTER_DEPLOYMENT_GUIDE.md` | 完整集群部署和管理指南 | 所有用户 |
| `MANUAL_CLUSTER_SETUP.md` | 手动部署详细步骤 | 学习者,需要自定义配置的用户 |
| `CLUSTER_QUICK_START.md` | 快速命令清单 | 快速部署用户 |
| `CLUSTER_USAGE.md` | 集群使用手册 | 部署后自动生成 |

---

## 🚀 快速开始

### 方法 1: 自动化部署 (推荐)

```bash
cd /Users/tompyang/WorkBuddy/20260320161009
./deploy_cluster_simple.sh
```

预计时间: 5-10 分钟

### 方法 2: 手动部署

参考: [CLUSTER_QUICK_START.md](./CLUSTER_QUICK_START.md)

```bash
# 1. 创建节点
multipass launch centos9 --name node-1 --cpus 2 --memory 2G --disk 20G
multipass launch centos9 --name node-2 --cpus 2 --memory 2G --disk 20G
multipass launch centos9 --name node-3 --cpus 2 --memory 2G --disk 20G

# 2. 配置网络和测试连通性
# (详见 CLUSTER_QUICK_START.md)
```

---

## 📊 集群架构

```
┌─────────────────────────────────────────────────┐
│                CentOS Cluster                    │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│  │ node-1   │    │ node-2   │    │ node-3   │  │
│  │ Master   │◄──►│ Worker 1 │◄──►│ Worker 2 │  │
│  │          │    │          │    │          │  │
│  │ 2 CPU    │    │ 2 CPU    │    │ 2 CPU    │  │
│  │ 2G RAM   │    │ 2G RAM   │    │ 2G RAM   │  │
│  │ 20G Disk │    │ 20G Disk │    │ 20G Disk │  │
│  └──────────┘    └──────────┘    └──────────┘  │
│                                                  │
│  Private Network: 10.x.x.x/24                   │
│  Hostnames: node-1, node-2, node-3              │
│  OS: CentOS Stream 9                            │
└─────────────────────────────────────────────────┘
```

---

## 🎯 集群应用场景

### 1. Kubernetes 集群
- 三节点高可用 K8s 集群
- 1 个 Master + 2 个 Worker
- 适合学习和测试

### 2. Docker Swarm 集群
- 容器编排学习
- 服务发现和负载均衡
- 高可用性测试

### 3. Ceph 存储集群
- 分布式存储学习
- 数据冗余和恢复
- 性能测试

### 4. Elasticsearch 集群
- 搜索引擎集群
- 日志聚合
- 数据分析

### 5. 数据库集群
- PostgreSQL 高可用 (Patroni)
- MySQL 主从复制
- Redis Cluster

---

## 📚 完整文档导航

### 核心文档

| 文档 | 说明 | 优先级 |
|------|------|-------|
| [README.md](./README.md) | 项目总览 | ⭐⭐⭐⭐⭐ |
| [CLUSTER_QUICK_START.md](./CLUSTER_QUICK_START.md) | 🚀 **快速部署命令清单** | ⭐⭐⭐⭐⭐ |
| [CLUSTER_DEPLOYMENT_GUIDE.md](./CLUSTER_DEPLOYMENT_GUIDE.md) | 🏗️ **完整集群部署指南** | ⭐⭐⭐⭐⭐ |
| [MANUAL_CLUSTER_SETUP.md](./MANUAL_CLUSTER_SETUP.md) | 📖 手动部署详细步骤 | ⭐⭐⭐⭐ |

### CentOS 支持文档

| 文档 | 说明 | 优先级 |
|------|------|-------|
| [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) | CentOS 支持部署指南 | ⭐⭐⭐⭐ |
| [CENTOS_MULTI_VERSION_GUIDE.md](./CENTOS_MULTI_VERSION_GUIDE.md) | 多版本支持 (7/8/9) | ⭐⭐⭐⭐ |
| [MULTIPASS_CENTOS_SUMMARY.md](./MULTIPASS_CENTOS_SUMMARY.md) | 技术实现总结 | ⭐⭐⭐ |
| [CENTOS_FINAL_TEST_REPORT.md](./CENTOS_FINAL_TEST_REPORT.md) | 测试报告 | ⭐⭐⭐ |

### GitHub 相关

| 文档 | 说明 |
|------|------|
| [GITHUB_SUCCESS.md](./GITHUB_SUCCESS.md) | GitHub 推送成功总结 |
| [GITHUB_PUSH_GUIDE.md](./GITHUB_PUSH_GUIDE.md) | GitHub 推送完整指南 |

---

## 🔧 项目结构

```
/Users/tompyang/WorkBuddy/20260320161009/
├── multipass/                              # Multipass 源码 (已改造)
├── multipass-patches/                      # 核心补丁文件
│   ├── data/distributions/
│   │   └── distribution-info.json
│   ├── tools/distro-scraper/scraper/scrapers/
│   │   └── centos.py
│   └── tools/distro-scraper/
│       └── pyproject.toml
│
├── 集群部署脚本/
│   ├── deploy_cluster_simple.sh           # 简化版部署脚本
│   ├── deploy_centos_cluster.sh           # 完整版部署脚本
│   ├── check_cluster.sh                   # 状态检查
│   ├── start_cluster.sh                   # 启动集群
│   ├── stop_cluster.sh                    # 停止集群
│   ├── delete_cluster.sh                  # 删除集群
│   └── ssh_node[1-3].sh                   # SSH 连接脚本
│
├── 集群文档/
│   ├── CLUSTER_DEPLOYMENT_GUIDE.md        # 完整部署指南
│   ├── MANUAL_CLUSTER_SETUP.md            # 手动部署步骤
│   └── CLUSTER_QUICK_START.md             # 快速命令清单
│
├── CentOS 支持文档/
│   ├── DEPLOYMENT_GUIDE.md
│   ├── CENTOS_MULTI_VERSION_GUIDE.md
│   ├── MULTIPASS_CENTOS_SUMMARY.md
│   ├── CENTOS_FINAL_TEST_REPORT.md
│   ├── CENTOS_TEST_EXECUTION.md
│   └── CENTOS_TEST_REPORT.md
│
├── 测试脚本/
│   ├── test_centos_support.sh
│   ├── test_centos_full.sh
│   ├── auto_test_centos.sh
│   └── run_tests_on_existing_vm.sh
│
└── README.md                               # 项目总览 (本文件)
```

---

## 📊 项目统计

### 代码和文档

- **总代码行数**: ~1200 行
- **文档数量**: 13 份完整文档
- **文档总页数**: 80+ 页
- **测试脚本**: 4 个

### 功能覆盖

- ✅ CentOS 7/8/Stream 8/Stream 9 支持
- ✅ 单节点快速部署
- ✅ **三节点集群自动化部署** (新增)
- ✅ 完整的测试套件 (16 项测试,94% 通过)
- ✅ 多架构支持 (x86_64, ARM64)

---

## 🎯 使用场景

### 1. 学习和开发
- ✅ 快速搭建 CentOS 开发环境
- ✅ 学习分布式系统
- ✅ 测试应用的集群部署

### 2. 生产环境模拟
- ✅ 模拟生产环境架构
- ✅ 测试高可用性配置
- ✅ 性能和压力测试

### 3. DevOps 实践
- ✅ CI/CD 流程测试
- ✅ 配置管理工具学习 (Ansible, Puppet)
- ✅ 监控和日志系统部署

### 4. 容器和编排
- ✅ Kubernetes 集群部署
- ✅ Docker Swarm 学习
- ✅ 容器网络和存储测试

---

## 🚀 快速链接

### 立即开始

```bash
# 克隆项目
git clone https://github.com/xiangy2020/multipass-centos-support.git
cd multipass-centos-support

# 部署集群
./deploy_cluster_simple.sh
```

### 获取帮助

- **GitHub Issues**: https://github.com/xiangy2020/multipass-centos-support/issues
- **Multipass 文档**: https://multipass.run/docs
- **CentOS 文档**: https://docs.centos.org/

---

## 🎉 项目亮点

### 完整性
- ✅ 从 CentOS 支持到集群部署的完整方案
- ✅ 详尽的文档和自动化脚本
- ✅ 经过充分测试和验证

### 易用性
- ✅ 一键自动化部署
- ✅ 清晰的文档结构
- ✅ 丰富的示例和命令

### 专业性
- ✅ 遵循最佳实践
- ✅ 完整的错误处理
- ✅ 详细的故障排除指南

---

## 💡 下一步建议

1. **阅读快速开始文档**: [CLUSTER_QUICK_START.md](./CLUSTER_QUICK_START.md)
2. **运行自动化部署**: `./deploy_cluster_simple.sh`
3. **测试集群连通性**: 验证节点间通信
4. **部署您的应用**: Kubernetes, Docker, Ceph 等
5. **分享您的经验**: GitHub Issues, 社区论坛

---

## 🙏 致谢

- **Canonical** - Multipass 项目
- **CentOS 社区** - CentOS 镜像
- **开源社区** - 所有贡献者

---

## 📄 许可证

本项目遵循 **GNU General Public License v3.0** (GPL-3.0)

---

**项目主页**: https://github.com/xiangy2020/multipass-centos-support  
**创建日期**: 2026-03-22  
**最后更新**: 2026-03-22

**准备好开始您的 CentOS 集群之旅了吗? 🚀**
