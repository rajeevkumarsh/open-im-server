#!/bin/bash

# 测试具体的容器管理API

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

echo "=== 测试1Panel容器管理API ==="
echo "Token: $PANEL_TOKEN"
echo ""

# 1. 测试容器操作API
echo "1. 测试容器操作API (/containers/operate):"
curl -s -w "HTTP状态码: %{http_code}\n" "${AUTH_HEADERS[@]}" \
  "$PANEL_URL/api/v2/containers/operate" | head -5

echo ""

# 2. 测试容器创建API  
echo "2. 测试容器创建API (/containers):"
curl -s -w "HTTP状态码: %{http_code}\n" "${AUTH_HEADERS[@]}" \
  "$PANEL_URL/api/v2/containers" | head -5

echo ""

# 3. 测试镜像拉取API
echo "3. 测试镜像API (/containers/image/pull):"
curl -s -w "HTTP状态码: %{http_code}\n" "${AUTH_HEADERS[@]}" \
  "$PANEL_URL/api/v2/containers/image/pull" | head -5

echo ""

# 4. 测试镜像列表
echo "4. 测试镜像列表 (/containers/image):"
curl -s -w "HTTP状态码: %{http_code}\n" "${AUTH_HEADERS[@]}" \
  "$PANEL_URL/api/v2/containers/image" | head -5

echo ""

# 5. 用GET方法测试容器列表
echo "5. 用GET测试容器搜索 (/containers/search):"
curl -s -w "HTTP状态码: %{http_code}\n" -X GET "${AUTH_HEADERS[@]}" \
  "$PANEL_URL/api/v2/containers/search" | head -10

echo ""
echo "测试完成！"