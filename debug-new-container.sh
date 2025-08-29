#!/bin/bash

# 调试最新部署的容器

PORTAINER_URL="https://docker.guguim.app"
PORTAINER_TOKEN="ptr_oVGV9nWLRCFDf2I3OTOSu+AqC7oZwgvbvQd7OD+8VpQ="
CONTAINER_NAME="openim-server"

echo "=== 调试最新 OpenIM Server 容器 ==="
echo "时间: $(date)"
echo "Portainer URL: $PORTAINER_URL"

# 1. 获取环境列表
echo ""
echo "=== 获取环境信息 ==="
ENVIRONMENTS=$(curl -s \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  "$PORTAINER_URL/api/endpoints")

if [ $? -ne 0 ] || [ -z "$ENVIRONMENTS" ]; then
  echo "❌ 无法连接到 Portainer API"
  exit 1
fi

ENDPOINT_ID=$(echo "$ENVIRONMENTS" | jq -r '.[0].Id')
echo "使用环境 ID: $ENDPOINT_ID"

# 2. 查找容器
echo ""
echo "=== 查找 openim-server 容器 ==="
CONTAINERS=$(curl -s \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/json?all=true")

CONTAINER_ID=$(echo "$CONTAINERS" | jq -r ".[] | select(.Names[] | contains(\"$CONTAINER_NAME\")) | .Id")

if [ -n "$CONTAINER_ID" ] && [ "$CONTAINER_ID" != "null" ]; then
  echo "找到容器: $CONTAINER_ID"
  
  # 3. 获取容器详细信息
  echo ""
  echo "=== 容器详细信息 ==="
  CONTAINER_INFO=$(curl -s \
    -H "X-API-Key: $PORTAINER_TOKEN" \
    "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/$CONTAINER_ID/json")
  
  echo "容器状态:"
  echo "$CONTAINER_INFO" | jq '{
    Name: .Name,
    State: .State.Status,
    Image: .Config.Image,
    RestartCount: .RestartCount,
    ExitCode: .State.ExitCode,
    Error: .State.Error,
    StartedAt: .State.StartedAt,
    FinishedAt: .State.FinishedAt
  }'
  
  echo ""
  echo "=== 端口绑定 ==="
  echo "$CONTAINER_INFO" | jq '.NetworkSettings.Ports'
  
  # 4. 获取容器日志
  echo ""
  echo "=== 容器日志 (最近50行) ==="
  curl -s \
    -H "X-API-Key: $PORTAINER_TOKEN" \
    "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/$CONTAINER_ID/logs?stdout=true&stderr=true&tail=50" \
    | sed 's/\x01\x00\x00\x00\x00\x00\x00./\n/g' | sed 's/\x02\x00\x00\x00\x00\x00\x00./\n/g' | tail -30
  
  echo ""
  echo "=== 环境变量检查 ==="
  echo "$CONTAINER_INFO" | jq '.Config.Env[]' | grep -E "(MONGO|REDIS|KAFKA|MINIO)" || echo "未找到相关环境变量"
  
else
  echo "❌ 未找到容器: $CONTAINER_NAME"
  echo "现有容器列表:"
  echo "$CONTAINERS" | jq -r '.[].Names[]'
fi

# 5. 测试健康检查端点
echo ""
echo "=== 测试健康检查端点 ==="
echo "测试端点: https://docker.guguim.app:10002/api/get_server_api_map"
if curl -v -f --connect-timeout 5 --max-time 10 "https://docker.guguim.app:10002/api/get_server_api_map" 2>&1; then
  echo "✅ 健康检查端点响应正常"
else
  echo "❌ 健康检查端点无响应"
fi

echo ""
echo "测试端口 10001: https://docker.guguim.app:10001"
if curl -v --connect-timeout 5 --max-time 10 "https://docker.guguim.app:10001" 2>&1; then
  echo "✅ 端口 10001 响应正常"  
else
  echo "❌ 端口 10001 无响应"
fi

echo ""
echo "=== 调试完成 ==="