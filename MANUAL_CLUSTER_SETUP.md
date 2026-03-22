# 🚀 CentOS 三节点集群 - 快速部署手册

## 📋 部署清单

**完成时间**: 约 5-10 分钟  
**前置要求**: Multipass 已安装,CentOS 镜像已配置

---

## 🎯 部署步骤

### 步骤 1: 创建三个节点

在终端执行以下命令:

```bash
# 创建 node-1 (Master 节点)
multipass launch centos9 --name node-1 --cpus 2 --memory 2G --disk 20G

# 创建 node-2 (Worker 1)
multipass launch centos9 --name node-2 --cpus 2 --memory 2G --disk 20G

# 创建 node-3 (Worker 2)
multipass launch centos9 --name node-3 --cpus 2 --memory 2G --disk 20G
```

**预计时间**: 每个节点约 1-2 分钟

---

### 步骤 2: 验证节点状态

```bash
multipass list
```

预期输出:
```
Name                    State             IPv4             Image
node-1                  Running           10.x.x.x         CentOS Stream 9
node-2                  Running           10.x.x.x         CentOS Stream 9
node-3                  Running           10.x.x.x         CentOS Stream 9
```

---

### 步骤 3: 获取节点 IP 地址

```bash
# 查看 node-1 IP
multipass info node-1 | grep IPv4

# 查看 node-2 IP
multipass info node-2 | grep IPv4

# 查看 node-3 IP
multipass info node-3 | grep IPv4
```

**记录这些 IP 地址,下一步需要使用!**

示例:
- node-1: 10.211.55.10
- node-2: 10.211.55.11
- node-3: 10.211.55.12

---

### 步骤 4: 配置集群网络 (主机名解析)

**方法 A**: 手动配置 (推荐学习)

在每个节点上添加 /etc/hosts 条目:

```bash
# 在 node-1 上执行
multipass exec node-1 -- sudo bash -c 'cat >> /etc/hosts <<EOF

# Cluster Nodes
10.211.55.10 node-1 node-1.cluster.local
10.211.55.11 node-2 node-2.cluster.local
10.211.55.12 node-3 node-3.cluster.local
EOF'

# 在 node-2 上执行
multipass exec node-2 -- sudo bash -c 'cat >> /etc/hosts <<EOF

# Cluster Nodes
10.211.55.10 node-1 node-1.cluster.local
10.211.55.11 node-2 node-2.cluster.local
10.211.55.12 node-3 node-3.cluster.local
EOF'

# 在 node-3 上执行
multipass exec node-3 -- sudo bash -c 'cat >> /etc/hosts <<EOF

# Cluster Nodes
10.211.55.10 node-1 node-1.cluster.local
10.211.55.11 node-2 node-2.cluster.local
10.211.55.12 node-3 node-3.cluster.local
EOF'
```

**⚠️ 注意**: 将上面的 IP 地址替换为您实际获取的 IP!

**方法 B**: 使用自动化脚本

我已经为您生成了 `deploy_cluster_simple.sh`,执行:

```bash
cd /Users/tompyang/WorkBuddy/20260320161009
./deploy_cluster_simple.sh
```

---

### 步骤 5: 测试集群连通性

```bash
# 从 node-1 ping node-2
multipass exec node-1 -- ping -c 3 node-2

# 从 node-1 ping node-3
multipass exec node-1 -- ping -c 3 node-3

# 从 node-2 ping node-3
multipass exec node-2 -- ping -c 3 node-3
```

如果所有 ping 都成功,说明集群网络配置正确! ✅

---

## 🎉 部署完成!

您现在拥有一个完整的三节点 CentOS 集群:

```
┌─────────────────────────────────────────┐
│          CentOS Cluster                  │
├─────────────────────────────────────────┤
│  node-1 (Master)    : 10.x.x.x          │
│  node-2 (Worker 1)  : 10.x.x.x          │
│  node-3 (Worker 2)  : 10.x.x.x          │
│                                          │
│  配置: 2 CPU, 2G RAM, 20G Disk / 节点   │
└─────────────────────────────────────────┘
```

---

## 📝 常用操作

### 连接到节点

```bash
# 方法 1: 使用 multipass shell
multipass shell node-1

# 方法 2: 使用 SSH (需配置密钥)
ssh ubuntu@10.x.x.x
```

### 在节点上执行命令

```bash
# 单条命令
multipass exec node-1 -- hostname
multipass exec node-1 -- cat /etc/centos-release

# 交互式 bash
multipass exec node-1 -- bash
```

