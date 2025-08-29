#!/bin/bash

# 测试1Panel API认证

PANEL_URL="http://124.156.102.70:18238"
API_KEY="MdRXfn1dhUkQ3vMUUqILrDKECAELkoUD"

echo "=== 测试不同的认证方式 ==="

# 方法1: 只使用API Key
echo "1. 只使用 X-API-Key:"
curl -s -w "HTTP状态码: %{http_code}\n" \
  -H "X-API-Key: $API_KEY" \
  "$PANEL_URL/api/v2/containers/list" | head -5

echo ""

# 方法2: API Key + 简单时间戳
TIMESTAMP=$(date +%s)
echo "2. X-API-Key + Timestamp ($TIMESTAMP):"
curl -s -w "HTTP状态码: %{http_code}\n" \
  -H "X-API-Key: $API_KEY" \
  -H "Timestamp: $TIMESTAMP" \
  "$PANEL_URL/api/v2/containers/list" | head -5

echo ""

# 方法3: API Key + Authorization头
echo "3. Authorization Bearer:"
curl -s -w "HTTP状态码: %{http_code}\n" \
  -H "Authorization: Bearer $API_KEY" \
  "$PANEL_URL/api/v2/containers/list" | head -5

echo ""

# 方法4: 直接访问面板主页测试连接
echo "4. 测试面板连接:"
curl -s -w "HTTP状态码: %{http_code}\n" \
  "$PANEL_URL/" | head -3

echo ""

# 方法5: 尝试其他可能的API路径
echo "5. 测试 /api 路径:"
curl -s -w "HTTP状态码: %{http_code}\n" \
  -H "X-API-Key: $API_KEY" \
  "$PANEL_URL/api" | head -5

echo ""

echo "6. 测试API版本信息:"
curl -s -w "HTTP状态码: %{http_code}\n" \
  -H "X-API-Key: $API_KEY" \
  "$PANEL_URL/api/v2" | head -5

echo ""

# 方法7: 检查是否需要CSRF或其他头
echo "7. 添加常见头部:"
curl -s -w "HTTP状态码: %{http_code}\n" \
  -H "X-API-Key: $API_KEY" \
  -H "Timestamp: $(date +%s)" \
  -H "Content-Type: application/json" \
  -H "User-Agent: Mozilla/5.0" \
  -H "Accept: application/json" \
  "$PANEL_URL/api/v2/containers/list" | head -5