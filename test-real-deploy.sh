#!/bin/bash

# 基于真实文档的1Panel API部署测试

set -e

PANEL_URL="http://124.156.102.70:18238"
API_KEY="MdRXfn1dhUkQ3vMUUqILrDKECAELkoUD"
TIMESTAMP=$(date +%s)

# 生成1Panel Token
TOKEN_STRING="1panel${API_KEY}${TIMESTAMP}"
PANEL_TOKEN=$(echo -n "$TOKEN_STRING" | md5sum | cut -d' ' -f1)

# 测试配置
CONTAINER_NAME="openim-server-test"
TEST_IMAGE="ghcr.io/rajeevkumarsh/open-im-server:develop_build-67d22c8"

AUTH_HEADERS=(
  -H "1Panel-Token: $PANEL_TOKEN"
  -H "1Panel-Timestamp: $TIMESTAMP"
  -H "Content-Type: application/json"
)

echo "=== 基于真实文档的1Panel API测试 ==="
echo "Token: $PANEL_TOKEN"
echo ""

# 1. 停止现有容器 (如果存在)
echo "=== 停止现有容器 ==="
STOP_RESPONSE=$(curl -s -X POST "${AUTH_HEADERS[@]}" \
  -d "{
    \"names\": [\"$CONTAINER_NAME\"],
    \"operation\": \"stop\"
  }" \
  "$PANEL_URL/api/v2/containers/operate")
echo "停止结果: $STOP_RESPONSE"

# 2. 删除现有容器 (如果存在)
echo "=== 删除现有容器 ==="
REMOVE_RESPONSE=$(curl -s -X POST "${AUTH_HEADERS[@]}" \
  -d "{
    \"names\": [\"$CONTAINER_NAME\"],
    \"operation\": \"remove\"
  }" \
  "$PANEL_URL/api/v2/containers/operate")
echo "删除结果: $REMOVE_RESPONSE"

# 3. 拉取镜像
echo "=== 拉取镜像 ==="
PULL_RESPONSE=$(curl -s -X POST "${AUTH_HEADERS[@]}" \
  -d "{
    \"imageName\": \"$TEST_IMAGE\"
  }" \
  "$PANEL_URL/api/v2/containers/image/pull")
echo "拉取结果: $PULL_RESPONSE"

# 等待镜像拉取完成
sleep 10

# 4. 创建新容器
echo "=== 创建新容器 ==="
CREATE_RESPONSE=$(curl -s -X POST "${AUTH_HEADERS[@]}" \
  -d "{
    \"name\": \"$CONTAINER_NAME\",
    \"image\": \"$TEST_IMAGE\",
    \"restartPolicy\": \"always\",
    \"network\": \"openim-docker_openim\",
    \"exposedPorts\": [
      {\"hostPort\": \"20001\", \"containerPort\": \"10001\", \"protocol\": \"tcp\"},
      {\"hostPort\": \"20002\", \"containerPort\": \"10002\", \"protocol\": \"tcp\"}
    ],
    \"volumes\": [
      {\"sourceDir\": \"/home/ubuntu/openim-docker/config\", \"containerDir\": \"/openim/config\", \"mode\": \"ro\", \"type\": \"bind\"},
      {\"sourceDir\": \"/home/ubuntu/openim-docker/_output/logs\", \"containerDir\": \"/openim/logs\", \"mode\": \"rw\", \"type\": \"bind\"}
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

# 5. 启动容器
echo "=== 启动容器 ==="
START_RESPONSE=$(curl -s -X POST "${AUTH_HEADERS[@]}" \
  -d "{
    \"names\": [\"$CONTAINER_NAME\"],
    \"operation\": \"start\"
  }" \
  "$PANEL_URL/api/v2/containers/operate")
echo "启动结果: $START_RESPONSE"

echo ""
echo "测试完成！"
echo ""
echo "如果所有步骤都返回成功的JSON响应（而不是HTML），"
echo "说明API调用格式正确，可以提交到GitHub Actions。"