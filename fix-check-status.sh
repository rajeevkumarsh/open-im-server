#!/bin/bash

# 使用正确的API端点检查容器状态

PANEL_URL="http://124.156.102.70:18238"
API_KEY="MdRXfn1dhUkQ3vMUUqILrDKECAELkoUD"
TIMESTAMP=$(date +%s)

# 生成1Panel Token
TOKEN_STRING="1panel${API_KEY}${TIMESTAMP}"
PANEL_TOKEN=$(echo -n "$TOKEN_STRING" | md5sum | cut -d' ' -f1)

AUTH_HEADERS=(
  -H "1Panel-Token: $PANEL_TOKEN"
  -H "1Panel-Timestamp: $TIMESTAMP"
  -H "Content-Type: application/json"
)

echo "=== 使用正确API检查容器状态 ==="
echo "Token: $PANEL_TOKEN"
echo ""

# 1. 测试容器搜索API (这个在我们测试脚本中是可用的)
echo "1. 容器搜索:"
curl -s -X GET "${AUTH_HEADERS[@]}" "$PANEL_URL/api/v2/containers/search" | head -20

echo -e "\n\n2. 尝试获取容器统计:"
curl -s "${AUTH_HEADERS[@]}" "$PANEL_URL/api/v2/containers" | head -10

# 3. 检查Docker状态
echo -e "\n\n3. Docker服务状态:"
curl -s "${AUTH_HEADERS[@]}" "$PANEL_URL/api/v2/containers/docker/status"

# 4. 重新尝试创建容器（调试用）
echo -e "\n\n4. 重新创建openim-server容器:"
CREATE_RESPONSE=$(curl -s -X POST "${AUTH_HEADERS[@]}" \
  -d '{
    "name": "openim-server",
    "image": "ghcr.io/rajeevkumarsh/open-im-server:develop_build-1c568ea",
    "restartPolicy": "always",
    "network": "openim-docker_openim",
    "exposedPorts": [
      {"hostPort": "10001", "containerPort": "10001", "protocol": "tcp"},
      {"hostPort": "10002", "containerPort": "10002", "protocol": "tcp"}
    ],
    "volumes": [
      {"sourceDir": "/home/ubuntu/openim-docker/config", "containerDir": "/openim/config", "mode": "ro", "type": "bind"},
      {"sourceDir": "/home/ubuntu/openim-docker/_output/logs", "containerDir": "/openim/logs", "mode": "rw", "type": "bind"}
    ],
    "env": [
      "TZ=Asia/Shanghai",
      "MONGO_URI=mongodb://openIM:openIM123@mongo:27017/openim_v3?maxPoolSize=100",
      "REDIS_ADDRESS=redis:6379",
      "REDIS_PASSWORD=openIM123",
      "KAFKA_ADDRESS=kafka:9092",
      "MINIO_ENDPOINT=http://minio:9000",
      "MINIO_ACCESS_KEY=root",
      "MINIO_SECRET_KEY=openIM123",
      "OPENIM_SECRET=openIM123"
    ]
  }' \
  "$PANEL_URL/api/v2/containers")

echo "创建结果: $CREATE_RESPONSE"

# 5. 启动容器
echo -e "\n5. 启动容器:"
START_RESPONSE=$(curl -s -X POST "${AUTH_HEADERS[@]}" \
  -d '{
    "names": ["openim-server"],
    "operation": "start"
  }' \
  "$PANEL_URL/api/v2/containers/operate")

echo "启动结果: $START_RESPONSE"

echo -e "\n6. 等待容器启动..."
sleep 10

# 7. 再次测试端口
echo -e "\n7. 测试端口可达性:"
curl -X POST --connect-timeout 3 --max-time 5 "http://api.guguim.app/msg/get_server_time" 2>&1 | grep -q "errCode" && echo "✅ 健康检查端点可用" || echo "❌ 健康检查端点不可用"