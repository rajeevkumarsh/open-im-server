#!/bin/bash

# OpenIM Server Swagger 文档生成脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}OpenIM Server API 文档生成工具${NC}"
echo "================================"

# 检查 swag 是否安装
if ! command -v swag &> /dev/null; then
    echo -e "${YELLOW}swag 未安装，正在安装...${NC}"
    go install github.com/swaggo/swag/cmd/swag@latest
    if [ $? -ne 0 ]; then
        echo -e "${RED}安装 swag 失败，请手动安装：go install github.com/swaggo/swag/cmd/swag@latest${NC}"
        exit 1
    fi
fi

cd "${PROJECT_ROOT}"

# 生成文档
echo -e "${YELLOW}正在生成 Swagger 文档...${NC}"
swag init -g cmd/openim-api/main.go \
    --parseInternal \
    --parseDependency \
    --output docs \
    --parseDepth 2

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Swagger 文档生成成功！${NC}"
    echo ""
    echo "文档文件位置："
    echo "  - JSON: ${PROJECT_ROOT}/docs/swagger.json"
    echo "  - YAML: ${PROJECT_ROOT}/docs/swagger.yaml"
    echo ""
    echo "查看文档方法："
    echo "  1. 启动 API 服务器"
    echo "  2. 访问 http://localhost:10002/swagger/index.html"
    echo ""
    echo "或者访问 http://localhost:10002/docs 自动跳转到文档页面"
else
    echo -e "${RED}❌ Swagger 文档生成失败${NC}"
    exit 1
fi