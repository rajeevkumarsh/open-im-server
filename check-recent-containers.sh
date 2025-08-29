#!/bin/bash

# 检查最近创建的容器

PORTAINER_URL="http://129.226.214.22:9100"
PORTAINER_TOKEN="ptr_99YaZP1PKDwOKXQe69xY97A7v6vWxvW5nYknGULibdw="
ENDPOINT_ID="3"

echo "=== 检查所有容器（包括已停止的） ==="

CONTAINERS=$(curl -s \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/json?all=true")

echo "所有容器信息:"
echo "$CONTAINERS" | jq '.[] | {
  Id: .Id[:12],
  Names: .Names,
  Image: .Image,
  State: .State,
  Status: .Status,
  Created: .Created
}' | head -50

echo ""
echo "=== 查找包含 openim 的容器 ==="
echo "$CONTAINERS" | jq '.[] | select(.Names[] | contains("openim") or .Image | contains("openim")) | {
  Id: .Id[:12],
  Names: .Names,
  Image: .Image,
  State: .State,
  Status: .Status
}'

echo ""
echo "=== 查找最近创建的容器 (按创建时间排序) ==="
echo "$CONTAINERS" | jq 'sort_by(.Created) | reverse | .[0:5] | .[] | {
  Id: .Id[:12],
  Names: .Names,
  Image: .Image,
  State: .State,
  Status: .Status,
  Created: .Created
}'