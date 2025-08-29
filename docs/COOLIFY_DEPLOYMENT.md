# OpenIM Coolify 部署指南

本指南将帮助您在 Coolify 平台上部署 OpenIM 聊天服务器。

## 前提条件

### 服务器环境要求
- 已配置的外部服务（您已配置完成）:
  - MongoDB 数据库
  - Redis 缓存
  - Kafka 消息队列  
  - etcd 服务发现
  - MinIO 对象存储

### Coolify 环境
- Coolify v4.0+ 已安装配置
- Docker 支持
- 网络连通性到外部服务

## 部署步骤

### 1. 准备项目

```bash
# 克隆项目
git clone <your-repo-url>
cd open-im-server

# 复制环境配置文件
cp .env.example .env

# 编辑环境配置
vim .env
```

### 2. 配置环境变量

编辑 `.env` 文件，配置您服务器的实际连接信息：

```bash
# MongoDB 配置
MONGO_HOST=your-mongodb-host
MONGO_PORT=27017
MONGO_DATABASE=openim_v3
MONGO_USERNAME=openIM
MONGO_PASSWORD=openIM123

# Redis 配置  
REDIS_HOST=your-redis-host
REDIS_PORT=6379
REDIS_PASSWORD=openIM123

# Kafka 配置
KAFKA_HOST=your-kafka-host
KAFKA_PORT=9092

# etcd 配置
ETCD_HOST=your-etcd-host
ETCD_PORT=2379

# MinIO 配置
MINIO_HOST=your-minio-host
MINIO_PORT=9000
MINIO_ACCESS_KEY=root
MINIO_SECRET_KEY=openIM123
```

### 3. 测试部署环境

运行部署脚本检查环境：

```bash
./scripts/coolify-deploy.sh
```

脚本会检查：
- ✅ 必要工具是否安装
- ✅ 环境变量是否正确配置
- ✅ 外部服务连接是否正常
- ✅ Docker 镜像构建是否成功

### 4. 在 Coolify 中创建应用

#### 4.1 通过 Git Repository 部署

1. 在 Coolify 管理界面中，点击 "New Resource"
2. 选择 "Application"
3. 选择 "Public Repository" 或连接您的私有仓库
4. 填写仓库信息：
   - Repository URL: `https://github.com/your-username/open-im-server`
   - Branch: `main`
   - Build Pack: `Docker`

#### 4.2 配置构建设置

在应用设置中：

1. **General** 标签：
   - Name: `openim-server`
   - Description: `OpenIM Chat Server`

2. **Source** 标签：
   - Dockerfile: `Dockerfile.coolify`
   - Docker Compose: `docker-compose.coolify.yml`

3. **Environment Variables** 标签：
   添加所有 `.env` 文件中的环境变量

4. **Domains** 标签：
   - 添加您的域名
   - 配置 SSL 证书

5. **Health Check** 标签：
   - Path: `/api/get_server_api_map`
   - Port: `10002`
   - Interval: `30s`

### 5. 部署应用

1. 配置完成后，点击 "Deploy"
2. Coolify 将开始构建和部署过程
3. 可在 "Deployments" 标签中查看部署日志

### 6. 验证部署

部署完成后：

1. **检查健康状态**：
   ```bash
   curl http://your-domain.com/api/get_server_api_map
   ```

2. **检查服务日志**：
   在 Coolify 管理界面的 "Logs" 标签中查看应用日志

3. **测试 WebSocket 连接**：
   ```javascript
   const ws = new WebSocket('ws://your-domain.com:10001');
   ```

## 端口配置

OpenIM 使用以下端口：

| 服务 | 端口 | 描述 |
|------|------|------|
| API Server | 10002 | HTTP API 接口 |
| WebSocket Gateway | 10001 | WebSocket 连接 |
| Prometheus | 19090 | 监控指标 |

## 环境变量说明

### 核心配置
- `OPENIM_SECRET`: OpenIM 加密密钥
- `SERVER_IP`: 服务器监听 IP
- `API_PORTS`: API 服务端口列表

### 数据库配置
- `MONGO_*`: MongoDB 连接配置
- `REDIS_*`: Redis 连接配置

### 消息队列配置  
- `KAFKA_*`: Kafka 连接配置

### 服务发现配置
- `ETCD_*`: etcd 连接配置

### 对象存储配置
- `MINIO_*`: MinIO 连接配置

## CI/CD 集成

项目已配置 GitHub Actions 工作流，支持：

- ✅ 自动构建和测试
- ✅ Docker 镜像构建和推送
- ✅ 自动部署到 Coolify
- ✅ 安全漏洞扫描

### 设置 CI/CD

1. **GitHub Repository Secrets**：
   - `COOLIFY_WEBHOOK_URL`: Coolify 部署 webhook
   - `COOLIFY_TOKEN`: Coolify API token
   - `SLACK_WEBHOOK`: Slack 通知 webhook (可选)

2. **触发条件**：
   - 推送到 `main` 分支：自动构建和部署
   - 推送到其他分支：仅构建和测试
   - Pull Request：构建、测试和安全扫描

## 监控和维护

### 健康检查
- URL: `/api/get_server_api_map`
- 间隔: 30秒
- 超时: 10秒
- 重试: 3次

### 日志管理
- 应用日志：`/openim-server/_output/logs`
- 持久化存储：通过 Docker volumes

### 资源监控
- 内存限制：2GB
- CPU 限制：1 核心
- 最小预留：512MB 内存，0.25 核心

## 故障排除

### 常见问题

1. **构建失败**
   - 检查 Go 版本是否为 1.22
   - 确认依赖是否正确下载
   - 查看构建日志定位错误

2. **启动失败**  
   - 验证环境变量配置
   - 检查外部服务连接
   - 查看容器日志

3. **健康检查失败**
   - 确认端口 10002 可访问
   - 检查 API 服务是否正常启动
   - 验证网络配置

4. **外部服务连接问题**
   - 使用 `./scripts/coolify-deploy.sh` 测试连接
   - 检查防火墙和网络配置
   - 验证认证信息

### 调试命令

```bash
# 查看容器状态
docker ps

# 查看应用日志
docker logs openim-server

# 进入容器调试
docker exec -it openim-server /bin/bash

# 测试外部服务连接
./scripts/coolify-deploy.sh
```

## 更新和升级

### 更新应用
1. 推送代码到 Git 仓库
2. CI/CD 自动触发构建和部署
3. 或在 Coolify 界面手动触发部署

### 版本回滚
1. 在 Coolify 管理界面找到 "Deployments" 
2. 选择要回滚的版本
3. 点击 "Redeploy"

## 安全建议

1. **环境变量安全**：
   - 不要在代码中硬编码敏感信息
   - 使用 Coolify 的环境变量管理

2. **网络安全**：
   - 配置防火墙规则
   - 使用 HTTPS/WSS
   - 限制不必要的端口访问

3. **定期更新**：
   - 保持依赖库最新
   - 定期更新基础镜像
   - 监控安全漏洞

## 支持

如有问题，请：
1. 查看 [OpenIM 官方文档](https://docs.openim.io/)
2. 提交 Issue 到项目仓库
3. 加入 OpenIM 社区讨论