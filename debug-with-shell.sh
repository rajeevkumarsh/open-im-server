#!/bin/bash

# 用交互方式启动容器进行调试

PORTAINER_URL="http://129.226.214.22:9100"
PORTAINER_TOKEN="ptr_99YaZP1PKDwOKXQe69xY97A7v6vWxvW5nYknGULibdw="
ENDPOINT_ID="3"
GITHUB_IMAGE="ghcr.io/rajeevkumarsh/open-im-server:develop_build-aaa7999"

echo "=== 停止当前重启中的容器 ==="
# 停止所有相关容器
CONTAINERS=$(curl -s \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/json?all=true")

echo "$CONTAINERS" | jq -r '.[] | select(.Image | contains("rajeevkumarsh/open-im-server")) | .Id' | while read container_id; do
  echo "停止容器: $container_id"
  curl -s -X POST \
    -H "X-API-Key: $PORTAINER_TOKEN" \
    "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/$container_id/stop"
  
  echo "删除容器: $container_id"  
  curl -s -X DELETE \
    -H "X-API-Key: $PORTAINER_TOKEN" \
    "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/$container_id"
done

sleep 5

echo ""
echo "=== 创建调试容器 (交互式) ==="
CREATE_RESPONSE=$(curl -s -X POST \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"Image\": \"$GITHUB_IMAGE\",
    \"name\": \"openim-server-debug\",
    \"Cmd\": [\"sleep\", \"3600\"],
    \"Tty\": true,
    \"AttachStdin\": true,
    \"AttachStdout\": true,
    \"AttachStderr\": true,
    \"HostConfig\": {
      \"NetworkMode\": \"openim-docker_openim\",
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
  }" \
  "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/create")

CONTAINER_ID=$(echo "$CREATE_RESPONSE" | jq -r '.Id')
echo "创建调试容器: $CONTAINER_ID"

if [ "$CONTAINER_ID" != "null" ] && [ -n "$CONTAINER_ID" ]; then
  # 启动容器
  curl -s -X POST \
    -H "X-API-Key: $PORTAINER_TOKEN" \
    "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/$CONTAINER_ID/start"
  
  echo "容器已启动，进行调试..."
  sleep 3
  
  # 检查二进制文件
  echo ""
  echo "=== 检查二进制文件 ==="
  exec_id=$(curl -s -X POST \
    -H "X-API-Key: $PORTAINER_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "AttachStdout": true,
      "AttachStderr": true,
      "Cmd": ["ls", "-la", "/openim-server/_output/bin/"]
    }' \
    "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/$CONTAINER_ID/exec" | jq -r '.Id')
  
  # 启动执行
  curl -s -X POST \
    -H "X-API-Key: $PORTAINER_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"Detach": false, "Tty": false}' \
    "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/exec/$exec_id/start"
  
else
  echo "❌ 创建调试容器失败"
  echo "$CREATE_RESPONSE"
fi