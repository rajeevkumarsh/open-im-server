package apistruct

// GetAdminTokenReq 管理员登录请求
type GetAdminTokenReq struct {
	Secret   string `json:"secret" binding:"required" example:"admin_secret"`
	AdminID  string `json:"adminID" binding:"required" example:"admin"`
}

// GetAdminTokenResp 管理员登录响应
type GetAdminTokenResp struct {
	Token         string `json:"token" example:"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."`
	ExpireTimeSeconds int64  `json:"expireTimeSeconds" example:"86400"`
}

// GetUserTokenReq 用户登录请求
type GetUserTokenReq struct {
	Secret   string `json:"secret" binding:"required" example:"openIM123"`
	UserID   string `json:"userID" binding:"required" example:"user123"`
	PlatformID int32 `json:"platformID" binding:"required,min=1,max=12" example:"1"`
}

// GetUserTokenResp 用户登录响应
type GetUserTokenResp struct {
	Token         string `json:"token" example:"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."`
	ExpireTimeSeconds int64  `json:"expireTimeSeconds" example:"86400"`
}

// ParseTokenReq 解析Token请求
type ParseTokenReq struct {
	Token string `json:"token" binding:"required" example:"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."`
}

// ParseTokenResp 解析Token响应
type ParseTokenResp struct {
	UserID   string `json:"userID" example:"user123"`
	Platform string `json:"platform" example:"iOS"`
	ExpireTimeSeconds int64  `json:"expireTimeSeconds" example:"86400"`
}

// ForceLogoutReq 强制登出请求
type ForceLogoutReq struct {
	UserID     string `json:"userID" binding:"required" example:"user123"`
	PlatformID int32 `json:"platformID" binding:"required,min=1,max=12" example:"1"`
}