package apistruct

// GetConfigReq 获取配置请求
type GetConfigReq struct {
	ConfigName string `json:"configName" binding:"required" example:"log.yaml"`
}

// GetConfigListResp 获取配置列表响应
type GetConfigListResp struct {
	Environment string   `json:"environment" example:"production"`
	Version     string   `json:"version" example:"v3.8.3"`
	ConfigNames []string `json:"configNames" example:"log.yaml,kafka.yaml,redis.yaml"`
}

// SetConfigReq 设置配置请求
type SetConfigReq struct {
	ConfigName string `json:"configName" binding:"required" example:"log.yaml"`
	Data       string `json:"data" binding:"required" example:"{\"level\":\"info\",\"format\":\"json\"}"`
}

// SetConfigsReq 批量设置配置请求
type SetConfigsReq struct {
	Configs []SetConfigReq `json:"configs" binding:"required"`
}

// SetEnableConfigManagerReq 设置配置管理器启用状态请求
type SetEnableConfigManagerReq struct {
	Enable bool `json:"enable" example:"true"`
}

// GetEnableConfigManagerResp 获取配置管理器启用状态响应
type GetEnableConfigManagerResp struct {
	Enable bool `json:"enable" example:"true"`
}
