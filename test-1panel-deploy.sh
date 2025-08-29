#!/bin/bash

# 本地测试1Panel API容器部署

set -e

# 1Panel配置
PANEL_URL="http://124.156.102.70:18238"
API_KEY="MdRXfn1dhUkQ3vMUUqILrDKECAELkoUD"
TIMESTAMP=$(date +%s)

# 生成1Panel Token
# Token = md5('1panel' + API-Key + UnixTimestamp)
TOKEN_STRING="1panel${API_KEY}${TIMESTAMP}"
PANEL_TOKEN=$(echo -n "$TOKEN_STRING" | md5sum | cut -d' ' -f1)

# 测试容器配置
CONTAINER_NAME="openim-server-test"
TEST_IMAGE="ghcr.io/rajeevkumarsh/open-im-server:develop_build-67d22c8"

# 认证头（使用1Panel格式）
AUTH_HEADERS=(
  -H "1Panel-Token: $PANEL_TOKEN"
  -H "1Panel-Timestamp: $TIMESTAMP"
  -H "Content-Type: application/json"
)

echo "=== 本地测试1Panel API部署 ==="
echo "面板地址: $PANEL_URL"
echo "容器名称: $CONTAINER_NAME"
echo "测试镜像: $TEST_IMAGE"
echo "时间戳: $TIMESTAMP"
echo "Token字符串: $TOKEN_STRING"
echo "生成的Token: $PANEL_TOKEN"
echo ""

# 1. 测试API连接
echo "=== 测试API连接 ==="
API_TEST=$(curl -s -w "%{http_code}" "${AUTH_HEADERS[@]}" \
  "$PANEL_URL/api/v2/containers/list" -o /tmp/api_test.json)

if [ "$API_TEST" = "200" ]; then
    echo "✅ 1Panel API连接成功"
else
    echo "❌ 1Panel API连接失败，HTTP状态码: $API_TEST"
    echo "响应内容:"
    cat /tmp/api_test.json 2>/dev/null || echo "无响应内容"
    exit 1
fi

# 2. 停止现有测试容器（如果存在）
echo ""
echo "=== 停止现有测试容器 ==="
STOP_RESULT=$(curl -s -w "%{http_code}" -X POST "${AUTH_HEADERS[@]}" \
  -d "{
    \"names\": [\"$CONTAINER_NAME\"],
    \"operation\": \"stop\"
  }" \
  "$PANEL_URL/api/v2/containers/operate" -o /tmp/stop_result.json)

echo "停止容器结果 (HTTP $STOP_RESULT):"
cat /tmp/stop_result.json && echo ""

# 3. 删除现有测试容器（如果存在）
echo "=== 删除现有测试容器 ==="
REMOVE_RESULT=$(curl -s -w "%{http_code}" -X POST "${AUTH_HEADERS[@]}" \
  -d "{
    \"names\": [\"$CONTAINER_NAME\"],
    \"operation\": \"remove\"
  }" \
  "$PANEL_URL/api/v2/containers/operate" -o /tmp/remove_result.json)

echo "删除容器结果 (HTTP $REMOVE_RESULT):"
cat /tmp/remove_result.json && echo ""

# 4. 拉取镜像
echo "=== 拉取镜像 ==="
PULL_RESULT=$(curl -s -w "%{http_code}" -X POST "${AUTH_HEADERS[@]}" \
  -d "{
    \"imageName\": \"$TEST_IMAGE\"
  }" \
  "$PANEL_URL/api/v2/containers/image/pull" -o /tmp/pull_result.json)

echo "拉取镜像结果 (HTTP $PULL_RESULT):"
cat /tmp/pull_result.json && echo ""

if [ "$PULL_RESULT" != "200" ]; then
    echo "❌ 镜像拉取失败"
    exit 1
fi

# 等待镜像拉取完成
echo "等待镜像拉取完成..."
sleep 15

# 5. 创建新容器
echo "=== 创建新容器 ==="
CREATE_PAYLOAD="{
  \"name\": \"$CONTAINER_NAME\",
  \"image\": \"$TEST_IMAGE\",
  \"restartPolicy\": \"always\",
  \"network\": \"openim-docker_openim\",
  \"exposedPorts\": [
    {\"hostPort\": \"20001\", \"containerPort\": \"10001\", \"protocol\": \"tcp\"},
    {\"hostPort\": \"20002\", \"containerPort\": \"10002\", \"protocol\": \"tcp\"}
  ],
  \"volumes\": [
    {\"sourceDir\": \"/home/ubuntu/openim-docker/config\", \"containerDir\": \"/openim/config\", \"mode\": \"ro\", \"type\": \"bind\"},
    {\"sourceDir\": \"/home/ubuntu/openim-docker/_output/logs\", \"containerDir\": \"/openim/logs\", \"mode\": \"rw\", \"type\": \"bind\"}
  ],
  \"env\": [
    \"TZ=Asia/Shanghai\",
    \"MONGO_URI=mongodb://openIM:openIM123@mongo:27017/openim_v3?maxPoolSize=100\",
    \"REDIS_ADDRESS=redis:6379\",
    \"REDIS_PASSWORD=openIM123\",
    \"KAFKA_ADDRESS=kafka:9092\",
    \"MINIO_ENDPOINT=http://minio:9000\",
    \"MINIO_ACCESS_KEY=root\",
    \"MINIO_SECRET_KEY=openIM123\",
    \"OPENIM_SECRET=openIM123\"
  ]
}"

