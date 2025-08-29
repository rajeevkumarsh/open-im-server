#!/bin/bash

# OpenIM Coolify 部署脚本
# 用于配置和部署 OpenIM 到 Coolify 环境

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

# 检查必要的工具
check_requirements() {
    log_info "检查部署环境..."
    
    local missing_tools=()
    
    # 检查 docker
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    # 检查 curl
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "缺少必要工具: ${missing_tools[*]}"
        log_error "请安装缺少的工具后重试"
        exit 1
    fi
    
    log_success "环境检查完成"
}

# 检查环境变量配置
check_env_config() {
    log_info "检查环境变量配置..."
    
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            log_warning ".env 文件不存在，正在从 .env.example 创建..."
            cp .env.example .env
            log_warning "请编辑 .env 文件配置您的服务器信息"
            return 1
        else
            log_error ".env.example 文件不存在，无法创建配置文件"
            return 1
        fi
    fi
    
    # 检查关键环境变量
    local required_vars=(
        "MONGO_HOST"
        "REDIS_HOST" 
        "KAFKA_HOST"
        "ETCD_HOST"
        "MINIO_HOST"
    )
    
    local missing_vars=()
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # 跳过注释和空行
        [[ $line =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # 提取变量名和值
        if [[ $line == *"="* ]]; then
            var_name="${line%%=*}"
            var_value="${line#*=}"
            
            # 检查是否是必需变量且值为空或占位符
            for required_var in "${required_vars[@]}"; do
                if [[ "$var_name" == "$required_var" ]]; then
                    if [[ -z "$var_value" ]] || [[ "$var_value" == *"host" ]] || [[ "$var_value" == *"your-"* ]]; then
                        missing_vars+=("$var_name")
                    fi
                fi
            done
        fi
    done < .env
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        log_error "以下环境变量需要配置: ${missing_vars[*]}"
        log_error "请在 .env 文件中配置正确的服务器连接信息"
        return 1
    fi
    
    log_success "环境变量配置检查完成"
    return 0
}

# 测试外部服务连接
test_external_services() {
    log_info "测试外部服务连接..."
    
    source .env
    
    local failed_services=()
    
    # 测试 MongoDB 连接
    log_info "测试 MongoDB 连接..."
    if ! timeout 10 bash -c "</dev/tcp/${MONGO_HOST}/${MONGO_PORT}" 2>/dev/null; then
        log_warning "无法连接到 MongoDB (${MONGO_HOST}:${MONGO_PORT})"
        failed_services+=("MongoDB")
    else
        log_success "MongoDB 连接正常"
    fi
    
    # 测试 Redis 连接
    log_info "测试 Redis 连接..."
    if ! timeout 10 bash -c "</dev/tcp/${REDIS_HOST}/${REDIS_PORT}" 2>/dev/null; then
        log_warning "无法连接到 Redis (${REDIS_HOST}:${REDIS_PORT})"
        failed_services+=("Redis")
    else
        log_success "Redis 连接正常"
    fi
    
    # 测试 Kafka 连接
    log_info "测试 Kafka 连接..."
    if ! timeout 10 bash -c "</dev/tcp/${KAFKA_HOST}/${KAFKA_PORT}" 2>/dev/null; then
        log_warning "无法连接到 Kafka (${KAFKA_HOST}:${KAFKA_PORT})"
        failed_services+=("Kafka")
    else
        log_success "Kafka 连接正常"
    fi
    
    # 测试 etcd 连接
    log_info "测试 etcd 连接..."
    if ! timeout 10 bash -c "</dev/tcp/${ETCD_HOST}/${ETCD_PORT}" 2>/dev/null; then
        log_warning "无法连接到 etcd (${ETCD_HOST}:${ETCD_PORT})"
        failed_services+=("etcd")
    else
        log_success "etcd 连接正常"
    fi
    
    # 测试 MinIO 连接
    log_info "测试 MinIO 连接..."
    if ! timeout 10 bash -c "</dev/tcp/${MINIO_HOST}/${MINIO_PORT}" 2>/dev/null; then
        log_warning "无法连接到 MinIO (${MINIO_HOST}:${MINIO_PORT})"
        failed_services+=("MinIO")
    else
        log_success "MinIO 连接正常"
    fi
    
    if [ ${#failed_services[@]} -ne 0 ]; then
        log_warning "以下服务连接失败: ${failed_services[*]}"
        log_warning "请检查服务器配置和网络连接"
        log_warning "部署可能会失败，是否继续？(y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "部署已取消"
            exit 1
        fi
    else
        log_success "所有外部服务连接正常"
    fi
}

# 构建 Docker 镜像
build_image() {
    log_info "构建 OpenIM Docker 镜像..."
    
    if docker build -f Dockerfile.coolify -t openim-server:latest .; then
        log_success "Docker 镜像构建成功"
    else
        log_error "Docker 镜像构建失败"
        return 1
    fi
}

# 显示部署信息
show_deployment_info() {
    log_info "=== OpenIM Coolify 部署信息 ==="
    echo
    log_info "API 端口: 10002"
    log_info "WebSocket 端口: 10001" 
    log_info "健康检查: http://localhost:10002/api/get_server_api_map"
    echo
    log_info "部署文件:"
    log_info "  - docker-compose.coolify.yml (Coolify 部署配置)"
    log_info "  - Dockerfile.coolify (优化的 Dockerfile)"
    log_info "  - .coolify.yml (Coolify 应用配置)"
    log_info "  - .env (环境变量配置)"
    echo
    log_success "配置文件已准备就绪，可以在 Coolify 中导入项目进行部署"
}

# 主函数
main() {
    log_info "开始 OpenIM Coolify 部署准备..."
    echo
    
    # 检查运行环境
    check_requirements
    
    # 检查环境配置
    if ! check_env_config; then
        log_error "环境配置检查失败，请修复后重试"
        exit 1
    fi
    
    # 测试外部服务
    test_external_services
    
    # 构建镜像（可选）
    if [ "${BUILD_IMAGE:-true}" = "true" ]; then
        build_image
    fi
    
    # 显示部署信息
    show_deployment_info
    
    log_success "OpenIM Coolify 部署准备完成！"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi