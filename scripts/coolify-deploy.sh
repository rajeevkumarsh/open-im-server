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

# 测试外部服务连接（使用 Docker 网络）
test_external_services() {
    log_info "测试外部服务连接（Docker 网络环境）..."
    
    source .env
    
    # 检查 Docker 和 1panel-network 是否可用
    if ! command -v docker &> /dev/null; then
        log_warning "Docker 未安装，跳过网络连接测试"
        log_warning "请在 Coolify 部署后验证服务连接"
        return 0
    fi
    
    # 检查必需的网络
    local required_networks=("1panel-network" "openim-docker_openim")
    local available_networks=()
    
    for network in "${required_networks[@]}"; do
        if docker network ls | grep -q "$network"; then
            available_networks+=("$network")
            log_success "$network 网络存在"
        else
            log_warning "$network 网络不存在"
        fi
    done
    
    if [ ${#available_networks[@]} -eq 0 ]; then
        log_warning "没有找到必需的 Docker 网络，跳过网络连接测试"
        log_warning "请确保 1panel-network 或 openim-docker_openim 网络可用"
        return 0
    fi
    
    # 使用第一个可用网络进行测试
    local test_network="${available_networks[0]}"
    log_info "使用 $test_network 网络进行连接测试"
    
    local test_container="openim-connectivity-test-$$"
    local failed_services=()
    
    log_info "启动测试容器..."
    if ! docker run -d --name "$test_container" --network "$test_network" alpine:latest sleep 120 >/dev/null 2>&1; then
        log_warning "无法启动测试容器，跳过网络连接测试"
        log_warning "可能的原因："
        log_warning "  - 无权限访问 1panel-network"
        log_warning "  - Docker 守护进程问题"
        log_warning "请在 Coolify 环境中验证网络连接"
        return 0
    fi
    
    # 安装网络测试工具
    log_info "安装网络测试工具..."
    docker exec "$test_container" apk add --no-cache netcat-openbsd curl >/dev/null 2>&1
    
    # 定义服务列表
    local services=(
        "MongoDB:${MONGO_HOST}:${MONGO_PORT}"
        "Redis:${REDIS_HOST}:${REDIS_PORT}"
        "Kafka:${KAFKA_HOST}:${KAFKA_PORT}"
        "etcd:${ETCD_HOST}:${ETCD_PORT}"
        "MinIO:${MINIO_HOST}:${MINIO_PORT}"
    )
    
    # 测试每个服务
    for service_info in "${services[@]}"; do
        local service_name="${service_info%%:*}"
        local remaining="${service_info#*:}"
        local host="${remaining%:*}"
        local port="${remaining##*:}"
        
        log_info "测试 $service_name 连接 ($host:$port)..."
        
        if docker exec "$test_container" nc -z -w5 "$host" "$port" 2>/dev/null; then
            log_success "$service_name 连接正常"
        else
            log_warning "无法连接到 $service_name ($host:$port)"
            failed_services+=("$service_name")
        fi
    done
    
    # 清理测试容器
    log_info "清理测试容器..."
    docker rm -f "$test_container" >/dev/null 2>&1
    
    # 结果处理
    if [ ${#failed_services[@]} -ne 0 ]; then
        log_warning "以下服务连接失败: ${failed_services[*]}"
        echo
        log_warning "可能的原因："
        log_warning "  - 服务容器未运行或未连接到 1panel-network"
        log_warning "  - 1Panel 服务配置问题"
        log_warning "  - 防火墙或网络策略限制"
        echo
        log_info "建议操作："
        log_info "  1. 检查 1Panel 中的服务状态"
        log_info "  2. 验证服务容器是否在 1panel-network 中"
        log_info "  3. 运行 ./scripts/check-1panel-network.sh 进行详细检查"
        echo
        log_warning "部署可能会失败，是否继续？(y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "部署已取消"
            log_info "请先修复服务连接问题，然后重新运行此脚本"
            exit 1
        fi
    else
        log_success "所有外部服务连接正常"
        log_success "OpenIM 应该能够正常连接到依赖服务"
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
    log_info "网络配置:"
    log_info "  - 1panel-network (连接 1Panel 依赖服务)"
    log_info "  - coolify (Coolify 平台管理网络)"
    echo
    log_info "依赖服务:"
    source .env 2>/dev/null || true
    log_info "  - MongoDB: ${MONGO_HOST:-未配置}:${MONGO_PORT:-27017}"
    log_info "  - Redis: ${REDIS_HOST:-未配置}:${REDIS_PORT:-6379}"
    log_info "  - Kafka: ${KAFKA_HOST:-未配置}:${KAFKA_PORT:-9092}"
    log_info "  - etcd: ${ETCD_HOST:-未配置}:${ETCD_PORT:-2379}"
    log_info "  - MinIO: ${MINIO_HOST:-未配置}:${MINIO_PORT:-9000}"
    echo
    log_success "配置文件已准备就绪，可以在 Coolify 中导入项目进行部署"
    echo
    log_info "下一步操作:"
    log_info "  1. 推送代码到 Git 仓库"
    log_info "  2. 在 Coolify 中导入项目"
    log_info "  3. 配置环境变量和网络"
    log_info "  4. 启动部署"
}

# 显示使用帮助
show_usage() {
    echo "OpenIM Coolify 部署脚本"
    echo
    echo "使用方法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help              显示此帮助信息"
    echo "  -s, --skip-network      跳过网络连接测试"
    echo "  -n, --no-build         跳过 Docker 镜像构建"
    echo "  -t, --test-only        仅执行网络连接测试"
    echo
    echo "环境变量:"
    echo "  BUILD_IMAGE=false       跳过镜像构建（默认: true）"
    echo "  SKIP_NETWORK_TEST=true  跳过网络测试（默认: false）"
    echo
    echo "示例:"
    echo "  $0                      完整的部署准备过程"
    echo "  $0 -s                   跳过网络测试"
    echo "  $0 -t                   仅测试网络连接"
    echo "  $0 -n -s                跳过构建和网络测试"
}

# 主函数
main() {
    local skip_network=false
    local no_build=false
    local test_only=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -s|--skip-network)
                skip_network=true
                shift
                ;;
            -n|--no-build)
                no_build=true
                shift
                ;;
            -t|--test-only)
                test_only=true
                shift
                ;;
            *)
                log_error "未知选项: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 环境变量覆盖
    if [ "${SKIP_NETWORK_TEST:-false}" = "true" ]; then
        skip_network=true
    fi
    
    if [ "${BUILD_IMAGE:-true}" = "false" ]; then
        no_build=true
    fi
    
    if [ "$test_only" = "true" ]; then
        log_info "仅执行网络连接测试..."
        echo
        
        # 检查环境配置
        if ! check_env_config; then
            log_error "环境配置检查失败，无法执行网络测试"
            exit 1
        fi
        
        # 测试外部服务
        test_external_services
        exit $?
    fi
    
    log_info "开始 OpenIM Coolify 部署准备..."
    echo
    
    # 检查运行环境
    check_requirements
    
    # 检查环境配置
    if ! check_env_config; then
        log_error "环境配置检查失败，请修复后重试"
        exit 1
    fi
    
    # 测试外部服务（可选）
    if [ "$skip_network" = "false" ]; then
        test_external_services
    else
        log_warning "跳过网络连接测试"
        log_warning "请确保在 Coolify 环境中服务连接正常"
    fi
    
    # 构建镜像（可选）
    if [ "$no_build" = "false" ]; then
        build_image
    else
        log_warning "跳过 Docker 镜像构建"
    fi
    
    # 显示部署信息
    show_deployment_info
    
    log_success "OpenIM Coolify 部署准备完成！"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi