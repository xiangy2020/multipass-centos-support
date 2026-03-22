# CentOS 集群快速部署 - 命令清单

## 🚀 一键复制粘贴命令

### 第 1 步: 创建三个节点

```bash
multipass launch centos9 --name node-1 --cpus 2 --memory 2G --disk 20G && \
multipass launch centos9 --name node-2 --cpus 2 --memory 2G --disk 20G && \
multipass launch centos9 --name node-3 --cpus 2 --memory 2G --disk 20G
```

### 第 2 步: 查看节点状态

```bash
multipass list
```

### 第 3 步: 获取 IP 地址

```bash
echo "=== 节点 IP 地址 ==="
echo -n "node-1: " && multipass info node-1 | grep IPv4 | awk '{print $2}'
echo -n "node-2: " && multipass info node-2 | grep IPv4 | awk '{print $2}'
echo -n "node-3: " && multipass info node-3 | grep IPv4 | awk '{print $2}'
```

### 第 4 步: 配置集群网络 (需替换 IP)

**⚠️ 重要**: 先执行第 3 步获取实际 IP,然后替换下面的 IP 地址!

```bash
# 设置变量 (替换为您的实际 IP)
NODE1_IP="10.211.55.10"
NODE2_IP="10.211.55.11"
NODE3_IP="10.211.55.12"

# 配置所有节点的 /etc/hosts
for i in 1 2 3; do
  multipass exec node-$i -- sudo bash -c "cat >> /etc/hosts <<EOF

# CentOS Cluster Nodes
$NODE1_IP node-1 node-1.cluster.local
$NODE2_IP node-2 node-2.cluster.local
$NODE3_IP node-3 node-3.cluster.local
EOF"
done
```

### 第 5 步: 测试集群连通性

```bash
echo "测试 node-1 -> node-2..."
multipass exec node-1 -- ping -c 2 node-2

echo "测试 node-1 -> node-3..."
multipass exec node-1 -- ping -c 2 node-3

echo "测试 node-2 -> node-3..."
multipass exec node-2 -- ping -c 2 node-3
```

---

## ✅ 部署完成!

### 连接到节点

```bash
multipass shell node-1
```

### 批量操作

```bash
# 在所有节点执行命令
for i in 1 2 3; do
  echo "=== Node-$i ==="
  multipass exec node-$i -- hostname
done
```

### 安装常用工具

```bash
# 在所有节点安装工具
for i in 1 2 3; do
  multipass exec node-$i -- sudo dnf install -y vim git curl wget htop
done
```

---

## 🔧 集群管理命令

```bash
# 停止集群
multipass stop node-1 node-2 node-3

# 启动集群
multipass start node-1 node-2 node-3

# 重启集群
multipass restart node-1 node-2 node-3

# 查看状态
multipass list | grep node-

# 删除集群 (危险!)
multipass delete node-1 node-2 node-3 && multipass purge
```

---

## 📊 集群信息查看

```bash
# 查看所有节点详细信息
for i in 1 2 3; do
  echo "╔══════════════════════════════════════╗"
  echo "║ Node-$i 信息"
  echo "╚══════════════════════════════════════╝"
  multipass info node-$i | grep -E "State|IPv4|Release|Load|Disk|Memory"
  echo ""
done
```

---

## 🎯 下一步操作建议

### 部署 Web 服务器集群

```bash
# 在所有节点安装 nginx
for i in 1 2 3; do
  multipass exec node-$i -- sudo dnf install -y nginx
  multipass exec node-$i -- sudo systemctl enable --now nginx
done
```

### 配置 NFS 共享存储

```bash
# 在 node-1 配置 NFS 服务器
multipass exec node-1 -- sudo dnf install -y nfs-utils
multipass exec node-1 -- sudo mkdir -p /nfs-share
multipass exec node-1 -- sudo bash -c 'echo "/nfs-share *(rw,sync,no_root_squash)" >> /etc/exports'
multipass exec node-1 -- sudo systemctl enable --now nfs-server
multipass exec node-1 -- sudo exportfs -ra
```

### 配置 SSH 密钥认证

```bash
# 生成密钥对
ssh-keygen -t rsa -b 4096 -f ~/.ssh/centos_cluster_rsa -N ""

# 复制到所有节点
for i in 1 2 3; do
  multipass exec node-$i -- bash -c "mkdir -p ~/.ssh && echo '$(cat ~/.ssh/centos_cluster_rsa.pub)' >> ~/.ssh/authorized_keys"
done
```

---

## 🚀 准备部署 Kubernetes?

参考完整指南: [CLUSTER_DEPLOYMENT_GUIDE.md](./CLUSTER_DEPLOYMENT_GUIDE.md)

**快捷命令**:
```bash
# 禁用 SELinux (K8s 要求)
for i in 1 2 3; do
  multipass exec node-$i -- sudo setenforce 0
  multipass exec node-$i -- sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
done

# 禁用 swap
for i in 1 2 3; do
  multipass exec node-$i -- sudo swapoff -a
done
```

---

**完整文档**: 
- [MANUAL_CLUSTER_SETUP.md](./MANUAL_CLUSTER_SETUP.md) - 详细部署指南
- [CLUSTER_DEPLOYMENT_GUIDE.md](./CLUSTER_DEPLOYMENT_GUIDE.md) - 完整集群管理手册
