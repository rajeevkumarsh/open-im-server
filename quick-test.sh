#!/bin/bash

# 快速测试镜像拉取

PORTAINER_URL="http://129.226.214.22:9100"
PORTAINER_TOKEN="ptr_99YaZP1PKDwOKXQe69xY97A7v6vWxvW5nYknGULibdw="
ENDPOINT_ID="3"
GITHUB_IMAGE="ghcr.io/rajeevkumarsh/open-im-server:develop_build-6341c0d"

echo "测试镜像拉取..."
echo "镜像: $GITHUB_IMAGE"

# 测试镜像拉取
PULL_URL="$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/images/create?fromImage=$(echo "$GITHUB_IMAGE" | sed 's/:/%3A/g' | sed 's|/|%2F|g')"
echo "拉取 URL: $PULL_URL"

PULL_RESPONSE=$(curl -s -X POST \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  "$PULL_URL")

echo "拉取响应: $PULL_RESPONSE"

# 检查镜像是否存在
echo ""
echo "检查镜像列表..."
IMAGES=$(curl -s \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/images/json")

echo "查找镜像: $GITHUB_IMAGE"
IMAGE_FOUND=$(echo "$IMAGES" | jq -r ".[] | select(.RepoTags[]? | contains(\"rajeevkumarsh/open-im-server\")) | .RepoTags[]")

if [ -n "$IMAGE_FOUND" ]; then
  echo "✅ 找到镜像:"
  echo "$IMAGE_FOUND"
else
  echo "❌ 未找到镜像"
fi