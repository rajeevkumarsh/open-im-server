#!/bin/bash

# OpenIM Server Docker Entrypoint Script
# 支持 Coolify 容器部署和本地开发测试

set -e

# 检测运行环境
if [ -n "$CONTAINER" ] || [ "$USER" = "openim" ]; then
    ENVIRONMENT="container"
    # 容器环境：使用预设的工作目录
    cd "${SERVER_DIR:-/openim-server}"
else
    ENVIRONMENT="local"
    # 本地环境：使用当前目录
    SERVER_DIR=$(pwd)
fi

echo "=== OpenIM Server Starting ==="
echo "Environment: $ENVIRONMENT"
echo "Working Directory: $(pwd)"
echo "User: $(whoami)"
echo "Environment Variables:"
echo "  SERVER_DIR=${SERVER_DIR}"
echo "  MONGO_HOST=${MONGO_HOST}"
echo "  REDIS_HOST=${REDIS_HOST}"
echo "  ETCD_HOST=${ETCD_HOST}"

# 检查必要文件
echo "=== Checking Required Files ==="
if [ ! -f "start-config.yml" ]; then
    echo "❌ start-config.yml not found"
    exit 1
fi

if [ ! -d "_output/bin" ]; then
    echo "⚠️  _output/bin directory not found"
    echo "🔨 Attempting to build project..."
    
    # 检查是否有 mage 工具
    if command -v mage >/dev/null 2>&1; then
        echo "Building with mage..."
        if mage build; then
            echo "✅ Build completed successfully"
        else
            echo "❌ Build failed"
            exit 1
        fi
    elif [ -f "Makefile" ]; then
        echo "Building with make..."
        if make build; then
            echo "✅ Build completed successfully"
        else
            echo "❌ Build failed"
            exit 1
        fi
    else
        echo "❌ No build tool found (mage or make)"
        exit 1
    fi
fi

if [ ! -f "_output/bin/openim-api" ]; then
    echo "❌ openim-api binary not found after build"
    exit 1
fi

echo "✅ All required files found"

# 设置文件权限
echo "=== Setting File Permissions ==="
chmod +x _output/bin/* 2>/dev/null || true

# 启动服务
echo "=== Starting OpenIM Services ==="
echo "Starting with mage..."

# 使用 mage start 启动所有服务
if ! mage start; then
    echo "❌ Failed to start services with mage"
    echo "=== Attempting individual service startup ==="
    
    # 如果 mage start 失败，尝试直接启动关键服务
    echo "Starting openim-api manually..."
    ./_output/bin/openim-api --config=config &
    
    echo "Starting openim-rpc-user manually..."
    ./_output/bin/openim-rpc-user --config=config &
    
    echo "Starting openim-msggateway manually..."
    ./_output/bin/openim-msggateway --config=config &
fi

echo "=== Services Started ==="

# 根据环境选择运行模式
if [ "$ENVIRONMENT" = "local" ]; then
    echo "=== Local Development Mode ==="
    echo "✅ Services started successfully"
    echo "💡 Local testing tips:"
    echo "   - Check logs in _output/logs/"
    echo "   - API endpoint: http://localhost:10002"
    echo "   - Use 'ps aux | grep openim' to check processes"
    echo "   - Use 'pkill -f openim' to stop all services"
    echo ""
    echo "🎉 OpenIM Server is running locally!"
    echo "Press Ctrl+C to stop monitoring (services will continue running)"
    
    # 本地模式：显示进程状态后退出，让服务在后台运行
    sleep 5
    echo "=== Current Process Status ==="
    ps aux | grep openim | grep -v grep || echo "No openim processes found"
    
else
    echo "=== Container Health Check Loop ==="
    # 容器模式：持续监控循环
    while true; do
        sleep 30
        
        # 检查关键进程
        if ! pgrep -f "openim-api" > /dev/null; then
            echo "⚠️  openim-api process not found"
        fi
        
        if ! pgrep -f "openim-rpc" > /dev/null; then
            echo "⚠️  openim-rpc processes not found"
        fi
        
        # 每5分钟输出一次状态
        if [ $(($(date +%s) % 300)) -eq 0 ]; then
            echo "=== Service Status $(date) ==="
            ps aux | grep openim | grep -v grep || echo "No openim processes found"
        fi
    done
fi