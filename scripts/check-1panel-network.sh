#!/bin/bash

# 检查 1Panel 网络和服务连接脚本
# 用于验证 OpenIM 是否能正确连接到 1Panel 管理的依赖服务

set -euo pipefail

# 颜色输出函数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 1Panel 网络是否存在
check_1panel_network() {
    log_info "检查 1panel-network 是否存在..."
    
    if docker network ls | grep -q "1panel-network"; then
        log_success "1panel-network 网络存在"
        
        # 显示网络详细信息
        log_info "网络详细信息："
        docker network inspect 1panel-network --format='{{json .}}' | jq -r '.IPAM.Config[0].Subnet // "未配置子网"' | while read subnet; do
            echo "  - 子网: $subnet"
        done
        
        return 0
    else
        log_error "1panel-network 网络不存在"
        log_error "请检查 1Panel 是否正确安装和配置"
        return 1
    fi
}

# 检查 1Panel 容器是否在网络中
check_1panel_containers() {
    log_info "检查 1Panel 管理的容器..."
    
    # 从 .env 文件读取容器名
    if [ ! -f .env ]; then
        log_error ".env 文件不存在，请先配置环境变量"
        return 1
    fi
    
    source .env
    
    local containers=(
        "${MONGO_HOST:-1Panel-mongodb-iSy5}"
        "${REDIS_HOST:-1Panel-redis-IVlq}"
        "${KAFKA_HOST:-1Panel-kafka-YgzS}"
        "${ETCD_HOST:-1Panel-etcd-FdgX}"
        "${MINIO_HOST:-1Panel-minio-DShb}"
    )
    
    local missing_containers=()
    
    for container in "${containers[@]}"; do
        log_info "检查容器: $container"
        
        # 检查容器是否存在
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            log_success "✓ $container 运行中"
            
            # 检查容器是否在 1panel-network 中
            if docker inspect "$container" --format='{{json .NetworkSettings.Networks}}' | grep -q "1panel-network"; then
                log_success "  ✓ $container 已连接到 1panel-network"
            else
                log_warning "  ⚠ $container 未连接到 1panel-network"
            fi
        else
            log_error "✗ $container 未运行"
            missing_containers+=("$container")
        fi
    done
    
    if [ ${#missing_containers[@]} -ne 0 ]; then
        log_error "以下容器未运行: ${missing_containers[*]}"
        return 1
    fi
    
    return 0
}

# 测试网络连接
test_network_connectivity() {
    log_info "测试网络连接..."
    
    if [ ! -f .env ]; then
        log_error ".env 文件不存在，跳过连接测试"
        return 1
    fi
    
    source .env
    
    # 创建临时测试容器
    local test_container="openim-network-test"
    
    log_info "启动测试容器..."
    if docker run -d --name "$test_container" --network 1panel-network alpine:latest sleep 60 >/dev/null 2>&1; then
        log_success "测试容器启动成功"
        
        # 测试各个服务的连接
        local services=(
            "${MONGO_HOST:-1Panel-mongodb-iSy5}:${MONGO_PORT:-27017}"
            "${REDIS_HOST:-1Panel-redis-IVlq}:${REDIS_PORT:-6379}"
            "${KAFKA_HOST:-1Panel-kafka-YgzS}:${KAFKA_PORT:-9092}"
            "${ETCD_HOST:-1Panel-etcd-FdgX}:${ETCD_PORT:-2379}"
            "${MINIO_HOST:-1Panel-minio-DShb}:${MINIO_PORT:-9000}"
        )
        
        local failed_services=()
        
        for service in "${services[@]}"; do
            local host="${service%:*}"
            local port="${service#*:}"
            
            log_info "测试连接: $host:$port"
            
            if docker exec "$test_container" nc -z "$host" "$port" 2>/dev/null; then
                log_success "  ✓ $host:$port 连接成功"
            else
                log_error "  ✗ $host:$port 连接失败"
                failed_services+=("$service")
            fi
        done
        
        # 清理测试容器
        docker rm -f "$test_container" >/dev/null 2>&1
        
        if [ ${#failed_services[@]} -ne 0 ]; then
            log_error "以下服务连接失败: ${failed_services[*]}"
            return 1
        else
            log_success "所有服务连接正常"
            return 0
        fi
    else
        log_error "无法启动测试容器，请检查 1panel-network 网络配置"
        return 1
    fi
}

# 显示网络配置建议
show_network_config() {
    log_info "=== 网络配置建议 ==="
    echo
    log_info "1. 确保 Coolify 应用配置包含以下网络:"
    echo "   - 1panel-network (外部网络)"
    echo "   - coolify (Coolify 管理网络)"
    echo
    log_info "2. Docker Compose 网络配置:"
    echo "   networks:"
    echo "     1panel-network:"
    echo "       external: true"
    echo "     coolify:"
    echo "       external: true"
    echo
    log_info "3. 容器网络配置:"
    echo "   networks:"
    echo "     - 1panel-network"
    echo "     - coolify"
    echo
    log_info "4. 如果遇到网络问题，检查："
    echo "   - 1Panel 服务是否正常运行"
    echo "   - Coolify 是否有权限访问 1panel-network"
    echo "   - 防火墙和网络策略配置"
}

# 主函数
main() {
    log_info "开始检查 1Panel 网络配置..."
    echo
    
    local exit_code=0
    
    # 检查网络
    if ! check_1panel_network; then
        exit_code=1
    fi
    
    echo
    
    # 检查容器
    if ! check_1panel_containers; then
        exit_code=1
    fi
    
    echo
    
    # 测试连接
    if ! test_network_connectivity; then
        exit_code=1
    fi
    
    echo
    
    # 显示配置建议
    show_network_config
    
    if [ $exit_code -eq 0 ]; then
        log_success "1Panel 网络配置检查完成，一切正常！"
    else
        log_warning "发现一些问题，请参考上述建议进行修复"
    fi
    
    return $exit_code
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi