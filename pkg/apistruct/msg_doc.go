package apistruct

// SimpleSendMsgReq 简化的发送消息请求（用于文档）
type SimpleSendMsgReq struct {
	SendID           string                 `json:"sendID" binding:"required" example:"admin"`
	RecvID           string                 `json:"recvID" binding:"required_if" example:"user123"`
	GroupID          string                 `json:"groupID" binding:"required_if=SessionType 2|required_if=SessionType 3" example:"group123"`
	SenderNickname   string                 `json:"senderNickname" example:"管理员"`
	SenderFaceURL    string                 `json:"senderFaceURL" example:"https://example.com/avatar.jpg"`
	SenderPlatformID int32                  `json:"senderPlatformID" example:"1"`
	Content          map[string]interface{} `json:"content" binding:"required"`
	ContentType      int32                  `json:"contentType" binding:"required" example:"101"`
	SessionType      int32                  `json:"sessionType" binding:"required" example:"1"`
	IsOnlineOnly     bool                   `json:"isOnlineOnly" example:"false"`
	NotOfflinePush   bool                   `json:"notOfflinePush" example:"false"`
	SendTime         int64                  `json:"sendTime" example:"1640995200000"`
	Ex               string                 `json:"ex" example:"{}"`
}

// SimpleSendMsgResp 简化的发送消息响应（用于文档）
type SimpleSendMsgResp struct {
	ServerMsgID string `json:"serverMsgID" example:"msg_123456"`
	ClientMsgID string `json:"clientMsgID" example:"client_msg_123"`
	SendTime    int64  `json:"sendTime" example:"1640995200000"`
}