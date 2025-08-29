#!/bin/bash

# 在服务器上运行此脚本配置 sudo 免密码
# 使用方法: sudo bash setup-sudo.sh

echo "配置 ubuntu 用户 sudo 免密码..."

# 方法1: 编辑 sudoers 文件
echo "ubuntu ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/ubuntu

# 设置正确的权限
sudo chmod 0440 /etc/sudoers.d/ubuntu

# 验证配置
sudo visudo -c

echo "✅ 配置完成！现在 ubuntu 用户可以无密码使用 sudo"
echo "测试: sudo whoami"