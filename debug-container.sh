#!/bin/bash

# 调试容器部署问题

set -e

PORTAINER_URL="http://129.226.214.22:9100"
PORTAINER_TOKEN="ptr_99YaZP1PKDwOKXQe69xY97A7v6vWxvW5nYknGULibdw="
CONTAINER_NAME="openim-server"
ENDPOINT_ID="3"

echo "=== 调试 OpenIM Server 容器 ==="
echo "时间: $(date)"

# 1. 查找容器
echo ""
echo "=== 查找容器 ==="
CONTAINERS=$(curl -s \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/json?all=true")

CONTAINER_ID=$(echo "$CONTAINERS" | jq -r ".[] | select(.Names[] | contains(\"$CONTAINER_NAME\")) | .Id")

if [ -n "$CONTAINER_ID" ] && [ "$CONTAINER_ID" != "null" ]; then
  echo "找到容器: $CONTAINER_ID"
  
  # 2. 获取容器详细信息
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
    Ports: .NetworkSettings.Ports,
    ExitCode: .State.ExitCode,
    Error: .State.Error,
    StartedAt: .State.StartedAt,
    FinishedAt: .State.FinishedAt
  }'
  
  # 3. 获取容器日志
  echo ""
  echo "=== 容器日志 (最近100行) ==="
  curl -s \
    -H "X-API-Key: $PORTAINER_TOKEN" \
    "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/$CONTAINER_ID/logs?stdout=true&stderr=true&tail=100" \
    | sed 's/\x01\x00\x00\x00\x00\x00\x00./\n/g' | sed 's/\x02\x00\x00\x00\x00\x00\x00./\n/g' | tail -50
  
  # 4. 检查网络连接
  echo ""
  echo "=== 网络信息 ==="
  echo "$CONTAINER_INFO" | jq '.NetworkSettings.Networks'
  
  # 5. 检查环境变量
  echo ""
  echo "=== 环境变量 ==="
  echo "$CONTAINER_INFO" | jq '.Config.Env[]' | grep -E "(MONGO|REDIS|KAFKA|MINIO)" || echo "未找到相关环境变量"
  
else
  echo "❌ 未找到容器: $CONTAINER_NAME"
  echo "现有容器列表:"
  echo "$CONTAINERS" | jq -r '.[].Names[]'
fi

# 6. 测试健康检查端点
echo ""
echo "=== 测试健康检查端点 ==="
echo "测试 http://129.226.214.22:10002/api/get_server_api_map"
if curl -v -f --connect-timeout 5 --max-time 10 "http://129.226.214.22:10002/api/get_server_api_map" 2>&1; then
  echo "✅ 健康检查端点响应正常"
else
  echo "❌ 健康检查端点无响应"
fi

echo ""
echo "测试 http://129.226.214.22:10001"
if curl -v --connect-timeout 5 --max-time 10 "http://129.226.214.22:10001" 2>&1; then
  echo "✅ 端口 10001 响应正常"  
else
  echo "❌ 端口 10001 无响应"
fi

echo ""
echo "=== 调试完成 ==="