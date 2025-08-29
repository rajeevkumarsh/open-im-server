#!/bin/bash

# 测试 Portainer API 部署脚本

set -e

# 配置变量
PORTAINER_URL="http://129.226.214.22:9100"
PORTAINER_TOKEN="ptr_99YaZP1PKDwOKXQe69xY97A7v6vWxvW5nYknGULibdw="
CONTAINER_NAME="openim-server"
GITHUB_IMAGE="ghcr.io/rajeevkumarsh/open-im-server:develop_build-6341c0d"

echo "=== 测试 Portainer API 部署 ==="
echo "Portainer URL: $PORTAINER_URL"
echo "容器名称: $CONTAINER_NAME"
echo "测试镜像: $GITHUB_IMAGE"
echo "时间: $(date)"

# 1. 测试 API 连接
echo ""
echo "=== 测试 API 连接 ==="
if curl -s -f -H "X-API-Key: $PORTAINER_TOKEN" "$PORTAINER_URL/api/endpoints" >/dev/null; then
    echo "✅ Portainer API 连接成功"
else
    echo "❌ Portainer API 连接失败"
    exit 1
fi

# 2. 获取环境列表
echo ""
echo "=== 获取环境信息 ==="
ENVIRONMENTS=$(curl -s \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  "$PORTAINER_URL/api/endpoints")

echo "环境列表响应:"
echo "$ENVIRONMENTS" | jq '.'

ENDPOINT_ID=$(echo "$ENVIRONMENTS" | jq -r '.[0].Id')
echo "使用环境 ID: $ENDPOINT_ID"

if [ "$ENDPOINT_ID" = "null" ] || [ -z "$ENDPOINT_ID" ]; then
    echo "❌ 无法获取环境 ID"
    exit 1
fi

# 3. 查找现有容器
echo ""
echo "=== 查找现有容器 ==="
CONTAINERS=$(curl -s \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/json?all=true")

echo "容器列表（只显示名称）:"
echo "$CONTAINERS" | jq -r '.[].Names[]'

CONTAINER_ID=$(echo "$CONTAINERS" | jq -r ".[] | select(.Names[] | contains(\"$CONTAINER_NAME\")) | .Id")

if [ -n "$CONTAINER_ID" ] && [ "$CONTAINER_ID" != "null" ]; then
  echo "找到现有容器: $CONTAINER_ID"
  
  # 4. 停止并删除现有容器
  echo ""
  echo "=== 停止现有容器 ==="
  STOP_RESULT=$(curl -s -w "%{http_code}" -X POST \
    -H "X-API-Key: $PORTAINER_TOKEN" \
    "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/$CONTAINER_ID/stop")
  echo "停止容器结果: $STOP_RESULT"
  
  echo ""
  echo "=== 删除现有容器 ==="
  DELETE_RESULT=$(curl -s -w "%{http_code}" -X DELETE \
    -H "X-API-Key: $PORTAINER_TOKEN" \
    "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/$CONTAINER_ID")
  echo "删除容器结果: $DELETE_RESULT"
else
  echo "未找到现有容器，将创建新容器"
fi

# 5. 拉取新镜像
echo ""
echo "=== 拉取新镜像 ==="
# 修复镜像拉取的 API 调用方式
PULL_URL="$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/images/create?fromImage=$(echo "$GITHUB_IMAGE" | sed 's/:/%3A/g' | sed 's|/|%2F|g')"
echo "拉取 URL: $PULL_URL"

PULL_RESPONSE=$(curl -s -X POST \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  "$PULL_URL")
echo "拉取镜像响应: $PULL_RESPONSE"

# 等待镜像拉取完成
echo "等待镜像拉取完成..."
sleep 10

# 6. 创建新容器
echo ""
echo "=== 创建新容器 ==="
CREATE_PAYLOAD="{
  \"Image\": \"$GITHUB_IMAGE\",
  \"name\": \"$CONTAINER_NAME\",
  \"HostConfig\": {
    \"RestartPolicy\": {\"Name\": \"always\"},
    \"NetworkMode\": \"openim-docker_openim\",
    \"PortBindings\": {
      \"10001/tcp\": [{\"HostPort\": \"10001\"}],
      \"10002/tcp\": [{\"HostPort\": \"10002\"}]
    },
    \"Binds\": [
      \"/home/ubuntu/openim-docker/config:/openim/config:ro\",
      \"/home/ubuntu/openim-docker/_output/logs:/openim/logs\"
    ]
  },
  \"Env\": [
    \"TZ=Asia/Shanghai\",
    \"MONGO_URI=mongodb://openIM:openIM123@mongo:27017/openim_v3?maxPoolSize=100\",
    \"REDIS_ADDRESS=redis:6379\",
    \"REDIS_PASSWORD=openIM123\",
    \"KAFKA_ADDRESS=kafka:9092\",
    \"MINIO_ENDPOINT=http://minio:9000\",
    \"MINIO_ACCESS_KEY=root\",
    \"MINIO_SECRET_KEY=openIM123\",
    \"OPENIM_SECRET=openIM123\"
  ]
}"

echo "创建容器载荷:"
echo "$CREATE_PAYLOAD" | jq '.'

CREATE_RESPONSE=$(curl -s \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$CREATE_PAYLOAD" \
  "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/create")

echo "创建容器响应:"
echo "$CREATE_RESPONSE" | jq '.'

NEW_CONTAINER_ID=$(echo "$CREATE_RESPONSE" | jq -r '.Id')
echo "新容器 ID: $NEW_CONTAINER_ID"

if [ "$NEW_CONTAINER_ID" = "null" ] || [ -z "$NEW_CONTAINER_ID" ]; then
    echo "❌ 创建容器失败"
    echo "错误信息: $(echo "$CREATE_RESPONSE" | jq -r '.message // .error // "未知错误"')"
    exit 1
fi

# 7. 启动新容器
echo ""
echo "=== 启动新容器 ==="
START_RESULT=$(curl -s -w "%{http_code}" -X POST \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/$NEW_CONTAINER_ID/start")
echo "启动容器结果: $START_RESULT"

# 8. 验证容器状态
echo ""
echo "=== 验证容器状态 ==="
sleep 5

CONTAINER_STATUS=$(curl -s \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/$NEW_CONTAINER_ID/json")

CONTAINER_STATE=$(echo "$CONTAINER_STATUS" | jq -r '.State.Status')
echo "容器状态: $CONTAINER_STATE"

if [ "$CONTAINER_STATE" = "running" ]; then
    echo "✅ 容器启动成功"
    
    echo ""
    echo "=== 容器信息 ==="
    echo "$CONTAINER_STATUS" | jq '{
      Name: .Name,
      State: .State.Status,
      Image: .Config.Image,
      Ports: .NetworkSettings.Ports
    }'
    
else
    echo "❌ 容器启动失败"
    echo "容器日志:"
    curl -s \
      -H "X-API-Key: $PORTAINER_TOKEN" \
      "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/$NEW_CONTAINER_ID/logs?stdout=true&stderr=true&tail=50" \
      | sed 's/\x01\x00\x00\x00\x00\x00\x00\x/\n/g' | sed 's/\x02\x00\x00\x00\x00\x00\x00\x/\n/g'
fi

echo ""
echo "🎉 测试完成！"