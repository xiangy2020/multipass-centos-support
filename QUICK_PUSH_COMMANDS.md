# 🚀 快速推送到 GitHub - 3 步完成

## 方法 1: 自动化脚本 (最简单,推荐!)

```bash
# 1. 给脚本添加执行权限
chmod +x push_to_github.sh

# 2. 运行脚本
./push_to_github.sh

# 3. 按照提示操作
# - 输入 GitHub 用户名
# - 输入仓库名
# - 确认推送
```

**完成!** 🎉 你的代码已经推送到 GitHub!

---

## 方法 2: 手动命令 (3 步)

### 第 1 步: 初始化并提交

```bash
# 初始化 Git (如果还没有)
git init

# 添加所有文件
git add .

# 创建提交
git commit -m "feat: Add Multipass CentOS support and 3-node cluster deployment"
```

### 第 2 步: 在 GitHub 创建仓库

1. 访问 https://github.com/new
2. 仓库名: `multipass-centos-cluster`
3. 描述: `Multipass CentOS support + automated 3-node cluster deployment`
4. 选择 Public 或 Private
5. **不要**勾选 "Initialize with README"
6. 点击 "Create repository"

### 第 3 步: 推送到 GitHub

```bash
# 添加远程仓库 (替换 YOUR_USERNAME)
git remote add origin https://github.com/YOUR_USERNAME/multipass-centos-cluster.git

# 推送
git branch -M main
git push -u origin main
```

**完成!** 🎉

---

## 方法 3: 使用 GitHub CLI (极速!)

```bash
# 安装 GitHub CLI (如果没有)
brew install gh

# 登录
gh auth login

# 创建仓库并推送 (一键完成!)
gh repo create multipass-centos-cluster \
  --public \
  --description "Multipass CentOS support + automated 3-node cluster deployment" \
  --source=. \
  --push
```

**完成!** 🎉 这个方法会自动创建仓库并推送!

---

## 推送后检查清单

- [ ] 访问你的 GitHub 仓库页面
- [ ] 确认所有文件都已上传
- [ ] README.md 正常显示
- [ ] 添加 Topics: multipass, centos, cluster, virtualization
- [ ] 创建 Release v1.0.0 (可选)
- [ ] 分享你的项目!

---

## 仓库链接格式

你的仓库地址会是:

```
https://github.com/YOUR_USERNAME/multipass-centos-cluster
```

替换 `YOUR_USERNAME` 为你的 GitHub 用户名。

---

## 需要帮助?

查看详细文档: [GITHUB_PUSH_GUIDE.md](./GITHUB_PUSH_GUIDE.md)

---

**现在就开始推送吧!** 运行:

```bash
./push_to_github.sh
```

🚀 **Let's go!**
