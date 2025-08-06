# self-scripted

🚀 实用的自动化脚本集合，帮助您快速部署和管理服务器环境

## 📋 脚本功能

### 1. O11 自动安装脚本 (`install_o11.sh`)
自动化部署 O11 DRMStuff 服务的一键安装脚本

**功能特性：**
- 🔧 自动下载并安装 O11 程序到 `/etc/o11` 目录
- 🎯 配置 systemd 服务，实现开机自启和故障重启
- ⚡ 一键部署，无需手动配置
- 📊 安装完成后自动显示服务状态

### 2. SSH 密钥管理工具 (`ssh_key_manager.sh`)
交互式的 SSH 公钥管理脚本，简化服务器密钥配置

**功能特性：**
- 🔑 添加 SSH 公钥到指定用户
- 👀 查看现有公钥列表
- 🗑️ 选择性删除特定公钥
- 🎨 彩色界面，操作直观友好
- 🛡️ 支持 root 和普通用户操作

## 🚀 快速使用

### O11 服务安装
```bash
bash <(curl -L https://raw.githubusercontent.com/G1deonChan/self-scripted/main/install_o11.sh)
```

### SSH 密钥管理
```bash
bash <(curl -L https://raw.githubusercontent.com/G1deonChan/self-scripted/main/ssh_key_manager.sh)
```

## 📖 使用说明

### O11 安装脚本
执行后会自动：
1. 创建 `/etc/o11` 目录
2. 下载最新版本的 O11 程序
3. 配置 systemd 服务
4. 启动服务并设置开机自启

### SSH 密钥管理工具
启动后提供交互式菜单：
1. **添加SSH公钥** - 为用户添加新的公钥
2. **查看现有公钥** - 显示当前用户的所有公钥
3. **清除公钥** - 删除指定的公钥
4. **退出** - 退出程序

## ⚠️ 注意事项

- 建议在执行脚本前备份重要配置文件
- O11 安装脚本需要 sudo 权限
- SSH 密钥管理建议在 root 权限下运行以获得完整功能
- 脚本适用于基于 systemd 的 Linux 发行版

## 📝 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情
