#!/bin/bash

# 检查容器中的二进制文件

PORTAINER_URL="http://129.226.214.22:9100"
PORTAINER_TOKEN="ptr_99YaZP1PKDwOKXQe69xY97A7v6vWxvW5nYknGULibdw="
ENDPOINT_ID="3"
CONTAINER_ID="c999966ee86f"

echo "=== 检查容器中的二进制文件 ==="

echo "=== 执行命令: ls -la /openim-server/_output/bin ==="
curl -X POST \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "AttachStdout": true,
    "AttachStderr": true,
    "Cmd": ["ls", "-la", "/openim-server/_output/bin"]
  }' \
  "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/$CONTAINER_ID/exec"

echo ""
echo "=== 检查 mage 版本 ==="
curl -X POST \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "AttachStdout": true,
    "AttachStderr": true,
    "Cmd": ["mage", "-version"]
  }' \
  "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/$CONTAINER_ID/exec"

echo ""
echo "=== 检查 Go 版本和环境 ==="
curl -X POST \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "AttachStdout": true,
    "AttachStderr": true,
    "Cmd": ["go", "version"]
  }' \
  "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/$CONTAINER_ID/exec"

echo ""
echo "=== 检查工作目录内容 ==="
curl -X POST \
  -H "X-API-Key: $PORTAINER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "AttachStdout": true,
    "AttachStderr": true,
    "Cmd": ["ls", "-la", "/openim-server/"]
  }' \
  "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/$CONTAINER_ID/exec"