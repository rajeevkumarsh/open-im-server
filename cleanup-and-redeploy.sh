#!/bin/bash

# 清理冲突容器并重新部署 OpenIM

echo "=== 清理现有 openim-server 容器 ==="

# 1. 停止现有容器
echo "停止现有容器..."
sudo docker stop openim-server 2>/dev/null || echo "容器可能已停止"

# 2. 删除现有容器
echo "删除现有容器..."
sudo docker rm openim-server 2>/dev/null || echo "容器可能不存在"

# 3. 清理可能的悬挂容器
echo "清理悬挂容器..."
sudo docker container prune -f

# 4. 重新启动 docker-compose
echo "=== 重新启动 OpenIM Docker 栈 ==="
cd ~/openim-docker

# 停止所有服务
echo "停止所有服务..."
sudo docker compose --profile m down

# 启动所有服务
echo "启动所有服务..."
sudo docker compose --profile m up -d

# 5. 检查容器状态
echo "=== 检查容器状态 ==="
sleep 5
sudo docker ps | grep openim

# 6. 检查日志
echo "=== 检查 openim-server 日志 ==="
sudo docker logs openim-server --tail 20

echo "=== 部署完成 ==="