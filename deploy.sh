#!/bin/bash

# OpenIM Server 容器替换部署脚本
# 从 GitHub Container Registry 拉取 GitHub Actions 构建的镜像

set -e

echo "=== OpenIM Server 容器替换部署 ==="
echo "时间: $(date)"
echo "分支: $(git branch --show-current)" 
echo "提交: $(git rev-parse --short HEAD)"

# 配置参数
CONTAINER_NAME="${CONTAINER_NAME:-openim-server}"
COMMIT_HASH=$(git rev-parse --short HEAD)
BRANCH_NAME=$(git branch --show-current)
# GitHub Container Registry 镜像
GITHUB_IMAGE="${GITHUB_IMAGE:-ghcr.io/rajeevkumarsh/open-im-server:${BRANCH_NAME}-${COMMIT_HASH}}"
# Discord Webhook URL
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-https://discord.com/api/webhooks/1410921882714116227/M4NJjctluETrJk5JnWwW8U0uWCcgO_MYSCy-w8QefRI56zmMkY3Ii5C47MegO4A_1Vjm}"

echo "容器名称: $CONTAINER_NAME"
echo "提交哈希: $COMMIT_HASH" 
echo "分支名称: $BRANCH_NAME"
echo "GitHub 镜像: $GITHUB_IMAGE"

# 1. 从 GitHub Container Registry 拉取最新镜像
echo "=== 拉取最新镜像 ==="
docker pull "$GITHUB_IMAGE"

echo "✅ 镜像拉取完成"

# 4. 获取当前容器的运行参数
echo "=== 获取容器运行参数 ==="
if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    echo "发现运行中的容器: $CONTAINER_NAME"
    
    # 获取网络信息
    NETWORKS=$(docker inspect "$CONTAINER_NAME" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null || echo "")
    echo "容器网络: $NETWORKS"
    
    # 获取端口映射
    PORTS=$(docker port "$CONTAINER_NAME" 2>/dev/null || echo "")
    echo "端口映射: $PORTS"
    
    # 5. 停止并删除旧容器
    echo "=== 停止旧容器 ==="
    docker stop "$CONTAINER_NAME"
    docker rm "$CONTAINER_NAME"
    
    # 6. 启动新容器
    echo "=== 启动新容器 ==="
    
    # 构建 docker run 命令
    RUN_CMD="docker run -d --name $CONTAINER_NAME"
    
    # 添加网络参数
    for network in $NETWORKS; do
        if [ "$network" != "bridge" ]; then
            RUN_CMD="$RUN_CMD --network $network"
        fi
    done
    
    # 添加端口映射（从 docker ps 获取）
    if echo "$PORTS" | grep -q "10001"; then
        RUN_CMD="$RUN_CMD -p 10001:10001"
    fi
    if echo "$PORTS" | grep -q "10002"; then
        RUN_CMD="$RUN_CMD -p 10002:10002"
    fi
    
    # 添加基本配置
    RUN_CMD="$RUN_CMD --init --restart=always"
    
    # 添加 GitHub Actions 构建的镜像
    RUN_CMD="$RUN_CMD $GITHUB_IMAGE"
    
    echo "执行命令: $RUN_CMD"
    eval $RUN_CMD
    
else
    echo "⚠️  未发现运行中的 $CONTAINER_NAME 容器"
    echo "启动新容器（使用默认配置）..."
    
    # 启动新容器（使用 GitHub Actions 构建的镜像）
    docker run -d \
        --name "$CONTAINER_NAME" \
        --init \
        --restart=always \
        -p 10001:10001 \
        -p 10002:10002 \
        "$GITHUB_IMAGE"
fi

# 7. 等待容器启动
echo "=== 等待容器启动 ==="
sleep 15

# 8. 健康检查
echo "=== 健康检查 ==="
for i in {1..30}; do
    if curl -f http://localhost:10002/api/get_server_api_map &>/dev/null; then
        echo "✅ OpenIM Server 启动成功"
        
        # 发送部署成功通知到 Discord
        curl -X POST "$DISCORD_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d '{
                "embeds": [{
                    "title": "🎉 OpenIM Server - 部署成功",
                    "description": "容器替换部署完成，服务正常运行",
                    "color": 3066993,
                    "fields": [
                        {
                            "name": "分支",
                            "value": "'$BRANCH_NAME'",
                            "inline": true
                        },
                        {
                            "name": "提交哈希",
                            "value": "'$COMMIT_HASH'",
                            "inline": true
                        },
                        {
                            "name": "运行镜像",
                            "value": "'$GITHUB_IMAGE'",
                            "inline": false
                        },
                        {
                            "name": "API 地址",
                            "value": "http://localhost:10002",
                            "inline": true
                        },
                        {
                            "name": "部署时间",
                            "value": "'"$(date)"'",
                            "inline": false
                        }
                    ]
                }]
            }' &>/dev/null || echo "⚠️  Discord 通知发送失败"
        
        break
    fi
    
    if [ $i -eq 30 ]; then
        echo "❌ 健康检查失败"
        echo "=== 容器状态 ==="
        docker ps -f name="$CONTAINER_NAME"
        echo "=== 容器日志 ==="
        docker logs --tail=20 "$CONTAINER_NAME"
        
        # 发送部署失败通知到 Discord
        curl -X POST "$DISCORD_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d '{
                "embeds": [{
                    "title": "❌ OpenIM Server - 部署失败",
                    "description": "健康检查超时，服务启动失败",
                    "color": 15158332,
                    "fields": [
                        {
                            "name": "分支",
                            "value": "'$BRANCH_NAME'",
                            "inline": true
                        },
                        {
                            "name": "提交哈希",
                            "value": "'$COMMIT_HASH'",
                            "inline": true
                        },
                        {
                            "name": "镜像",
                            "value": "'$GITHUB_IMAGE'",
                            "inline": false
                        },
                        {
                            "name": "失败时间",
                            "value": "'"$(date)"'",
                            "inline": true
                        }
                    ]
                }]
            }' &>/dev/null || echo "⚠️  Discord 通知发送失败"
            
        exit 1
    fi
    
    echo "等待服务启动... ($i/30)"
    sleep 2
done

# 9. 显示部署结果
echo "=== 部署成功 ==="
echo "✅ OpenIM Server 容器替换完成"
echo "提交哈希: $COMMIT_HASH"
echo "运行镜像: $GITHUB_IMAGE"
echo "API 地址: http://localhost:10002"

# 显示容器状态
echo "=== 容器状态 ==="
docker ps -f name="$CONTAINER_NAME"

echo "🎉 容器替换部署完成！"