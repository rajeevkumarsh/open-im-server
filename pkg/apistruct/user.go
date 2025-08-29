package apistruct

// UserRegisterReq 用户注册请求
type UserRegisterReq struct {
	Secret   string     `json:"secret" binding:"required" example:"openIM123"`
	Users    []UserInfo `json:"users" binding:"required"`
}

// UserInfo 用户信息
type UserInfo struct {
	UserID     string `json:"userID" binding:"required" example:"user123"`
	Nickname   string `json:"nickname" binding:"required" example:"张三"`
	FaceURL    string `json:"faceURL" example:"https://example.com/avatar.jpg"`
	Gender     int32  `json:"gender" example:"1"`
	Birth      int64  `json:"birth" example:"946656000000"`
	AreaCode   string `json:"areaCode" example:"+86"`
	PhoneNumber string `json:"phoneNumber" example:"13812345678"`
	Email      string `json:"email" example:"user@example.com"`
	Ex         string `json:"ex" example:"{}"`
}

// UserRegisterResp 用户注册响应
type UserRegisterResp struct {
	UserID string `json:"userID" example:"user123"`
}

// UpdateUserInfoExReq 更新用户信息请求
type UpdateUserInfoExReq struct {
	UserID   string         `json:"userID" binding:"required" example:"user123"`
	Nickname *StringValue   `json:"nickname,omitempty"`
	FaceURL  *StringValue   `json:"faceURL,omitempty"`
	Gender   *Int32Value    `json:"gender,omitempty"`
	Birth    *Int64Value    `json:"birth,omitempty"`
	AreaCode *StringValue   `json:"areaCode,omitempty"`
	PhoneNumber *StringValue `json:"phoneNumber,omitempty"`
	Email    *StringValue   `json:"email,omitempty"`
	Ex       *StringValue   `json:"ex,omitempty"`
}

// StringValue 可选字符串值
type StringValue struct {
	Value string `json:"value"`
}

// Int32Value 可选整数值
type Int32Value struct {
	Value int32 `json:"value"`
}

// Int64Value 可选长整数值
type Int64Value struct {
	Value int64 `json:"value"`
}

// GetDesignateUsersReq 获取指定用户信息请求
type GetDesignateUsersReq struct {
	UserIDs []string `json:"userIDs" binding:"required" example:"user123,user456"`
}

// GetDesignateUsersResp 获取指定用户信息响应
type GetDesignateUsersResp struct {
	Users []PublicUserInfo `json:"users"`
}

// PublicUserInfo 公开用户信息
type PublicUserInfo struct {
	UserID   string `json:"userID" example:"user123"`
	Nickname string `json:"nickname" example:"张三"`
	FaceURL  string `json:"faceURL" example:"https://example.com/avatar.jpg"`
	Gender   int32  `json:"gender" example:"1"`
	Ex       string `json:"ex" example:"{}"`
}