// Copyright © 2023 OpenIM. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package api

import (
	"github.com/gin-gonic/gin"
	_ "github.com/openimsdk/open-im-server/v3/pkg/apistruct"
	"github.com/openimsdk/protocol/auth"
	"github.com/openimsdk/tools/a2r"
)

type AuthApi struct {
	Client auth.AuthClient
}

func NewAuthApi(client auth.AuthClient) AuthApi {
	return AuthApi{client}
}

// GetAdminToken 获取管理员Token
// @Summary 获取管理员Token
// @Description 管理员登录获取访问令牌
// @Tags 认证管理
// @Accept json
// @Produce json
// @Param body body apistruct.GetAdminTokenReq true "管理员登录信息"
// @Success 200 {object} apistruct.ApiResponse{data=apistruct.GetAdminTokenResp} "成功响应"
// @Failure 400 {object} apistruct.ApiResponse "请求参数错误"
// @Failure 401 {object} apistruct.ApiResponse "认证失败"
// @Router /auth/get_admin_token [post]
func (o *AuthApi) GetAdminToken(c *gin.Context) {
	a2r.Call(c, auth.AuthClient.GetAdminToken, o.Client)
}

// GetUserToken 获取用户Token
// @Summary 获取用户Token  
// @Description 用户登录获取访问令牌，用于后续API调用的身份认证
// @Tags 认证管理
// @Accept json
// @Produce json
// @Param body body apistruct.GetUserTokenReq true "用户登录信息"
// @Success 200 {object} apistruct.ApiResponse{data=apistruct.GetUserTokenResp} "成功响应，包含token和过期时间"
// @Failure 400 {object} apistruct.ApiResponse "请求参数错误"
// @Failure 401 {object} apistruct.ApiResponse "认证失败，用户名或密码错误"
// @Router /auth/get_user_token [post]
func (o *AuthApi) GetUserToken(c *gin.Context) {
	a2r.Call(c, auth.AuthClient.GetUserToken, o.Client)
}

// ParseToken 解析Token
// @Summary 解析Token
// @Description 解析并验证Token的有效性，返回Token中包含的用户信息
// @Tags 认证管理
// @Accept json
// @Produce json
// @Param body body apistruct.ParseTokenReq true "Token信息"
// @Success 200 {object} apistruct.ApiResponse{data=apistruct.ParseTokenResp} "成功响应，包含用户ID和过期时间"
// @Failure 400 {object} apistruct.ApiResponse "请求参数错误"
// @Failure 401 {object} apistruct.ApiResponse "Token无效或已过期"
// @Router /auth/parse_token [post]
func (o *AuthApi) ParseToken(c *gin.Context) {
	a2r.Call(c, auth.AuthClient.ParseToken, o.Client)
}

// ForceLogout 强制登出
// @Summary 强制登出用户
// @Description 强制指定用户登出，清除其所有Token
// @Tags 认证管理
// @Accept json
// @Produce json
// @Security BearerToken
// @Param body body apistruct.ForceLogoutReq true "强制登出信息"
// @Success 200 {object} apistruct.ApiResponse "成功响应"
// @Failure 400 {object} apistruct.ApiResponse "请求参数错误"
// @Failure 401 {object} apistruct.ApiResponse "权限不足"
// @Router /auth/force_logout [post]
func (o *AuthApi) ForceLogout(c *gin.Context) {
	a2r.Call(c, auth.AuthClient.ForceLogout, o.Client)
}
