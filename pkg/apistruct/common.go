package apistruct

// ApiResponse 通用 API 响应结构
type ApiResponse struct {
	ErrCode int    `json:"errCode" example:"0"`
	ErrMsg  string `json:"errMsg" example:"success"`
	ErrDlt  string `json:"errDlt,omitempty" example:""`
	Data    any    `json:"data,omitempty"`
}

// PageParam 分页参数
type PageParam struct {
	PageNumber int `json:"pageNumber" binding:"required,min=1" example:"1"`
	ShowNumber int `json:"showNumber" binding:"required,min=1,max=100" example:"20"`
}