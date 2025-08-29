#!/bin/bash

# 检查崩溃容器的日志

PORTAINER_URL="http://129.226.214.22:9100"
PORTAINER_TOKEN="ptr_99YaZP1PKDwOKXQe69xY97A7v6vWxvW5nYknGULibdw="
ENDPOINT_ID="3"

# 检查最新的 OpenIM 容器
CONTAINER_ID="c999966ee86f"

echo "=== 检查容器日志: $CONTAINER_ID ==="

# 1. 获取容器详细信息
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

echo ""
echo "=== 网络设置 ==="  
echo "$CONTAINER_INFO" | jq '.NetworkSettings.Networks'

echo ""
echo "=== 挂载点 ==="
echo "$CONTAINER_INFO" | jq '.Mounts'

echo ""
echo "=== 容器启动日志 ==="
curl -s \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/$CONTAINER_ID/logs?stdout=true&stderr=true&tail=100" \
  | sed 's/\x01\x00\x00\x00\x00\x00\x00./\n/g' | sed 's/\x02\x00\x00\x00\x00\x00\x00./\n/g'

echo ""
echo "=== 环境变量 ==="
echo "$CONTAINER_INFO" | jq '.Config.Env[]'