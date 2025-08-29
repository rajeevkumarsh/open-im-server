#!/bin/bash

# OpenIM Server 容器替换部署脚本
# Coolify 已完成镜像构建，此脚本负责替换运行中的 openim-server 容器

set -e

echo "=== OpenIM Server 容器替换部署 ==="
echo "时间: $(date)"
echo "分支: $(git branch --show-current)" 
echo "提交: $(git rev-parse --short HEAD)"

# 配置参数
CONTAINER_NAME="${CONTAINER_NAME:-openim-server}"
COMMIT_HASH=$(git rev-parse --short HEAD)
# Coolify 构建的镜像通常使用应用名称作为标签
COOLIFY_IMAGE_TAG="${COOLIFY_IMAGE_TAG:-rajeevkumarsh/open-im-server:main-ok000cg0koowck4k8ock044g}"

echo "容器名称: $CONTAINER_NAME"
echo "提交哈希: $COMMIT_HASH" 
echo "Coolify 镜像: $COOLIFY_IMAGE_TAG"

echo "✅ 跳过镜像构建（Coolify 已完成）"

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
    
    # 添加 Coolify 构建的镜像
    RUN_CMD="$RUN_CMD $COOLIFY_IMAGE_TAG"
    
    echo "执行命令: $RUN_CMD"
    eval $RUN_CMD
    
else
    echo "⚠️  未发现运行中的 $CONTAINER_NAME 容器"
    echo "启动新容器（使用默认配置）..."
    
    # 启动新容器（使用 Coolify 构建的镜像）
    docker run -d \
        --name "$CONTAINER_NAME" \
        --init \
        --restart=always \
        -p 10001:10001 \
        -p 10002:10002 \
        "$COOLIFY_IMAGE_TAG"
fi

# 7. 等待容器启动
echo "=== 等待容器启动 ==="
sleep 15

# 8. 健康检查
echo "=== 健康检查 ==="
for i in {1..30}; do
    if curl -f http://localhost:10002/api/get_server_api_map &>/dev/null; then
        echo "✅ OpenIM Server 启动成功"
        break
    fi
    
    if [ $i -eq 30 ]; then
        echo "❌ 健康检查失败"
        echo "=== 容器状态 ==="
        docker ps -f name="$CONTAINER_NAME"
        echo "=== 容器日志 ==="
        docker logs --tail=20 "$CONTAINER_NAME"
        exit 1
    fi
    
    echo "等待服务启动... ($i/30)"
    sleep 2
done

# 9. 显示部署结果
echo "=== 部署成功 ==="
echo "✅ OpenIM Server 容器替换完成"
echo "提交哈希: $COMMIT_HASH"
echo "运行镜像: $COOLIFY_IMAGE_TAG"
echo "API 地址: http://localhost:10002"

# 显示容器状态
echo "=== 容器状态 ==="
docker ps -f name="$CONTAINER_NAME"

echo "🎉 容器替换部署完成！"