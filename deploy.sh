#!/bin/bash

# OpenIM Server 直接替换部署脚本
# 构建新镜像并直接替换运行中的 openim-server 容器

set -e

echo "=== OpenIM Server 容器替换部署 ==="
echo "时间: $(date)"
echo "分支: $(git branch --show-current)" 
echo "提交: $(git rev-parse --short HEAD)"

# 配置参数
CONTAINER_NAME="${CONTAINER_NAME:-openim-server}"
IMAGE_TAG="${IMAGE_TAG:-openim-server:latest}"
COMMIT_HASH=$(git rev-parse --short HEAD)
NEW_IMAGE_TAG="${NEW_IMAGE_TAG:-openim-server:${COMMIT_HASH}}"

echo "容器名称: $CONTAINER_NAME"
echo "当前镜像: $IMAGE_TAG"
echo "新镜像标签: $NEW_IMAGE_TAG"
echo "提交哈希: $COMMIT_HASH"

# 1. 构建新镜像
echo "=== 构建新镜像 ==="
docker build -t "$NEW_IMAGE_TAG" .

# 2. 备份当前镜像标签
docker tag "$IMAGE_TAG" "openim-server:backup-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || echo "当前镜像不存在，跳过备份"

# 3. 标记新镜像为生产标签
docker tag "$NEW_IMAGE_TAG" "$IMAGE_TAG"

echo "✅ 镜像构建完成: $NEW_IMAGE_TAG -> $IMAGE_TAG"

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
    
    # 添加镜像
    RUN_CMD="$RUN_CMD $IMAGE_TAG"
    
    echo "执行命令: $RUN_CMD"
    eval $RUN_CMD
    
else
    echo "⚠️  未发现运行中的 $CONTAINER_NAME 容器"
    echo "启动新容器（使用默认配置）..."
    
    # 启动新容器（默认配置）
    docker run -d \
        --name "$CONTAINER_NAME" \
        --init \
        --restart=always \
        -p 10001:10001 \
        -p 10002:10002 \
        "$IMAGE_TAG"
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
echo "新镜像: $NEW_IMAGE_TAG"
echo "运行镜像: $IMAGE_TAG"
echo "API 地址: http://localhost:10002"

# 显示容器状态
echo "=== 容器状态 ==="
docker ps -f name="$CONTAINER_NAME"

echo "🎉 容器替换部署完成！"