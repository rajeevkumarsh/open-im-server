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

package main

import (
	"github.com/openimsdk/open-im-server/v3/pkg/common/cmd"
	"github.com/openimsdk/tools/system/program"
	_ "net/http/pprof"
)

// @title OpenIM Server API
// @version 3.8
// @description OpenIM Server 提供即时通讯服务的 REST API 接口文档
// @description
// @description ## 认证方式
// @description 大部分接口需要在 Header 中携带 token 进行认证：
// @description - Header名称: token
// @description - 获取方式: 调用 /auth/get_user_token 接口
// @description
// @description ## 接口规范
// @description - 所有接口均使用 POST 方法
// @description - Content-Type: application/json
// @description - 响应格式: JSON
//
// @contact.name OpenIM Support
// @contact.url https://github.com/openimsdk/open-im-server
// @contact.email contact@openim.io
//
// @license.name Apache 2.0
// @license.url http://www.apache.org/licenses/LICENSE-2.0.html
//
// @host localhost:10002
// @BasePath /
// @schemes http https
//
// @securityDefinitions.apikey BearerToken
// @in header
// @name token
func main() {
	if err := cmd.NewApiCmd().Exec(); err != nil {
		program.ExitWithError(err)
	}
}