### 批量操作所有节点

```bash
# 检查所有节点的 hostname
for i in 1 2 3; do
    echo "=== Node-$i ==="
    multipass exec node-$i -- hostname
done

# 更新所有节点
for i in 1 2 3; do
    echo "=== 更新 Node-$i ==="
    multipass exec node-$i -- sudo dnf update -y
done

# 安装工具到所有节点
for i in 1 2 3; do
    multipass exec node-$i -- sudo dnf install -y vim git curl htop
done
```

### 查看集群状态

```bash
# 查看所有虚拟机
multipass list

# 查看节点详细信息
multipass info node-1

# 查看资源使用
for i in 1 2 3; do
    echo "=== Node-$i ==="
    multipass exec node-$i -- free -h
    multipass exec node-$i -- df -h
done
```

---

## 🔧 集群管理

### 停止集群

```bash
multipass stop node-1 node-2 node-3
```

### 启动集群

```bash
multipass start node-1 node-2 node-3
```

### 重启集群

```bash
multipass restart node-1 node-2 node-3
```

### 删除集群 (危险!)

```bash
multipass delete node-1 node-2 node-3
multipass purge
```

---

## 🚀 下一步: 部署应用

### 选项 1: 部署 Kubernetes 集群

参考官方文档:
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/

基本步骤:
```bash
# 1. 在所有节点安装容器运行时
# 2. 在所有节点安装 kubeadm, kubelet, kubectl
# 3. 在 node-1 初始化 master
# 4. 在 node-2 和 node-3 加入集群
```

### 选项 2: 部署 Docker Swarm

```bash
# 在 node-1 初始化 Swarm
multipass exec node-1 -- sudo docker swarm init

# 获取 join token 并在 worker 节点加入
# (参考 Docker Swarm 官方文档)
```

### 选项 3: 测试和学习

```bash
# 在节点上运行 Web 服务器
multipass exec node-1 -- sudo dnf install -y nginx
multipass exec node-1 -- sudo systemctl start nginx

# 从 node-2 访问 node-1 的 Web 服务
multipass exec node-2 -- curl http://node-1
```

---

## 🆘 故障排除

### 问题 1: 节点无法启动

**症状**: `multipass launch` 失败

**解决方案**:
```bash
# 检查 Multipass 状态
multipass version

# 查看错误日志
tail -f /Library/Logs/Multipass/multipassd.log

# 重启 Multipass (macOS)
sudo launchctl unload /Library/LaunchDaemons/com.canonical.multipassd.plist
sudo launchctl load /Library/LaunchDaemons/com.canonical.multipassd.plist
```

### 问题 2: 节点间无法 ping 通

**症状**: `ping node-2` 失败

**解决方案**:
```bash
# 1. 检查 /etc/hosts 是否配置正确
multipass exec node-1 -- cat /etc/hosts

# 2. 检查防火墙
multipass exec node-1 -- sudo firewall-cmd --list-all

# 3. 临时禁用防火墙测试
multipass exec node-1 -- sudo systemctl stop firewalld
```

### 问题 3: IP 地址变化

**症状**: 重启后 IP 地址变了

**解决方案**:
1. 重新获取 IP 地址
2. 更新所有节点的 /etc/hosts
3. 或使用 Multipass 的主机名解析功能

---

## 📚 参考资料

### 官方文档
- **Multipass**: https://multipass.run/docs
- **CentOS**: https://docs.centos.org/
- **Kubernetes**: https://kubernetes.io/docs/
- **Docker**: https://docs.docker.com/

### 本项目文档
- [README.md](./README.md) - 项目总览
- [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - CentOS 支持部署
- [CLUSTER_DEPLOYMENT_GUIDE.md](./CLUSTER_DEPLOYMENT_GUIDE.md) - 完整集群指南
- [CENTOS_MULTI_VERSION_GUIDE.md](./CENTOS_MULTI_VERSION_GUIDE.md) - 多版本支持

---

## 💡 小贴士

1. **资源调整**: 根据需要调整 --cpus, --memory, --disk 参数
2. **版本选择**: 可以使用 centos7, centos8, centos9 等
3. **节点数量**: 可以创建更多节点 (node-4, node-5...)
4. **快照备份**: 定期备份重要数据
5. **监控日志**: 关注系统日志和应用日志

---

**创建日期**: 2026-03-22  
**项目**: Multipass CentOS 支持  
**祝您部署顺利! 🎉**
