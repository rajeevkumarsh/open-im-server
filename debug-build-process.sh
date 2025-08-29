#!/bin/bash

# 调试构建过程

PORTAINER_URL="http://129.226.214.22:9100"
PORTAINER_TOKEN="ptr_99YaZP1PKDwOKXQe69xY97A7v6vWxvW5nYknGULibdw="
ENDPOINT_ID="3"
CONTAINER_ID="7954a8191796"  # 我们刚创建的调试容器

echo "=== 调试构建过程 ==="

# 创建并执行命令的函数
exec_cmd() {
    local cmd="$1"
    echo "执行: $cmd"
    
    exec_id=$(curl -s -X POST \
      -H "X-API-Key: $PORTAINER_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"AttachStdout\": true,
        \"AttachStderr\": true,
        \"Cmd\": $cmd
      }" \
      "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/$CONTAINER_ID/exec" | jq -r '.Id')
    
    # 启动执行并获取输出
    curl -s -X POST \
      -H "X-API-Key: $PORTAINER_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"Detach": false, "Tty": false}' \
      "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/exec/$exec_id/start"
    
    echo "---"
}

# 检查各种文件和目录
exec_cmd '["ls", "-la", "/openim-server/"]'
exec_cmd '["ls", "-la", "/openim-server/_output/"]'
exec_cmd '["ls", "-la", "/openim-server/_output/bin/platforms/"]'
exec_cmd '["ls", "-la", "/openim-server/_output/bin/tools/"]'

echo ""
echo "=== 尝试手动运行 mage build ==="
exec_cmd '["mage", "-v", "build"]'

echo ""
echo "=== 检查 go mod 状态 ==="
exec_cmd '["go", "mod", "tidy"]'
exec_cmd '["go", "mod", "download"]'

echo ""
echo "=== 检查 cmd 目录 ==="
exec_cmd '["ls", "-la", "/openim-server/cmd/"]'

echo ""
echo "=== 检查环境变量 ==="
exec_cmd '["env", "|", "grep", "-E", "(GO|PATH)"]'