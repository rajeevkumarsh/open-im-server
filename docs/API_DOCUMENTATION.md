# OpenIM Server API 文档

## 📖 概述

OpenIM Server 提供了完整的 REST API 接口，用于即时通讯服务的各项功能。本文档基于 OpenAPI 3.0 规范，使用 Swagger 工具自动生成。

## 🚀 快速开始

### 1. 生成文档

```bash
# 方式一：使用 Makefile
make -f Makefile.docs swagger

# 方式二：使用脚本
bash scripts/generate-swagger.sh

# 方式三：直接使用 swag 命令
swag init -g cmd/openim-api/main.go --parseInternal --output docs
```

### 2. 查看文档

#### 在线查看（推荐）

1. 启动 OpenIM API 服务器
2. 访问 Swagger UI：
   - http://localhost:10002/swagger/index.html
   - 或 http://localhost:10002/docs （自动跳转）

#### 独立文档服务器

```bash
# 使用 Makefile 启动独立文档服务器
make -f Makefile.docs swagger-serve

# 访问 http://localhost:8080
```

#### 文件查看

生成的文档文件位于 `docs/` 目录：
- `swagger.json` - JSON 格式的 API 定义
- `swagger.yaml` - YAML 格式的 API 定义

## 📝 API 模块说明

### 认证管理 (/auth)
- `POST /auth/get_user_token` - 用户登录获取 Token
- `POST /auth/get_admin_token` - 管理员登录获取 Token
- `POST /auth/parse_token` - 解析验证 Token
- `POST /auth/force_logout` - 强制用户登出

### 用户管理 (/user)
- `POST /user/user_register` - 用户注册
- `POST /user/update_user_info_ex` - 更新用户信息
- `POST /user/get_users_info` - 获取用户公开信息
- 更多接口正在添加...

### 消息管理 (/msg)
- `POST /msg/send_msg` - 发送消息
- `POST /msg/pull_msg_by_seq` - 拉取消息
- `POST /msg/revoke_msg` - 撤回消息
- 更多接口正在添加...

### 群组管理 (/group)
- `POST /group/create_group` - 创建群组
- `POST /group/join_group` - 加入群组
- `POST /group/quit_group` - 退出群组
- 更多接口正在添加...

### 好友关系 (/friend)
- `POST /friend/add_friend` - 添加好友
- `POST /friend/delete_friend` - 删除好友
- `POST /friend/get_friend_list` - 获取好友列表
- 更多接口正在添加...

## 🔐 认证方式

大部分 API 需要 Token 认证：

1. **获取 Token**：调用 `/auth/get_user_token` 或 `/auth/get_admin_token`
2. **使用 Token**：在请求 Header 中添加：
   ```
   token: <your_token_here>
   ```

## 📋 请求规范

- **方法**：所有接口均使用 POST 方法
- **Content-Type**：`application/json`
- **字符编码**：UTF-8
- **响应格式**：JSON

### 通用响应格式

```json
{
  "errCode": 0,
  "errMsg": "success",
  "errDlt": "",
  "data": {}
}
```

- `errCode`: 错误码，0 表示成功
- `errMsg`: 错误信息
- `errDlt`: 详细错误信息（可选）
- `data`: 响应数据

## 🛠 开发指南

### 添加新的 API 文档

1. 在对应的 API 处理函数上方添加 Swagger 注释：

```go
// GetUserInfo 获取用户信息
// @Summary 获取用户详细信息
// @Description 根据用户ID获取用户的详细信息
// @Tags 用户管理
// @Accept json
// @Produce json
// @Security BearerToken
// @Param body body GetUserInfoReq true "请求参数"
// @Success 200 {object} ApiResponse{data=GetUserInfoResp} "成功"
// @Failure 400 {object} ApiResponse "参数错误"
// @Router /user/get_user_info [post]
func (u *UserApi) GetUserInfo(c *gin.Context) {
    // ...
}
```

2. 定义请求和响应结构体（在 `pkg/apistruct/` 目录）：

```go
type GetUserInfoReq struct {
    UserID string `json:"userID" binding:"required" example:"user123"`
}

type GetUserInfoResp struct {
    UserInfo UserInfo `json:"userInfo"`
}
```

3. 重新生成文档：

```bash
make -f Makefile.docs swagger
```

### Swagger 注释说明

- `@Summary`: 简短描述
- `@Description`: 详细描述
- `@Tags`: API 分组标签
- `@Accept`: 请求内容类型
- `@Produce`: 响应内容类型
- `@Security`: 认证方式
- `@Param`: 参数定义
- `@Success`: 成功响应
- `@Failure`: 错误响应
- `@Router`: 路由路径和方法

## 📚 相关资源

- [OpenAPI 3.0 规范](https://spec.openapis.org/oas/latest.html)
- [Swagger 官方文档](https://swagger.io/docs/)
- [swag 项目](https://github.com/swaggo/swag)
- [gin-swagger](https://github.com/swaggo/gin-swagger)

## 🤝 贡献指南

欢迎为 API 文档做出贡献：

1. Fork 项目
2. 添加或改进 API 注释
3. 确保文档能正常生成
4. 提交 Pull Request

## 📄 许可证

本项目采用 Apache 2.0 许可证，详见 [LICENSE](../LICENSE) 文件。

## 💬 联系方式

- GitHub: https://github.com/openimsdk/open-im-server
- 邮箱: contact@openim.io
- Slack: [加入我们的 Slack](https://join.slack.com/t/openimsdk/shared_invite/zt-2ijy1ys1f-O0aEDCr7ExRZ7mwsHAVg9A)

---

*文档最后更新：2024年8月*