#!/bin/bash

# 检查新容器的日志

PORTAINER_URL="https://docker.guguim.app"
PORTAINER_TOKEN="ptr_oVGV9nWLRCFDf2I3OTOSu+AqC7oZwgvbvQd7OD+8VpQ="
ENDPOINT_ID="3"
CONTAINER_ID="d627f0c899ae"  # wonderful_bassi

echo "=== 检查容器日志: $CONTAINER_ID (wonderful_bassi) ==="

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
echo "=== 容器最新日志 ==="
curl -s \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/$CONTAINER_ID/logs?stdout=true&stderr=true&tail=100" \
  | sed 's/\x01\x00\x00\x00\x00\x00\x00./\n/g' | sed 's/\x02\x00\x00\x00\x00\x00\x00./\n/g'

echo ""
echo "=== 网络和端口配置 ==="
echo "$CONTAINER_INFO" | jq '{
  Ports: .NetworkSettings.Ports,
  Networks: .NetworkSettings.Networks
}'