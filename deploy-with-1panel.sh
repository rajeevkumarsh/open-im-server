#!/bin/bash

# 使用1Panel API进行OpenIM Server部署

set -e

# 1Panel配置
PANEL_URL="http://124.156.102.70:18238"
API_KEY="your-api-key-here"  # 需要在1Panel中生成API密钥
TIMESTAMP=$(date +%s)

# 容器配置
CONTAINER_NAME="openim-server"
GITHUB_IMAGE="ghcr.io/rajeevkumarsh/open-im-server:develop_build-67d22c8"
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1410921882714116227/M4NJjctluETrJk5JnWwW8U0uWCcgO_MYSCy-w8QefRI56zmMkY3Ii5C47MegO4A_1Vjm"

# 认证头
AUTH_HEADERS=(
  -H "X-API-Key: $API_KEY"
  -H "Timestamp: $TIMESTAMP"
  -H "Content-Type: application/json"
)

echo "=== 使用1Panel API部署OpenIM Server ==="
echo "面板地址: $PANEL_URL"
echo "容器名称: $CONTAINER_NAME"
echo "镜像: $GITHUB_IMAGE"

# 1. 停止并删除现有容器
echo ""
echo "=== 停止现有容器 ==="
curl -s -X POST "${AUTH_HEADERS[@]}" \
  -d "{
    \"names\": [\"$CONTAINER_NAME\"],
    \"operation\": \"stop\"
  }" \
  "$PANEL_URL/api/v2/containers/operate" || echo "容器可能不存在或已停止"

echo ""
echo "=== 删除现有容器 ==="
curl -s -X POST "${AUTH_HEADERS[@]}" \
  -d "{
    \"names\": [\"$CONTAINER_NAME\"],
    \"operation\": \"remove\"
  }" \
  "$PANEL_URL/api/v2/containers/operate" || echo "容器可能不存在"

# 2. 拉取新镜像
echo ""
echo "=== 拉取镜像 ==="
PULL_RESPONSE=$(curl -s -X POST "${AUTH_HEADERS[@]}" \
  -d "{
    \"imageName\": \"$GITHUB_IMAGE\"
  }" \
  "$PANEL_URL/api/v2/containers/image/pull")
echo "拉取结果: $PULL_RESPONSE"

# 等待镜像拉取完成
sleep 10

# 3. 创建新容器
echo ""
echo "=== 创建新容器 ==="
CREATE_RESPONSE=$(curl -s -X POST "${AUTH_HEADERS[@]}" \
  -d "{
    \"name\": \"$CONTAINER_NAME\",
    \"image\": \"$GITHUB_IMAGE\",
    \"restart\": \"always\",
    \"networkMode\": \"openim-docker_openim\",
    \"portBindings\": [
      {\"hostPort\": \"10001\", \"containerPort\": \"10001\"},
      {\"hostPort\": \"10002\", \"containerPort\": \"10002\"}
    ],
    \"volumes\": [
      {\\"host\": \"/home/ubuntu/openim-docker/config\", \"container\": \"/openim/config\", \"mode\": \"ro\"},
      {\"host\": \"/home/ubuntu/openim-docker/_output/logs\", \"container\": \"/openim/logs\"}
    ],
    \"env\": [
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
  }" \
  "$PANEL_URL/api/v2/containers")

echo "创建结果: $CREATE_RESPONSE"

# 4. 启动容器
echo ""
echo "=== 启动容器 ==="
curl -s -X POST "${AUTH_HEADERS[@]}" \
  -d "{
    \"names\": [\"$CONTAINER_NAME\"],
    \"operation\": \"start\"
  }" \
  "$PANEL_URL/api/v2/containers/operate"

# 5. 等待容器启动
echo ""
echo "=== 等待容器启动 ==="
sleep 15

# 6. 健康检查
echo ""
echo "=== 健康检查 ==="
for i in {1..30}; do
  if curl -f "https://docker.guguim.app:10002/api/get_server_api_map" &>/dev/null; then
    echo "✅ OpenIM Server 启动成功"
    
    # 发送部署成功通知到 Discord
    curl -X POST "$DISCORD_WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d "{
        \"embeds\": [{
          \"title\": \"🎉 OpenIM Server - 部署成功 (1Panel API)\",
          \"description\": \"通过1Panel API部署完成，服务正常运行\",
          \"color\": 3066993,
          \"fields\": [
            {\"name\": \"容器名称\", \"value\": \"$CONTAINER_NAME\", \"inline\": true},
            {\"name\": \"镜像版本\", \"value\": \"$GITHUB_IMAGE\", \"inline\": false},
            {\"name\": \"部署方式\", \"value\": \"1Panel API\", \"inline\": true}
          ]
        }]
      }" &>/dev/null || echo "⚠️ Discord 通知发送失败"
    
    exit 0
  fi
  
  if [ $i -eq 30 ]; then
    echo "❌ 健康检查失败"
    
    # 发送部署失败通知到 Discord
    curl -X POST "$DISCORD_WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d "{
        \"embeds\": [{
          \"title\": \"❌ OpenIM Server - 部署失败 (1Panel API)\",
          \"description\": \"健康检查超时，服务启动失败\",
          \"color\": 15158332,
          \"fields\": [
            {\"name\": \"容器名称\", \"value\": \"$CONTAINER_NAME\", \"inline\": true},
            {\"name\": \"镜像\", \"value\": \"$GITHUB_IMAGE\", \"inline\": false}
          ]
        }]
      }" &>/dev/null || echo "⚠️ Discord 通知发送失败"
    
    exit 1
  fi
  
  echo "等待服务启动... ($i/30)"
  sleep 2
done