#!/bin/bash

# 检查最近的部署情况

PORTAINER_URL="https://docker.guguim.app"
PORTAINER_TOKEN="ptr_oVGV9nWLRCFDf2I3OTOSu+AqC7oZwgvbvQd7OD+8VpQ="
ENDPOINT_ID="3"

echo "=== 检查所有容器（包括已停止的） ==="

CONTAINERS=$(curl -s \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/json?all=true")

echo "所有容器信息 (按创建时间排序):"
echo "$CONTAINERS" | jq 'sort_by(.Created) | reverse | .[0:10] | .[] | {
  Id: .Id[:12],
  Names: .Names,
  Image: .Image,
  State: .State,
  Status: .Status,
  Created: .Created
}'

echo ""
echo "=== 查找包含 openim 或 rajeevkumarsh 的容器 ==="
echo "$CONTAINERS" | jq '.[] | select(.Names[] | contains("openim") or .Image | contains("rajeevkumarsh")) | {
  Id: .Id[:12],
  Names: .Names,
  Image: .Image,
  State: .State,
  Status: .Status
}'

echo ""
echo "=== 检查镜像列表 ==="
IMAGES=$(curl -s \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/images/json")

echo "包含 rajeevkumarsh 的镜像:"
echo "$IMAGES" | jq '.[] | select(.RepoTags[]? | contains("rajeevkumarsh")) | {
  RepoTags: .RepoTags,
  Created: .Created,
  Size: .Size
}'