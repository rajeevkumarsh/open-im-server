#!/bin/bash

# 快速检查1Panel中的容器状态

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

echo "=== 检查容器状态 ==="

# 1. 列出所有容器
echo "1. 容器列表:"
curl -s "${AUTH_HEADERS[@]}" "$PANEL_URL/api/v2/containers/list" | \
  jq '.items[] | select(.name | contains("openim")) | {name, state, status, ports}' 2>/dev/null || \
  curl -s "${AUTH_HEADERS[@]}" "$PANEL_URL/api/v2/containers/list"

echo -e "\n2. openim-server容器详情:"
curl -s "${AUTH_HEADERS[@]}" "$PANEL_URL/api/v2/containers/list" | \
  jq '.items[] | select(.name == "openim-server")' 2>/dev/null || \
  echo "未找到openim-server容器"

# 3. 检查容器日志
echo -e "\n3. 容器日志 (最后50行):"
curl -s -X POST "${AUTH_HEADERS[@]}" \
  -d '{"containerID": "openim-server", "mode": "tail", "number": 50}' \
  "$PANEL_URL/api/v2/containers/search/log" | \
  jq -r '.content // empty' 2>/dev/null || \
  echo "无法获取日志"

# 4. 直接测试端口
echo -e "\n4. 端口连通性测试:"
echo "测试 10001 端口:"
curl -f --connect-timeout 5 --max-time 10 "http://124.156.102.70:10001" 2>&1 || echo "端口不可达"

echo "测试 10002 端口:"
curl -f --connect-timeout 5 --max-time 10 "http://124.156.102.70:10002" 2>&1 || echo "端口不可达"

echo "测试健康检查端点:"
curl -X POST --connect-timeout 5 --max-time 10 "http://api.guguim.app/msg/get_server_time" 2>&1 | grep -q "errCode" && echo "✅ 健康检查端点可用" || echo "❌ 健康检查端点不可用"