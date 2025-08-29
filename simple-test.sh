#!/bin/bash

# 简化的1Panel API测试

PANEL_URL="http://124.156.102.70:18238"
API_KEY="MdRXfn1dhUkQ3vMUUqILrDKECAELkoUD"
TIMESTAMP=$(date +%s)

# 生成1Panel Token
TOKEN_STRING="1panel${API_KEY}${TIMESTAMP}"
PANEL_TOKEN=$(echo -n "$TOKEN_STRING" | md5sum | cut -d' ' -f1)

echo "=== 1Panel API 基础测试 ==="
echo "时间戳: $TIMESTAMP"
echo "Token字符串: $TOKEN_STRING"
echo "生成Token: $PANEL_TOKEN"
echo ""

# 测试几个不同的API端点
echo "=== 测试容器列表API ==="
curl -s -w "HTTP状态码: %{http_code}\n" \
  -H "1Panel-Token: $PANEL_TOKEN" \
  -H "1Panel-Timestamp: $TIMESTAMP" \
  -H "Content-Type: application/json" \
  "$PANEL_URL/api/v2/containers/list" | head -10

echo ""
echo "=== 测试Docker状态API ==="
curl -s -w "HTTP状态码: %{http_code}\n" \
  -H "1Panel-Token: $PANEL_TOKEN" \
  -H "1Panel-Timestamp: $TIMESTAMP" \
  -H "Content-Type: application/json" \
  "$PANEL_URL/api/v2/containers/docker/status" | head -10

echo ""
echo "=== 测试仪表板API ==="
curl -s -w "HTTP状态码: %{http_code}\n" \
  -H "1Panel-Token: $PANEL_TOKEN" \
  -H "1Panel-Timestamp: $TIMESTAMP" \
  -H "Content-Type: application/json" \
  "$PANEL_URL/api/v2/dashboard/current" | head -10

echo ""
echo "测试完成！"