echo "创建容器载荷:"
echo "$CREATE_PAYLOAD" | jq '.' 2>/dev/null || echo "$CREATE_PAYLOAD"

CREATE_RESULT=$(curl -s -w "%{http_code}" -X POST "${AUTH_HEADERS[@]}" \
  -d "$CREATE_PAYLOAD" \
  "$PANEL_URL/api/v2/containers" -o /tmp/create_result.json)

echo ""
echo "创建容器结果 (HTTP $CREATE_RESULT):"
cat /tmp/create_result.json && echo ""

if [ "$CREATE_RESULT" != "200" ]; then
    echo "❌ 容器创建失败"
    exit 1
fi

# 6. 启动容器
echo "=== 启动容器 ==="
START_RESULT=$(curl -s -w "%{http_code}" -X POST "${AUTH_HEADERS[@]}" \
  -d "{
    \"names\": [\"$CONTAINER_NAME\"],
    \"operation\": \"start\"
  }" \
  "$PANEL_URL/api/v2/containers/operate" -o /tmp/start_result.json)

echo "启动容器结果 (HTTP $START_RESULT):"
cat /tmp/start_result.json && echo ""

if [ "$START_RESULT" != "200" ]; then
    echo "❌ 容器启动失败"
    exit 1
fi

# 7. 等待容器启动
echo "=== 等待容器启动 ==="
sleep 10

# 8. 检查容器状态
echo "=== 检查容器状态 ==="
STATUS_RESULT=$(curl -s -w "%{http_code}" "${AUTH_HEADERS[@]}" \
  "$PANEL_URL/api/v2/containers/list" -o /tmp/status_result.json)

echo "容器列表 (HTTP $STATUS_RESULT):"
if [ "$STATUS_RESULT" = "200" ]; then
    cat /tmp/status_result.json | jq ".items[] | select(.name == \"$CONTAINER_NAME\") | {name, state, status, ports}" 2>/dev/null || \
    cat /tmp/status_result.json | grep -A 5 -B 5 "$CONTAINER_NAME" || \
    echo "未找到容器信息"
else
    cat /tmp/status_result.json
fi

# 9. 简单的健康检查
echo ""
echo "=== 健康检查 ==="
echo "测试端口 20001:"
if curl -f --connect-timeout 5 --max-time 10 "http://124.156.102.70:20001" >/dev/null 2>&1; then
    echo "✅ 端口 20001 可访问"
else
    echo "❌ 端口 20001 不可访问"
fi

echo "测试端口 20002:"
if curl -f --connect-timeout 5 --max-time 10 "http://124.156.102.70:20002" >/dev/null 2>&1; then
    echo "✅ 端口 20002 可访问"
else
    echo "❌ 端口 20002 不可访问"
fi

# 10. 获取容器日志（最后几行）
echo ""
echo "=== 获取容器日志 ==="
LOG_RESULT=$(curl -s -w "%{http_code}" "${AUTH_HEADERS[@]}" \
  "$PANEL_URL/api/v2/containers/search/log" -o /tmp/log_result.json \
  -d "{\"containerID\": \"$CONTAINER_NAME\", \"mode\": \"tail\", \"number\": 20}")

if [ "$LOG_RESULT" = "200" ]; then
    echo "容器日志:"
    cat /tmp/log_result.json | jq -r '.content // empty' 2>/dev/null || \
    cat /tmp/log_result.json
else
    echo "获取日志失败 (HTTP $LOG_RESULT):"
    cat /tmp/log_result.json
fi

echo ""
echo "🎉 测试完成！"
echo ""
echo "测试总结:"
echo "- 容器名称: $CONTAINER_NAME" 
echo "- 镜像版本: $TEST_IMAGE"
echo "- 端口映射: 20001:10001, 20002:10002"
echo "- 网络: openim-docker_openim"
echo ""
echo "如需清理测试容器，请运行:"
echo "curl -X POST -H \"X-API-Key: $API_KEY\" -H \"Timestamp: \$(date +%s)\" -H \"Content-Type: application/json\" \\"
echo "  -d '{\"names\": [\"$CONTAINER_NAME\"], \"operation\": \"remove\"}' \\"
echo "  \"$PANEL_URL/api/v2/containers/operate\""

# 清理临时文件
rm -f /tmp/api_test.json /tmp/stop_result.json /tmp/remove_result.json /tmp/pull_result.json /tmp/create_result.json /tmp/start_result.json /tmp/status_result.json /tmp/log_result.json