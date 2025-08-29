# OpenIM 阅后即焚功能完整实现方案

## 一、方案概述

### 1.1 设计理念
基于对主流IM应用的深度调研分析，我们采用**"Signal模式增强版"**架构，融合各家最佳实践：

- **安全优先**：真正的端到端加密 + 阅读后触发计时
- **体验友好**：直观的时间选择 + 清晰的视觉反馈
- **合规考虑**：法务保留接口 + 完整审计日志
- **渐进实施**：向后兼容 + 分阶段发布

### 1.2 核心改进
相比之前的方案，新方案具有以下关键改进：

1. **双重计时机制**：支持"发送后"和"阅读后"两种触发模式
2. **多级安全防护**：客户端 + 服务端 + 网络层多重保护
3. **智能合规功能**：自动识别敏感内容 + 选择性保留
4. **增强用户控制**：细粒度权限 + 个性化配置
5. **完整审计体系**：操作日志 + 删除证明 + 合规报告

## 二、技术架构设计

### 2.1 整体架构

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   客户端A       │    │   OpenIM服务端   │    │   客户端B       │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │消息加密模块 │◄┼────┼─│消息路由模块 │─┼────┤►│消息解密模块 │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │定时器管理   │ │    │ │燃烧协调器   │ │    │ │定时器管理   │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │本地删除引擎 │ │    │ │审计日志模块 │ │    │ │本地删除引擎 │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │安全防护模块 │ │    │ │合规管理模块 │ │    │ │安全防护模块 │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 2.2 核心组件

#### 2.2.1 客户端组件
1. **消息加密模块**：端到端加密，基于Signal Protocol
2. **定时器管理**：本地计时器 + 状态同步
3. **本地删除引擎**：安全删除 + 内存清理
4. **安全防护模块**：防截图 + 防调试 + 防逆向

#### 2.2.2 服务端组件
1. **消息路由模块**：加密消息转发 + 元数据最小化
2. **燃烧协调器**：多端同步 + 状态管理
3. **审计日志模块**：操作记录 + 删除证明
4. **合规管理模块**：法务保留 + 监管报告

## 三、数据模型设计

### 3.1 消息模型扩展

#### 3.1.1 后端消息模型
```go
// pkg/common/storage/model/msg.go
type MsgDataModel struct {
    // ... 现有字段 ...
    
    // 阅后即焚增强字段
    BurnConfig        *BurnConfig `bson:"burn_config,omitempty"`
    BurnState         *BurnState  `bson:"burn_state,omitempty"`
    BurnAudit         *BurnAudit  `bson:"burn_audit,omitempty"`
}

// 燃烧配置
type BurnConfig struct {
    Enabled           bool                `bson:"enabled"`                // 是否启用阅后即焚
    TriggerMode       int32              `bson:"trigger_mode"`           // 触发模式：1-发送后，2-阅读后
    Duration          int32              `bson:"duration"`               // 燃烧持续时间（秒）
    DeleteMode        int32              `bson:"delete_mode"`            // 删除模式：1-软删除，2-硬删除
    PreviewEnabled    bool               `bson:"preview_enabled"`        // 是否允许预览
    ScreenshotAlert   bool               `bson:"screenshot_alert"`       // 截图提醒
    ForwardBlocked    bool               `bson:"forward_blocked"`        // 是否阻止转发
    ContentTypes      []int32            `bson:"content_types"`          // 适用的内容类型
    ExceptionUsers    []string           `bson:"exception_users"`        // 例外用户列表（法务等）
}

// 燃烧状态
type BurnState struct {
    Status            int32              `bson:"status"`                 // 状态：0-未开始，1-燃烧中，2-已销毁
    StartTime         int64              `bson:"start_time"`             // 开始时间
    DeadlineTime      int64              `bson:"deadline_time"`          // 截止时间
    ReadUserStates    map[string]*ReadState `bson:"read_user_states"`    // 用户阅读状态
    DeletedDevices    []string           `bson:"deleted_devices"`        // 已删除的设备列表
    RetentionReason   string             `bson:"retention_reason"`       // 保留原因（法务等）
}

// 用户阅读状态
type ReadState struct {
    UserID            string             `bson:"user_id"`
    ReadTime          int64              `bson:"read_time"`              // 阅读时间
    DeviceID          string             `bson:"device_id"`              // 设备ID
    BurnStartTime     int64              `bson:"burn_start_time"`        // 个人燃烧开始时间
    BurnDeadline      int64              `bson:"burn_deadline"`          // 个人燃烧截止时间
    LocalDeleted      bool               `bson:"local_deleted"`          // 本地是否已删除
}

// 燃烧审计
type BurnAudit struct {
    CreateTime        int64              `bson:"create_time"`            // 创建时间
    CreatorID         string             `bson:"creator_id"`             // 创建者
    ReadLogs          []*ReadLog         `bson:"read_logs"`              // 阅读日志
    DeleteLogs        []*DeleteLog       `bson:"delete_logs"`            // 删除日志
    ViolationLogs     []*ViolationLog    `bson:"violation_logs"`         // 违规日志
    RetentionLogs     []*RetentionLog    `bson:"retention_logs"`         // 保留日志
}

// 阅读日志
type ReadLog struct {
    UserID            string             `bson:"user_id"`
    DeviceID          string             `bson:"device_id"`
    ReadTime          int64              `bson:"read_time"`
    IPAddress         string             `bson:"ip_address"`
    UserAgent         string             `bson:"user_agent"`
}

// 删除日志
type DeleteLog struct {
    UserID            string             `bson:"user_id"`
    DeviceID          string             `bson:"device_id"`
    DeleteTime        int64              `bson:"delete_time"`
    DeleteType        int32              `bson:"delete_type"`            // 1-自动，2-手动
    Success           bool               `bson:"success"`
    ErrorMessage      string             `bson:"error_message,omitempty"`
}

// 违规日志
type ViolationLog struct {
    UserID            string             `bson:"user_id"`
    DeviceID          string             `bson:"device_id"`
    ViolationType     int32              `bson:"violation_type"`         // 1-截图，2-录屏，3-转发
    ViolationTime     int64              `bson:"violation_time"`
    Evidence          string             `bson:"evidence"`               // 证据（如截图检测结果）
    Notified          bool               `bson:"notified"`               // 是否已通知对方
}
```

#### 3.1.2 前端本地模型
```go
// pkg/db/model_struct/data_model_struct.go
type LocalChatLog struct {
    // ... 现有字段 ...
    
    // 阅后即焚字段
    BurnConfig        string             `gorm:"column:burn_config;type:text"`      // JSON格式配置
    BurnStatus        int32              `gorm:"column:burn_status;default:0"`      // 燃烧状态
    BurnStartTime     int64              `gorm:"column:burn_start_time;default:0"`  // 燃烧开始时间
    BurnDeadline      int64              `gorm:"column:burn_deadline;default:0"`    // 燃烧截止时间
    LocalBurnTimer    int64              `gorm:"column:local_burn_timer;default:0"` // 本地计时器
    IsLocalDeleted    bool               `gorm:"column:is_local_deleted;default:false"` // 本地已删除
    DeleteProof       string             `gorm:"column:delete_proof;type:text"`     // 删除证明
    OriginalContent   string             `gorm:"column:original_content;type:text"` // 原始内容备份（加密）
}

// 会话燃烧配置
type LocalConversationBurnConfig struct {
    ConversationID    string             `gorm:"column:conversation_id;primary_key;type:varchar(128)"`
    DefaultEnabled    bool               `gorm:"column:default_enabled;default:false"`
    DefaultDuration   int32              `gorm:"column:default_duration;default:300"`      // 默认5分钟
    DefaultTrigger    int32              `gorm:"column:default_trigger;default:2"`         // 默认阅读后
    AllowedDurations  string             `gorm:"column:allowed_durations;type:text"`       // JSON数组
    AdminOnly         bool               `gorm:"column:admin_only;default:false"`          // 仅管理员可设置
    UpdateTime        int64              `gorm:"column:update_time"`
}
```

### 3.2 配置模型

```go
// pkg/common/config/config.go
type BurnAfterReadConfig struct {
    Enabled           bool               `yaml:"enabled"`
    DefaultSettings   DefaultSettings    `yaml:"defaultSettings"`
    SecuritySettings  SecuritySettings   `yaml:"securitySettings"`
    ComplianceSettings ComplianceSettings `yaml:"complianceSettings"`
    PerformanceSettings PerformanceSettings `yaml:"performanceSettings"`
}

type DefaultSettings struct {
    Duration          int32              `yaml:"duration"`               // 默认时长（秒）
    TriggerMode       int32              `yaml:"triggerMode"`            // 默认触发模式
    DeleteMode        int32              `yaml:"deleteMode"`             // 默认删除模式
    ScreenshotAlert   bool               `yaml:"screenshotAlert"`        // 默认截图提醒
    PreviewEnabled    bool               `yaml:"previewEnabled"`         // 默认预览开关
}

type SecuritySettings struct {
    MinDuration       int32              `yaml:"minDuration"`            // 最小时长
    MaxDuration       int32              `yaml:"maxDuration"`            // 最大时长
    EncryptionRequired bool             `yaml:"encryptionRequired"`     // 是否必须加密
    AntiScreenshot    bool               `yaml:"antiScreenshot"`         // 防截图
    AntiDebug         bool               `yaml:"antiDebug"`              // 防调试
    SecureDelete      bool               `yaml:"secureDelete"`           // 安全删除
    MemoryProtection  bool               `yaml:"memoryProtection"`       // 内存保护
}

type ComplianceSettings struct {
    AuditEnabled      bool               `yaml:"auditEnabled"`           // 审计日志
    RetentionEnabled  bool               `yaml:"retentionEnabled"`       // 法务保留
    RetentionDays     int32              `yaml:"retentionDays"`          // 保留天数
    AutoReport        bool               `yaml:"autoReport"`             // 自动报告
    ExportFormat      string             `yaml:"exportFormat"`           // 导出格式
}

type PerformanceSettings struct {
    CleanupInterval   int32              `yaml:"cleanupInterval"`        // 清理间隔（秒）
    BatchSize         int32              `yaml:"batchSize"`              // 批处理大小
    CacheSize         int32              `yaml:"cacheSize"`              // 缓存大小
    MaxConcurrent     int32              `yaml:"maxConcurrent"`          // 最大并发数
}
```

## 四、API接口设计

### 4.1 REST API

#### 4.1.1 消息相关接口
```go
// internal/api/msg.go

// 发送阅后即焚消息
type SendBurnMessageReq struct {
    apistruct.SendMsg
    BurnConfig *BurnConfig `json:"burnConfig"`
}

type SendBurnMessageResp struct {
    ServerMsgID   string `json:"serverMsgID"`
    ClientMsgID   string `json:"clientMsgID"`
    SendTime      int64  `json:"sendTime"`
    BurnDeadline  int64  `json:"burnDeadline,omitempty"`
}

// 批量发送阅后即焚消息
type BatchSendBurnMessageReq struct {
    Messages      []SendBurnMessageReq `json:"messages"`
    BurnConfig    *BurnConfig          `json:"burnConfig"` // 统一配置
}

// 获取消息燃烧状态
type GetBurnStatusReq struct {
    ConversationID string   `json:"conversationID"`
    MessageIDs     []string `json:"messageIDs"`
}

type GetBurnStatusResp struct {
    BurnStates map[string]*BurnState `json:"burnStates"`
}

// 手动触发燃烧
type TriggerBurnReq struct {
    ConversationID string   `json:"conversationID"`
    MessageIDs     []string `json:"messageIDs"`
    Reason         string   `json:"reason"`
}

// 设置消息保留
type SetMessageRetentionReq struct {
    ConversationID string `json:"conversationID"`
    MessageID      string `json:"messageID"`
    Reason         string `json:"reason"`
    Duration       int32  `json:"duration"` // 保留天数
    Operator       string `json:"operator"`
}
```

#### 4.1.2 会话配置接口
```go
// 设置会话阅后即焚配置
type SetConversationBurnConfigReq struct {
    ConversationID string      `json:"conversationID"`
    BurnConfig     *BurnConfig `json:"burnConfig"`
}

// 获取会话阅后即焚配置
type GetConversationBurnConfigReq struct {
    ConversationIDs []string `json:"conversationIDs"`
}

type GetConversationBurnConfigResp struct {
    Configs map[string]*BurnConfig `json:"configs"`
}

// 批量设置用户默认配置
type SetUserDefaultBurnConfigReq struct {
    UserID     string      `json:"userID"`
    BurnConfig *BurnConfig `json:"burnConfig"`
}
```

#### 4.1.3 合规管理接口
```go
// 获取审计日志
type GetBurnAuditLogReq struct {
    ConversationID string `json:"conversationID,omitempty"`
    UserID         string `json:"userID,omitempty"`
    StartTime      int64  `json:"startTime"`
    EndTime        int64  `json:"endTime"`
    EventType      int32  `json:"eventType,omitempty"` // 事件类型筛选
    PageNum        int32  `json:"pageNum"`
    PageSize       int32  `json:"pageSize"`
}

type GetBurnAuditLogResp struct {
    Logs     []*BurnAuditLog `json:"logs"`
    Total    int64           `json:"total"`
    PageNum  int32           `json:"pageNum"`
    PageSize int32           `json:"pageSize"`
}

// 导出合规报告
type ExportComplianceReportReq struct {
    StartTime  int64  `json:"startTime"`
    EndTime    int64  `json:"endTime"`
    Format     string `json:"format"`     // json/csv/pdf
    ReportType string `json:"reportType"` // summary/detail/violation
}

// 设置法务保留
type SetLegalHoldReq struct {
    ConversationID string   `json:"conversationID"`
    MessageIDs     []string `json:"messageIDs,omitempty"` // 为空则保留整个会话
    Reason         string   `json:"reason"`
    Duration       int32    `json:"duration"` // 保留天数
    Operator       string   `json:"operator"`
    CaseNumber     string   `json:"caseNumber,omitempty"`
}
```

### 4.2 RPC接口

#### 4.2.1 核心消息RPC
```protobuf
// protocol/msg/msg.proto

service msg {
    // 发送阅后即焚消息
    rpc SendBurnAfterReadMsg(SendBurnAfterReadMsgReq) returns (SendBurnAfterReadMsgResp);
    
    // 触发消息燃烧
    rpc TriggerMessageBurn(TriggerMessageBurnReq) returns (TriggerMessageBurnResp);
    
    // 获取过期的阅后即焚消息
    rpc GetExpiredBurnMessages(GetExpiredBurnMessagesReq) returns (GetExpiredBurnMessagesResp);
    
    // 删除阅后即焚消息
    rpc DeleteBurnAfterReadMsg(DeleteBurnAfterReadMsgReq) returns (DeleteBurnAfterReadMsgResp);
    
    // 获取燃烧状态
    rpc GetBurnStatus(GetBurnStatusReq) returns (GetBurnStatusResp);
    
    // 设置消息保留
    rpc SetMessageRetention(SetMessageRetentionReq) returns (SetMessageRetentionResp);
    
    // 记录燃烧违规
    rpc RecordBurnViolation(RecordBurnViolationReq) returns (RecordBurnViolationResp);
}

message SendBurnAfterReadMsgReq {
    MsgData msgData = 1;
    BurnConfig burnConfig = 2;
}

message TriggerMessageBurnReq {
    string conversationID = 1;
    repeated int64 seqs = 2;
    string triggerUser = 3;
    int32 triggerType = 4; // 1-阅读触发，2-手动触发，3-定时触发
}

message GetExpiredBurnMessagesReq {
    int64 currentTime = 1;
    int32 limit = 2;
    string lastMessageID = 3; // 分页游标
}

message GetExpiredBurnMessagesResp {
    repeated ExpiredBurnMessage messages = 1;
    string nextCursor = 2;
    bool hasMore = 3;
}

message ExpiredBurnMessage {
    string conversationID = 1;
    int64 seq = 2;
    string serverMsgID = 3;
    BurnState burnState = 4;
}
```

#### 4.2.2 会话配置RPC
```protobuf
// protocol/conversation/conversation.proto

service conversation {
    // 设置会话燃烧配置
    rpc SetConversationBurnConfig(SetConversationBurnConfigReq) returns (SetConversationBurnConfigResp);
    
    // 获取会话燃烧配置
    rpc GetConversationBurnConfig(GetConversationBurnConfigReq) returns (GetConversationBurnConfigResp);
    
    // 批量更新燃烧配置
    rpc BatchUpdateBurnConfig(BatchUpdateBurnConfigReq) returns (BatchUpdateBurnConfigResp);
}

message SetConversationBurnConfigReq {
    string conversationID = 1;
    BurnConfig burnConfig = 2;
    repeated string userIDs = 3; // 影响的用户列表
}
```

### 4.3 WebSocket推送消息

```protobuf
// protocol/sdkws/ws.proto

// 燃烧开始通知
message BurnStartNotification {
    string conversationID = 1;
    int64 seq = 2;
    string clientMsgID = 3;
    int64 burnDeadline = 4;
    repeated string affectedUsers = 5; // 受影响的用户
}

// 燃烧状态更新
message BurnStatusUpdateNotification {
    string conversationID = 1;
    int64 seq = 2;
    string clientMsgID = 3;
    BurnState burnState = 4;
}

// 燃烧删除通知
message BurnDeleteNotification {
    string conversationID = 1;
    int64 seq = 2;
    string clientMsgID = 3;
    int32 deleteReason = 4; // 1-正常过期，2-手动删除，3-违规删除
    string deleteProof = 5; // 删除证明
}

// 燃烧违规通知
message BurnViolationNotification {
    string conversationID = 1;
    string violatorUserID = 2;
    int32 violationType = 3; // 1-截图，2-录屏，3-转发尝试
    int64 violationTime = 4;
    string evidence = 5;
}

// 燃烧配置变更通知
message BurnConfigChangeNotification {
    string conversationID = 1;
    BurnConfig newConfig = 2;
    string operatorUserID = 3;
    int64 changeTime = 4;
}
```

## 五、后端核心实现

### 5.1 燃烧协调器（Burn Coordinator）

```go
// internal/rpc/msg/burn_coordinator.go
package msg

import (
    "context"
    "sync"
    "time"
    
    "github.com/openimsdk/tools/log"
    "github.com/openimsdk/protocol/msg"
)

type BurnCoordinator struct {
    msgDatabase    database.MsgDatabase
    conversationRpc rpc.ConversationRpcClient
    notificationSender notification.MsgNotificationSender
    
    // 燃烧任务管理
    burnTasks      sync.Map // map[string]*BurnTask
    taskQueue      chan *BurnTask
    workerPool     *sync.WaitGroup
    
    // 配置
    config         *config.BurnAfterReadConfig
    
    ctx            context.Context
    cancel         context.CancelFunc
}

type BurnTask struct {
    MessageID      string
    ConversationID string
    Seq            int64
    DeadlineTime   int64
    RetryCount     int32
    CreatedAt      int64
}

// 初始化燃烧协调器
func NewBurnCoordinator(msgDB database.MsgDatabase, config *config.BurnAfterReadConfig) *BurnCoordinator {
    ctx, cancel := context.WithCancel(context.Background())
    
    bc := &BurnCoordinator{
        msgDatabase:    msgDB,
        config:         config,
        taskQueue:      make(chan *BurnTask, config.PerformanceSettings.CacheSize),
        workerPool:     &sync.WaitGroup{},
        ctx:           ctx,
        cancel:        cancel,
    }
    
    // 启动工作协程
    for i := 0; i < int(config.PerformanceSettings.MaxConcurrent); i++ {
        bc.workerPool.Add(1)
        go bc.burnWorker()
    }
    
    // 启动定时清理任务
    go bc.scheduleCleanup()
    
    return bc
}

// 添加燃烧任务
func (bc *BurnCoordinator) AddBurnTask(ctx context.Context, messageID, conversationID string, seq, deadlineTime int64) error {
    task := &BurnTask{
        MessageID:      messageID,
        ConversationID: conversationID,
        Seq:           seq,
        DeadlineTime:  deadlineTime,
        RetryCount:    0,
        CreatedAt:     time.Now().Unix(),
    }
    
    // 存储任务
    bc.burnTasks.Store(messageID, task)
    
    // 计算延迟时间
    delay := deadlineTime - time.Now().Unix()
    if delay <= 0 {
        // 立即执行
        select {
        case bc.taskQueue <- task:
        default:
            log.ZWarn(ctx, "burn task queue full", nil, "messageID", messageID)
        }
    } else {
        // 延迟执行
        go func() {
            timer := time.NewTimer(time.Duration(delay) * time.Second)
            defer timer.Stop()
            
            select {
            case <-timer.C:
                select {
                case bc.taskQueue <- task:
                default:
                    log.ZWarn(ctx, "burn task queue full after delay", nil, "messageID", messageID)
                }
            case <-bc.ctx.Done():
                return
            }
        }()
    }
    
    return nil
}

// 燃烧工作协程
func (bc *BurnCoordinator) burnWorker() {
    defer bc.workerPool.Done()
    
    for {
        select {
        case task := <-bc.taskQueue:
            bc.processBurnTask(context.Background(), task)
        case <-bc.ctx.Done():
            return
        }
    }
}

// 处理燃烧任务
func (bc *BurnCoordinator) processBurnTask(ctx context.Context, task *BurnTask) {
    // 检查消息是否还存在
    msg, err := bc.msgDatabase.GetMsgBySeq(ctx, task.ConversationID, task.Seq)
    if err != nil {
        log.ZWarn(ctx, "message not found for burn task", err, "messageID", task.MessageID)
        bc.burnTasks.Delete(task.MessageID)
        return
    }
    
    // 检查燃烧状态
    if msg.BurnState == nil || msg.BurnState.Status == 2 { // 已销毁
        bc.burnTasks.Delete(task.MessageID)
        return
    }
    
    // 检查是否有法务保留
    if msg.BurnState.RetentionReason != "" {
        log.ZInfo(ctx, "message retained for legal reasons", "messageID", task.MessageID, "reason", msg.BurnState.RetentionReason)
        bc.burnTasks.Delete(task.MessageID)
        return
    }
    
    // 执行删除
    err = bc.executeMessageDeletion(ctx, msg)
    if err != nil {
        // 重试逻辑
        task.RetryCount++
        if task.RetryCount < 3 {
            log.ZWarn(ctx, "burn task failed, retrying", err, "messageID", task.MessageID, "retryCount", task.RetryCount)
            // 延迟重试
            go func() {
                time.Sleep(time.Duration(task.RetryCount*30) * time.Second)
                select {
                case bc.taskQueue <- task:
                case <-bc.ctx.Done():
                }
            }()
            return
        } else {
            log.ZError(ctx, "burn task failed after retries", err, "messageID", task.MessageID)
        }
    }
    
    // 清理任务
    bc.burnTasks.Delete(task.MessageID)
}

// 执行消息删除
func (bc *BurnCoordinator) executeMessageDeletion(ctx context.Context, msg *model_struct.MsgDataModel) error {
    // 1. 更新消息状态为已销毁
    updateData := map[string]interface{}{
        "burn_state.status": 2,
        "burn_state.deleted_devices": []string{}, // 将在客户端确认后填充
    }
    
    err := bc.msgDatabase.UpdateMessage(ctx, msg.ConversationID, msg.Seq, updateData)
    if err != nil {
        return err
    }
    
    // 2. 记录删除日志
    deleteLog := &DeleteLog{
        UserID:     "system",
        DeviceID:   "server",
        DeleteTime: time.Now().Unix(),
        DeleteType: 1, // 自动删除
        Success:    true,
    }
    
    if msg.BurnAudit == nil {
        msg.BurnAudit = &BurnAudit{}
    }
    msg.BurnAudit.DeleteLogs = append(msg.BurnAudit.DeleteLogs, deleteLog)
    
    // 3. 发送删除通知给所有相关用户
    notification := &sdkws.BurnDeleteNotification{
        ConversationID: msg.ConversationID,
        Seq:           msg.Seq,
        ClientMsgID:   msg.ClientMsgID,
        DeleteReason:  1, // 正常过期
        DeleteProof:   bc.generateDeleteProof(msg),
    }
    
    // 获取会话成员
    userIDs, err := bc.getConversationUserIDs(ctx, msg.ConversationID)
    if err != nil {
        log.ZWarn(ctx, "failed to get conversation users", err, "conversationID", msg.ConversationID)
        return err
    }
    
    // 发送通知
    for _, userID := range userIDs {
        err := bc.notificationSender.BurnDeleteNotification(ctx, userID, notification)
        if err != nil {
            log.ZWarn(ctx, "failed to send burn delete notification", err, "userID", userID)
        }
    }
    
    // 4. 延迟物理删除（给客户端确认删除的时间）
    go func() {
        time.Sleep(5 * time.Minute) // 等待5分钟
        bc.physicalDeleteMessage(context.Background(), msg.ConversationID, msg.Seq)
    }()
    
    return nil
}

// 物理删除消息
func (bc *BurnCoordinator) physicalDeleteMessage(ctx context.Context, conversationID string, seq int64) error {
    return bc.msgDatabase.DeleteMsgsPhysicalBySeqs(ctx, conversationID, []int64{seq})
}

// 生成删除证明
func (bc *BurnCoordinator) generateDeleteProof(msg *model_struct.MsgDataModel) string {
    // 生成包含消息元数据的删除证明（不包含内容）
    proof := map[string]interface{}{
        "message_id":       msg.ServerMsgID,
        "conversation_id":  msg.ConversationID,
        "seq":             msg.Seq,
        "delete_time":     time.Now().Unix(),
        "burn_config":     msg.BurnConfig,
        "checksum":        bc.calculateMessageChecksum(msg),
    }
    
    // 转为JSON并签名
    proofBytes, _ := json.Marshal(proof)
    signature := bc.signDeleteProof(proofBytes)
    
    return base64.StdEncoding.EncodeToString(append(proofBytes, signature...))
}

// 定时清理任务
func (bc *BurnCoordinator) scheduleCleanup() {
    ticker := time.NewTicker(time.Duration(bc.config.PerformanceSettings.CleanupInterval) * time.Second)
    defer ticker.Stop()
    
    for {
        select {
        case <-ticker.C:
            bc.cleanupExpiredTasks(context.Background())
        case <-bc.ctx.Done():
            return
        }
    }
}

// 清理过期任务
func (bc *BurnCoordinator) cleanupExpiredTasks(ctx context.Context) {
    now := time.Now().Unix()
    var expiredKeys []string
    
    bc.burnTasks.Range(func(key, value interface{}) bool {
        task := value.(*BurnTask)
        if now > task.DeadlineTime+3600 { // 超期1小时的任务
            expiredKeys = append(expiredKeys, key.(string))
        }
        return true
    })
    
    for _, key := range expiredKeys {
        bc.burnTasks.Delete(key)
        log.ZDebug(ctx, "cleaned up expired burn task", "messageID", key)
    }
}
```

### 5.2 消息阅读处理

```go
// internal/rpc/msg/as_read.go - 增强版阅读处理
func (m *msgServer) MarkMsgsAsRead(ctx context.Context, req *msg.MarkMsgsAsReadReq) (*msg.MarkMsgsAsReadResp, error) {
    // 权限检查
    if err := authverify.CheckAccess(ctx, req.UserID); err != nil {
        return nil, err
    }
    
    // 现有的标记已读逻辑
    // ...existing code...
    
    // 新增：处理阅后即焚消息
    err := m.processBurnAfterReadMessages(ctx, req)
    if err != nil {
        log.ZWarn(ctx, "failed to process burn after read messages", err)
        // 不阻断正常的已读标记流程
    }
    
    return &msg.MarkMsgsAsReadResp{}, nil
}

// 处理阅后即焚消息
func (m *msgServer) processBurnAfterReadMessages(ctx context.Context, req *msg.MarkMsgsAsReadReq) error {
    for _, seq := range req.Seqs {
        msg, err := m.MsgDatabase.GetMsgBySeq(ctx, req.ConversationID, seq)
        if err != nil {
            continue
        }
        
        // 检查是否为阅后即焚消息
        if msg.BurnConfig == nil || !msg.BurnConfig.Enabled {
            continue
        }
        
        // 检查触发模式
        if msg.BurnConfig.TriggerMode != 2 { // 2表示阅读后触发
            continue
        }
        
        // 检查燃烧状态
        if msg.BurnState == nil {
            msg.BurnState = &BurnState{
                Status:         0,
                ReadUserStates: make(map[string]*ReadState),
            }
        }
        
        // 更新用户阅读状态
        userReadState := &ReadState{
            UserID:        req.UserID,
            ReadTime:      time.Now().Unix(),
            DeviceID:      req.DeviceID,
            LocalDeleted:  false,
        }
        
        // 计算个人燃烧时间
        if msg.BurnConfig.TriggerMode == 2 { // 阅读后触发
            userReadState.BurnStartTime = userReadState.ReadTime
            userReadState.BurnDeadline = userReadState.ReadTime + int64(msg.BurnConfig.Duration)
        }
        
        msg.BurnState.ReadUserStates[req.UserID] = userReadState
        
        // 记录阅读日志
        readLog := &ReadLog{
            UserID:    req.UserID,
            DeviceID:  req.DeviceID,
            ReadTime:  userReadState.ReadTime,
            IPAddress: getClientIP(ctx),
            UserAgent: getUserAgent(ctx),
        }
        
        if msg.BurnAudit == nil {
            msg.BurnAudit = &BurnAudit{
                CreateTime: msg.CreateTime,
                CreatorID:  msg.SendID,
            }
        }
        msg.BurnAudit.ReadLogs = append(msg.BurnAudit.ReadLogs, readLog)
        
        // 确定全局燃烧时间
        globalDeadline := m.calculateGlobalBurnDeadline(ctx, msg)
        
        if msg.BurnState.Status == 0 { // 首次触发
            msg.BurnState.Status = 1 // 燃烧中
            msg.BurnState.StartTime = time.Now().Unix()
            msg.BurnState.DeadlineTime = globalDeadline
            
            // 添加到燃烧协调器
            err = m.burnCoordinator.AddBurnTask(ctx, msg.ServerMsgID, msg.ConversationID, msg.Seq, globalDeadline)
            if err != nil {
                log.ZError(ctx, "failed to add burn task", err, "messageID", msg.ServerMsgID)
            }
        }
        
        // 更新数据库
        updateData := map[string]interface{}{
            "burn_state":  msg.BurnState,
            "burn_audit":  msg.BurnAudit,
        }
        
        err = m.MsgDatabase.UpdateMessage(ctx, req.ConversationID, seq, updateData)
        if err != nil {
            log.ZError(ctx, "failed to update burn message state", err, "seq", seq)
            continue
        }
        
        // 发送燃烧开始通知
        if msg.BurnState.Status == 1 {
            notification := &sdkws.BurnStartNotification{
                ConversationID: req.ConversationID,
                Seq:           seq,
                ClientMsgID:   msg.ClientMsgID,
                BurnDeadline:  userReadState.BurnDeadline,
                AffectedUsers: []string{req.UserID},
            }
            
            // 通知阅读者
            m.notificationSender.BurnStartNotification(ctx, req.UserID, notification)
            
            // 根据配置决定是否通知发送者
            if msg.BurnConfig.ScreenshotAlert {
                notification.AffectedUsers = []string{msg.SendID}
                m.notificationSender.BurnStartNotification(ctx, msg.SendID, notification)
            }
        }
    }
    
    return nil
}

// 计算全局燃烧截止时间
func (m *msgServer) calculateGlobalBurnDeadline(ctx context.Context, msg *model_struct.MsgDataModel) int64 {
    switch msg.BurnConfig.TriggerMode {
    case 1: // 发送后触发
        return msg.SendTime/1000 + int64(msg.BurnConfig.Duration)
        
    case 2: // 阅读后触发
        // 找到最早的阅读时间
        var earliestReadTime int64 = math.MaxInt64
        for _, readState := range msg.BurnState.ReadUserStates {
            if readState.ReadTime > 0 && readState.ReadTime < earliestReadTime {
                earliestReadTime = readState.ReadTime
            }
        }
        
        if earliestReadTime == math.MaxInt64 {
            return time.Now().Unix() + int64(msg.BurnConfig.Duration)
        }
        
        return earliestReadTime + int64(msg.BurnConfig.Duration)
        
    default:
        return time.Now().Unix() + int64(msg.BurnConfig.Duration)
    }
}
```

### 5.3 定时清理服务

```go
// internal/tools/cron/burn_cleanup.go
package cron

import (
    "context"
    "time"
    
    "github.com/openimsdk/tools/log"
    "github.com/openimsdk/tools/mcontext"
)

// 阅后即焚清理任务
func (c *cronServer) cleanupBurnAfterReadMessages() {
    ctx := mcontext.SetOperationID(c.ctx, "burn_cleanup_"+time.Now().Format("20060102150405"))
    log.ZInfo(ctx, "starting burn after read cleanup task")
    
    startTime := time.Now()
    
    // 1. 清理过期的燃烧消息
    deletedCount, err := c.cleanupExpiredBurnMessages(ctx)
    if err != nil {
        log.ZError(ctx, "failed to cleanup expired burn messages", err)
    } else {
        log.ZInfo(ctx, "cleaned up expired burn messages", "count", deletedCount)
    }
    
    // 2. 清理孤儿燃烧任务
    taskCount, err := c.cleanupOrphanBurnTasks(ctx)
    if err != nil {
        log.ZError(ctx, "failed to cleanup orphan burn tasks", err)
    } else {
        log.ZInfo(ctx, "cleaned up orphan burn tasks", "count", taskCount)
    }
    
    // 3. 压缩审计日志
    compressedCount, err := c.compressBurnAuditLogs(ctx)
    if err != nil {
        log.ZError(ctx, "failed to compress burn audit logs", err)
    } else {
        log.ZInfo(ctx, "compressed burn audit logs", "count", compressedCount)
    }
    
    elapsed := time.Since(startTime)
    log.ZInfo(ctx, "burn cleanup task completed", 
        "duration", elapsed,
        "deleted_messages", deletedCount,
        "cleaned_tasks", taskCount, 
        "compressed_logs", compressedCount)
}

// 清理过期的燃烧消息
func (c *cronServer) cleanupExpiredBurnMessages(ctx context.Context) (int64, error) {
    const batchSize = 1000
    var totalDeleted int64
    
    for {
        // 获取过期消息
        resp, err := c.msgClient.GetExpiredBurnMessages(ctx, &msg.GetExpiredBurnMessagesReq{
            CurrentTime: time.Now().Unix(),
            Limit:      batchSize,
        })
        
        if err != nil {
            return totalDeleted, err
        }
        
        if len(resp.Messages) == 0 {
            break
        }
        
        // 批量删除
        for _, expiredMsg := range resp.Messages {
            err := c.deleteBurnMessage(ctx, expiredMsg)
            if err != nil {
                log.ZWarn(ctx, "failed to delete expired burn message", err, 
                    "messageID", expiredMsg.ServerMsgID)
                continue
            }
            totalDeleted++
        }
        
        if !resp.HasMore {
            break
        }
    }
    
    return totalDeleted, nil
}

// 删除单个燃烧消息
func (c *cronServer) deleteBurnMessage(ctx context.Context, expiredMsg *msg.ExpiredBurnMessage) error {
    // 检查是否有法务保留
    if expiredMsg.BurnState.RetentionReason != "" {
        log.ZInfo(ctx, "message retained for legal reasons", 
            "messageID", expiredMsg.ServerMsgID,
            "reason", expiredMsg.BurnState.RetentionReason)
        return nil
    }
    
    // 物理删除消息
    _, err := c.msgClient.DeleteMsgPhysicalBySeq(ctx, &msg.DeleteMsgPhysicalBySeqReq{
        ConversationID: expiredMsg.ConversationID,
        Seqs:          []int64{expiredMsg.Seq},
    })
    
    if err != nil {
        return err
    }
    
    // 发送删除通知
    return c.sendBurnDeleteNotification(ctx, expiredMsg)
}

// 发送燃烧删除通知
func (c *cronServer) sendBurnDeleteNotification(ctx context.Context, expiredMsg *msg.ExpiredBurnMessage) error {
    // 获取会话成员
    userIDs, err := c.getConversationUserIDs(ctx, expiredMsg.ConversationID)
    if err != nil {
        return err
    }
    
    notification := &sdkws.BurnDeleteNotification{
        ConversationID: expiredMsg.ConversationID,
        Seq:           expiredMsg.Seq,
        DeleteReason:  1, // 正常过期
        DeleteProof:   c.generateDeleteProof(expiredMsg),
    }
    
    // 并发发送通知
    errChan := make(chan error, len(userIDs))
    for _, userID := range userIDs {
        go func(uid string) {
            err := c.notificationSender.BurnDeleteNotification(ctx, uid, notification)
            errChan <- err
        }(userID)
    }
    
    // 收集错误
    var errors []error
    for i := 0; i < len(userIDs); i++ {
        if err := <-errChan; err != nil {
            errors = append(errors, err)
        }
    }
    
    if len(errors) > 0 {
        log.ZWarn(ctx, "some notifications failed", nil, "errors", len(errors))
    }
    
    return nil
}
```

## 六、前端SDK实现

### 6.1 燃烧管理器

```go
// internal/conversation_msg/burn_manager.go
package conversation_msg

import (
    "context"
    "encoding/json"
    "fmt"
    "sync"
    "time"
    
    "github.com/openimsdk/openim-sdk-core/v3/pkg/db/model_struct"
    "github.com/openimsdk/tools/log"
)

type BurnManager struct {
    db                  database.DataBase
    conversationManager *Conversation
    
    // 本地定时器管理
    burnTimers          sync.Map // map[string]*time.Timer
    timerMutex          sync.RWMutex
    
    // 配置
    config              *BurnConfig
    
    ctx                 context.Context
    cancel              context.CancelFunc
}

type LocalBurnTimer struct {
    MessageID           string
    ConversationID      string
    ClientMsgID         string
    DeadlineTime        int64
    Timer              *time.Timer
    CreatedAt          int64
}

func NewBurnManager(db database.DataBase, conv *Conversation) *BurnManager {
    ctx, cancel := context.WithCancel(context.Background())
    
    bm := &BurnManager{
        db:                  db,
        conversationManager: conv,
        ctx:                ctx,
        cancel:             cancel,
    }
    
    // 启动时恢复定时器
    go bm.restoreBurnTimers()
    
    return bm
}

// 恢复本地燃烧定时器
func (bm *BurnManager) restoreBurnTimers() {
    ctx := context.Background()
    
    // 获取所有燃烧中的消息
    messages, err := bm.db.GetBurningMessages(ctx)
    if err != nil {
        log.ZError(ctx, "failed to get burning messages", err)
        return
    }
    
    now := time.Now().Unix()
    
    for _, msg := range messages {
        if msg.BurnDeadline <= now {
            // 已过期，立即删除
            bm.executeLocalDelete(ctx, msg.ConversationID, msg.ClientMsgID)
        } else {
            // 创建定时器
            bm.createBurnTimer(ctx, msg)
        }
    }
}

// 创建燃烧定时器
func (bm *BurnManager) createBurnTimer(ctx context.Context, msg *model_struct.LocalChatLog) {
    now := time.Now().Unix()
    delay := msg.BurnDeadline - now
    
    if delay <= 0 {
        // 立即删除
        bm.executeLocalDelete(ctx, msg.ConversationID, msg.ClientMsgID)
        return
    }
    
    timer := time.NewTimer(time.Duration(delay) * time.Second)
    
    localTimer := &LocalBurnTimer{
        MessageID:      fmt.Sprintf("%s_%s", msg.ConversationID, msg.ClientMsgID),
        ConversationID: msg.ConversationID,
        ClientMsgID:    msg.ClientMsgID,
        DeadlineTime:   msg.BurnDeadline,
        Timer:         timer,
        CreatedAt:     now,
    }
    
    // 存储定时器
    bm.burnTimers.Store(localTimer.MessageID, localTimer)
    
    // 启动定时器协程
    go func() {
        select {
        case <-timer.C:
            // 时间到，执行删除
            bm.executeLocalDelete(context.Background(), msg.ConversationID, msg.ClientMsgID)
            bm.burnTimers.Delete(localTimer.MessageID)
            
        case <-bm.ctx.Done():
            // 取消定时器
            timer.Stop()
            bm.burnTimers.Delete(localTimer.MessageID)
        }
    }()
    
    log.ZDebug(ctx, "created burn timer", 
        "messageID", localTimer.MessageID,
        "delay", delay)
}

// 执行本地删除
func (bm *BurnManager) executeLocalDelete(ctx context.Context, conversationID, clientMsgID string) error {
    log.ZInfo(ctx, "executing local burn delete", 
        "conversationID", conversationID,
        "clientMsgID", clientMsgID)
    
    // 1. 获取原始消息
    msg, err := bm.db.GetMessage(ctx, conversationID, clientMsgID)
    if err != nil {
        log.ZWarn(ctx, "message not found for burn delete", err, "clientMsgID", clientMsgID)
        return err
    }
    
    // 2. 备份原始内容（加密存储）
    originalContent, _ := bm.encryptContent(msg.Content)
    
    // 3. 更新消息内容
    msg.Content = "[消息已焚毁]"
    msg.IsLocalDeleted = true
    msg.DeleteProof = bm.generateLocalDeleteProof(msg)
    msg.OriginalContent = originalContent
    
    // 4. 更新数据库
    err = bm.db.UpdateMessage(ctx, msg)
    if err != nil {
        log.ZError(ctx, "failed to update burned message", err, "clientMsgID", clientMsgID)
        return err
    }
    
    // 5. 清理相关文件（如图片、视频等）
    bm.cleanupMessageFiles(ctx, msg)
    
    // 6. 内存清理
    bm.secureMemoryClean(msg)
    
    // 7. 通知UI更新
    bm.notifyUIBurnDelete(conversationID, clientMsgID)
    
    // 8. 记录本地删除日志
    bm.recordLocalDeleteLog(ctx, msg)
    
    log.ZInfo(ctx, "local burn delete completed", "clientMsgID", clientMsgID)
    return nil
}

// 处理服务端燃烧通知
func (bm *BurnManager) HandleServerBurnNotification(ctx context.Context, notification interface{}) {
    switch notif := notification.(type) {
    case *sdkws.BurnStartNotification:
        bm.handleBurnStartNotification(ctx, notif)
        
    case *sdkws.BurnDeleteNotification:
        bm.handleBurnDeleteNotification(ctx, notif)
        
    case *sdkws.BurnStatusUpdateNotification:
        bm.handleBurnStatusUpdate(ctx, notif)
        
    case *sdkws.BurnViolationNotification:
        bm.handleBurnViolationNotification(ctx, notif)
    }
}

// 处理燃烧开始通知
func (bm *BurnManager) handleBurnStartNotification(ctx context.Context, notif *sdkws.BurnStartNotification) {
    log.ZInfo(ctx, "received burn start notification", 
        "conversationID", notif.ConversationID,
        "clientMsgID", notif.ClientMsgID,
        "deadline", notif.BurnDeadline)
    
    // 获取本地消息
    msg, err := bm.db.GetMessage(ctx, notif.ConversationID, notif.ClientMsgID)
    if err != nil {
        log.ZError(ctx, "message not found for burn start", err, "clientMsgID", notif.ClientMsgID)
        return
    }
    
    // 更新燃烧状态
    msg.BurnStatus = 1 // 燃烧中
    msg.BurnStartTime = time.Now().Unix()
    msg.BurnDeadline = notif.BurnDeadline
    
    err = bm.db.UpdateMessage(ctx, msg)
    if err != nil {
        log.ZError(ctx, "failed to update burn start state", err)
        return
    }
    
    // 创建本地定时器
    bm.createBurnTimer(ctx, msg)
    
    // 通知UI更新
    bm.notifyUIBurnStart(notif.ConversationID, notif.ClientMsgID, notif.BurnDeadline)
}

// 处理燃烧删除通知
func (bm *BurnManager) handleBurnDeleteNotification(ctx context.Context, notif *sdkws.BurnDeleteNotification) {
    log.ZInfo(ctx, "received burn delete notification", 
        "conversationID", notif.ConversationID,
        "clientMsgID", notif.ClientMsgID)
    
    // 立即执行本地删除
    err := bm.executeLocalDelete(ctx, notif.ConversationID, notif.ClientMsgID)
    if err != nil {
        log.ZError(ctx, "failed to execute local delete from notification", err)
        return
    }
    
    // 取消本地定时器
    messageID := fmt.Sprintf("%s_%s", notif.ConversationID, notif.ClientMsgID)
    if timerInterface, ok := bm.burnTimers.LoadAndDelete(messageID); ok {
        localTimer := timerInterface.(*LocalBurnTimer)
        localTimer.Timer.Stop()
    }
}

// 安全内存清理
func (bm *BurnManager) secureMemoryClean(msg *model_struct.LocalChatLog) {
    // 多次覆盖内存中的敏感内容
    if msg.Content != "" {
        contentBytes := []byte(msg.Content)
        for i := 0; i < 3; i++ {
            for j := range contentBytes {
                contentBytes[j] = 0x00
            }
        }
        msg.Content = ""
    }
    
    // 强制垃圾回收
    runtime.GC()
}

// 清理消息相关文件
func (bm *BurnManager) cleanupMessageFiles(ctx context.Context, msg *model_struct.LocalChatLog) {
    // 解析消息内容，查找文件路径
    var content map[string]interface{}
    json.Unmarshal([]byte(msg.Content), &content)
    
    // 根据消息类型清理不同的文件
    switch msg.ContentType {
    case constant.Picture:
        bm.cleanupPictureFiles(ctx, content)
    case constant.Video:
        bm.cleanupVideoFiles(ctx, content)
    case constant.Voice:
        bm.cleanupVoiceFiles(ctx, content)
    case constant.File:
        bm.cleanupAttachmentFiles(ctx, content)
    }
}

// 发送阅后即焚消息
func (bm *BurnManager) SendBurnMessage(
    ctx context.Context,
    message *sdk_struct.MsgStruct,
    recvID, groupID string,
    burnConfig *BurnConfig,
    operationID string,
) (*sdk_struct.MsgStruct, error) {
    
    // 1. 设置消息的燃烧属性
    burnConfigJSON, _ := json.Marshal(burnConfig)
    message.BurnConfig = string(burnConfigJSON)
    message.BurnStatus = 0 // 未开始
    
    // 2. 如果是发送后触发，设置开始时间
    if burnConfig.TriggerMode == 1 {
        message.BurnStartTime = time.Now().Unix()
        message.BurnDeadline = message.BurnStartTime + int64(burnConfig.Duration)
    }
    
    // 3. 保存到本地数据库
    err := bm.db.InsertMessage(ctx, message)
    if err != nil {
        return nil, err
    }
    
    // 4. 发送到服务器
    resp, err := bm.sendBurnMessageToServer(ctx, message, burnConfig)
    if err != nil {
        // 更新本地消息状态为发送失败
        message.Status = constant.MsgStatusSendFailed
        bm.db.UpdateMessage(ctx, message)
        return nil, err
    }
    
    // 5. 更新本地消息信息
    message.ServerMsgID = resp.ServerMsgID
    message.SendTime = resp.SendTime
    message.Status = constant.MsgStatusSendSuccess
    
    if resp.BurnDeadline > 0 {
        message.BurnDeadline = resp.BurnDeadline
    }
    
    bm.db.UpdateMessage(ctx, message)
    
    // 6. 如果是发送后触发，创建本地定时器
    if burnConfig.TriggerMode == 1 && message.BurnDeadline > 0 {
        bm.createBurnTimer(ctx, message)
    }
    
    return message, nil
}
```

### 6.2 安全防护模块

```go
// internal/conversation_msg/security_guard.go
package conversation_msg

import (
    "context"
    "runtime"
    "time"
    
    "github.com/openimsdk/tools/log"
)

type SecurityGuard struct {
    burnManager     *BurnManager
    
    // 防护配置
    antiScreenshot  bool
    antiDebug      bool
    antiRoot       bool
    
    // 检测状态
    isMonitoring   bool
    violations     []*ViolationRecord
    
    ctx            context.Context
    cancel         context.CancelFunc
}

type ViolationRecord struct {
    Type           int32     // 违规类型
    Time           int64     // 违规时间
    Evidence       string    // 证据
    ConversationID string    // 相关会话
    MessageID      string    // 相关消息
    Reported       bool      // 是否已报告
}

func NewSecurityGuard(burnManager *BurnManager, config SecurityConfig) *SecurityGuard {
    ctx, cancel := context.WithCancel(context.Background())
    
    sg := &SecurityGuard{
        burnManager:    burnManager,
        antiScreenshot: config.AntiScreenshot,
        antiDebug:      config.AntiDebug,
        antiRoot:       config.AntiRoot,
        ctx:           ctx,
        cancel:        cancel,
    }
    
    if config.AntiScreenshot {
        go sg.startScreenshotDetection()
    }
    
    if config.AntiDebug {
        go sg.startDebugDetection()
    }
    
    if config.AntiRoot {
        go sg.startRootDetection()
    }
    
    return sg
}

// 截图检测（平台相关实现）
func (sg *SecurityGuard) startScreenshotDetection() {
    // 注意：实际实现需要根据平台调用相应的系统API
    // 这里提供通用的框架
    
    ticker := time.NewTicker(100 * time.Millisecond)
    defer ticker.Stop()
    
    for {
        select {
        case <-ticker.C:
            if sg.detectScreenshot() {
                sg.handleViolation(context.Background(), ViolationTypeScreenshot, "screenshot detected")
            }
        case <-sg.ctx.Done():
            return
        }
    }
}

// 检测截图（需要平台特定实现）
func (sg *SecurityGuard) detectScreenshot() bool {
    // iOS实现：监听UIApplicationUserDidTakeScreenshotNotification
    // Android实现：监听MediaStore变化或FileObserver
    // Desktop实现：监听剪贴板变化或全局快捷键
    
    // 这里是伪代码，实际需要调用平台API
    return false
}

// 防调试检测
func (sg *SecurityGuard) startDebugDetection() {
    ticker := time.NewTicker(5 * time.Second)
    defer ticker.Stop()
    
    for {
        select {
        case <-ticker.C:
            if sg.detectDebugger() {
                sg.handleViolation(context.Background(), ViolationTypeDebug, "debugger detected")
                // 可以选择退出应用或清理敏感数据
                sg.emergencyCleanup()
            }
        case <-sg.ctx.Done():
            return
        }
    }
}

// 检测调试器
func (sg *SecurityGuard) detectDebugger() bool {
    // 检测调试器是否附加
    // 1. 检查IsDebuggerPresent（Windows）
    // 2. 检查ptrace（Linux/macOS）
    // 3. 检查调试标志
    
    // 简单的Go调试检测
    return false // 实际实现需要平台相关代码
}

// Root/越狱检测
func (sg *SecurityGuard) startRootDetection() {
    // 检测设备是否被Root或越狱
    if sg.detectRootOrJailbreak() {
        sg.handleViolation(context.Background(), ViolationTypeRoot, "rooted/jailbroken device detected")
    }
}

// 检测Root或越狱
func (sg *SecurityGuard) detectRootOrJailbreak() bool {
    // iOS：检查Cydia等越狱应用
    // Android：检查su命令、Magisk等
    // 检查系统文件完整性
    
    return false // 实际实现需要平台相关代码
}

// 处理违规
func (sg *SecurityGuard) handleViolation(ctx context.Context, violationType int32, evidence string) {
    log.ZWarn(ctx, "security violation detected", nil, 
        "type", violationType,
        "evidence", evidence)
    
    violation := &ViolationRecord{
        Type:     violationType,
        Time:     time.Now().Unix(),
        Evidence: evidence,
        Reported: false,
    }
    
    sg.violations = append(sg.violations, violation)
    
    // 报告违规
    go sg.reportViolation(ctx, violation)
    
    // 根据违规类型采取措施
    switch violationType {
    case ViolationTypeScreenshot:
        sg.handleScreenshotViolation(ctx, violation)
    case ViolationTypeDebug:
        sg.handleDebugViolation(ctx, violation)
    case ViolationTypeRoot:
        sg.handleRootViolation(ctx, violation)
    }
}

// 处理截图违规
func (sg *SecurityGuard) handleScreenshotViolation(ctx context.Context, violation *ViolationRecord) {
    // 1. 立即清理敏感内容
    sg.blurSensitiveContent()
    
    // 2. 通知相关用户
    // 获取当前显示的燃烧消息
    currentBurnMessages := sg.getCurrentDisplayedBurnMessages()
    for _, msg := range currentBurnMessages {
        sg.notifyScreenshotViolation(ctx, msg, violation)
    }
    
    // 3. 记录到本地日志
    sg.recordViolationLog(violation)
}

// 应急清理
func (sg *SecurityGuard) emergencyCleanup() {
    log.ZError(context.Background(), "executing emergency cleanup", nil)
    
    // 1. 立即删除所有燃烧中的消息
    sg.burnManager.EmergencyDeleteAllBurnMessages()
    
    // 2. 清理内存中的敏感数据
    runtime.GC()
    
    // 3. 清理临时文件
    sg.cleanupTempFiles()
    
    // 4. 可选：退出应用
    // os.Exit(1)
}

// 内存保护
func (sg *SecurityGuard) ProtectMemory(data []byte) []byte {
    // 在支持的平台上使用内存保护
    // 1. 使用mlock锁定内存页面
    // 2. 设置内存页面为不可执行
    // 3. 使用随机密钥异或加密
    
    // 简单的异或加密示例
    key := sg.generateRandomKey()
    protected := make([]byte, len(data))
    for i, b := range data {
        protected[i] = b ^ key[i%len(key)]
    }
    
    return protected
}

// 安全字符串比较（防止时序攻击）
func (sg *SecurityGuard) SecureStringCompare(a, b string) bool {
    if len(a) != len(b) {
        return false
    }
    
    result := 0
    for i := 0; i < len(a); i++ {
        result |= int(a[i]) ^ int(b[i])
    }
    
    return result == 0
}
```

### 6.3 用户界面集成

```go
// open_im_sdk/conversation_msg.go - UI接口扩展
package open_im_sdk

// 发送阅后即焚消息
func (c *ConversationMsg) SendBurnAfterReadMessage(
    operationID string,
    message string,
    recvID string,
    groupID string,
    burnDuration int32,
    triggerMode int32,
) string {
    
    call := func(ctx context.Context) (string, error) {
        // 解析消息
        var msgStruct sdk_struct.MsgStruct
        err := json.Unmarshal([]byte(message), &msgStruct)
        if err != nil {
            return "", err
        }
        
        // 创建燃烧配置
        burnConfig := &BurnConfig{
            Enabled:        true,
            Duration:       burnDuration,
            TriggerMode:    triggerMode,
            DeleteMode:     2, // 硬删除
            ScreenshotAlert: true,
            ForwardBlocked: true,
        }
        
        // 调用燃烧管理器发送
        result, err := c.burnManager.SendBurnMessage(
            ctx, 
            &msgStruct, 
            recvID, 
            groupID,
            burnConfig,
            operationID,
        )
        
        if err != nil {
            return "", err
        }
        
        // 返回结果
        resultBytes, _ := json.Marshal(result)
        return string(resultBytes), nil
    }
    
    return caller.ExecAsync(c.ctx, call, operationID, c.conversationCH)
}

// 设置会话默认燃烧配置
func (c *ConversationMsg) SetConversationBurnConfig(
    operationID string,
    conversationID string,
    burnConfig string,
) string {
    
    call := func(ctx context.Context) (string, error) {
        // 解析配置
        var config BurnConfig
        err := json.Unmarshal([]byte(burnConfig), &config)
        if err != nil {
            return "", err
        }
        
        // 保存到本地数据库
        localConfig := &model_struct.LocalConversationBurnConfig{
            ConversationID:   conversationID,
            DefaultEnabled:   config.Enabled,
            DefaultDuration:  config.Duration,
            DefaultTrigger:   config.TriggerMode,
            UpdateTime:       time.Now().Unix(),
        }
        
        err = c.db.SetConversationBurnConfig(ctx, localConfig)
        if err != nil {
            return "", err
        }
        
        // 同步到服务器
        apiReq := &api.SetConversationBurnConfigReq{
            ConversationID: conversationID,
            BurnConfig:     &config,
        }
        
        err = api.SetConversationBurnConfig.Execute(ctx, apiReq)
        if err != nil {
            return "", err
        }
        
        return "success", nil
    }
    
    return caller.ExecAsync(c.ctx, call, operationID, c.conversationCH)
}

// 获取消息燃烧状态
func (c *ConversationMsg) GetMessageBurnStatus(
    operationID string,
    conversationID string,
    clientMsgID string,
) string {
    
    call := func(ctx context.Context) (string, error) {
        msg, err := c.db.GetMessage(ctx, conversationID, clientMsgID)
        if err != nil {
            return "", err
        }
        
        status := map[string]interface{}{
            "burnStatus":     msg.BurnStatus,
            "burnStartTime":  msg.BurnStartTime,
            "burnDeadline":   msg.BurnDeadline,
            "remainingTime":  msg.BurnDeadline - time.Now().Unix(),
            "isLocalDeleted": msg.IsLocalDeleted,
        }
        
        statusBytes, _ := json.Marshal(status)
        return string(statusBytes), nil
    }
    
    return caller.ExecSync(c.ctx, call, operationID)
}

// 手动触发消息燃烧
func (c *ConversationMsg) TriggerMessageBurn(
    operationID string,
    conversationID string,
    clientMsgID string,
) string {
    
    call := func(ctx context.Context) (string, error) {
        // 获取消息
        msg, err := c.db.GetMessage(ctx, conversationID, clientMsgID)
        if err != nil {
            return "", err
        }
        
        // 检查权限（只有发送者可以手动触发）
        if msg.SendID != c.loginUserID {
            return "", errors.New("only sender can trigger burn")
        }
        
        // 立即执行燃烧
        err = c.burnManager.executeLocalDelete(ctx, conversationID, clientMsgID)
        if err != nil {
            return "", err
        }
        
        // 通知服务器
        apiReq := &api.TriggerBurnReq{
            ConversationID: conversationID,
            MessageIDs:     []string{msg.ServerMsgID},
            Reason:        "manual_trigger",
        }
        
        err = api.TriggerBurn.Execute(ctx, apiReq)
        if err != nil {
            return "", err
        }
        
        return "success", nil
    }
    
    return caller.ExecAsync(c.ctx, call, operationID, c.conversationCH)
}

// 监听燃烧事件
func (c *ConversationMsg) SetBurnMessageListener(listener BurnMessageListener) {
    c.burnMessageListener = listener
}

// 燃烧消息监听器接口
type BurnMessageListener interface {
    // 燃烧开始
    OnBurnStart(conversationID, clientMsgID string, deadline int64)
    
    // 燃烧倒计时更新
    OnBurnCountdown(conversationID, clientMsgID string, remainingTime int64)
    
    // 燃烧完成（消息删除）
    OnBurnComplete(conversationID, clientMsgID string)
    
    // 燃烧违规（截图等）
    OnBurnViolation(conversationID, clientMsgID string, violationType int32)
    
    // 燃烧配置变更
    OnBurnConfigChanged(conversationID string, newConfig string)
}
```

## 七、安全防护与合规

### 7.1 加密增强

```go
// pkg/common/encrypt/burn_encryption.go
package encrypt

import (
    "crypto/aes"
    "crypto/cipher"
    "crypto/rand"
    "crypto/sha256"
    "encoding/base64"
    "io"
    
    "golang.org/x/crypto/pbkdf2"
)

type BurnMessageEncryptor struct {
    masterKey []byte
    salt     []byte
}

// 创建加密器
func NewBurnMessageEncryptor(masterKey string) *BurnMessageEncryptor {
    salt := make([]byte, 16)
    rand.Read(salt)
    
    return &BurnMessageEncryptor{
        masterKey: []byte(masterKey),
        salt:     salt,
    }
}

// 加密燃烧消息内容
func (e *BurnMessageEncryptor) EncryptBurnMessage(content string, messageID string) (string, error) {
    // 使用消息ID作为密钥派生的额外盐
    key := e.deriveKey(messageID)
    
    // 创建AES加密器
    block, err := aes.NewCipher(key)
    if err != nil {
        return "", err
    }
    
    // 使用GCM模式
    gcm, err := cipher.NewGCM(block)
    if err != nil {
        return "", err
    }
    
    // 生成随机nonce
    nonce := make([]byte, gcm.NonceSize())
    if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
        return "", err
    }
    
    // 加密内容
    ciphertext := gcm.Seal(nonce, nonce, []byte(content), nil)
    
    // Base64编码
    return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// 解密燃烧消息内容
func (e *BurnMessageEncryptor) DecryptBurnMessage(encryptedContent string, messageID string) (string, error) {
    // Base64解码
    ciphertext, err := base64.StdEncoding.DecodeString(encryptedContent)
    if err != nil {
        return "", err
    }
    
    // 派生密钥
    key := e.deriveKey(messageID)
    
    // 创建AES解密器
    block, err := aes.NewCipher(key)
    if err != nil {
        return "", err
    }
    
    gcm, err := cipher.NewGCM(block)
    if err != nil {
        return "", err
    }
    
    // 提取nonce
    nonceSize := gcm.NonceSize()
    if len(ciphertext) < nonceSize {
        return "", errors.New("ciphertext too short")
    }
    
    nonce, ciphertext := ciphertext[:nonceSize], ciphertext[nonceSize:]
    
    // 解密
    plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
    if err != nil {
        return "", err
    }
    
    return string(plaintext), nil
}

// 派生消息特定密钥
func (e *BurnMessageEncryptor) deriveKey(messageID string) []byte {
    // 使用PBKDF2派生32字节密钥
    return pbkdf2.Key(
        e.masterKey,
        append(e.salt, []byte(messageID)...),
        10000,
        32,
        sha256.New,
    )
}

// 安全清理密钥
func (e *BurnMessageEncryptor) SecureCleanup() {
    // 覆盖密钥数据
    for i := range e.masterKey {
        e.masterKey[i] = 0
    }
    for i := range e.salt {
        e.salt[i] = 0
    }
}
```

### 7.2 合规管理模块

```go
// internal/rpc/compliance/compliance.go
package compliance

import (
    "context"
    "encoding/json"
    "fmt"
    "time"
    
    "github.com/openimsdk/tools/log"
)

type ComplianceManager struct {
    msgDatabase     database.MsgDatabase
    auditLogger     *AuditLogger
    retentionPolicy *RetentionPolicy
    
    config          *config.ComplianceSettings
}

type RetentionPolicy struct {
    DefaultDays     int32
    LegalHoldDays   int32
    AutoReport      bool
    ReportInterval  time.Duration
}

type AuditLogger struct {
    logPath         string
    rotationSize    int64
    retentionDays   int32
    encryptLogs     bool
}

// 设置法务保留
func (cm *ComplianceManager) SetLegalHold(ctx context.Context, req *compliance.SetLegalHoldReq) error {
    log.ZInfo(ctx, "setting legal hold", 
        "conversationID", req.ConversationID,
        "operator", req.Operator,
        "reason", req.Reason)
    
    // 验证操作权限
    if !cm.hasLegalHoldPermission(ctx, req.Operator) {
        return errors.New("insufficient permissions for legal hold")
    }
    
    // 获取相关消息
    var messageIDs []string
    if len(req.MessageIDs) > 0 {
        messageIDs = req.MessageIDs
    } else {
        // 保留整个会话
        messages, err := cm.msgDatabase.GetConversationAllMessages(ctx, req.ConversationID)
        if err != nil {
            return err
        }
        
        for _, msg := range messages {
            messageIDs = append(messageIDs, msg.ServerMsgID)
        }
    }
    
    // 设置保留状态
    for _, msgID := range messageIDs {
        err := cm.setMessageRetention(ctx, msgID, req)
        if err != nil {
            log.ZError(ctx, "failed to set message retention", err, "messageID", msgID)
            continue
        }
    }
    
    // 记录审计日志
    auditLog := &AuditLog{
        Timestamp:      time.Now().Unix(),
        Operator:       req.Operator,
        Action:         "legal_hold_set",
        ConversationID: req.ConversationID,
        MessageCount:   len(messageIDs),
        Reason:         req.Reason,
        CaseNumber:     req.CaseNumber,
        Duration:       req.Duration,
    }
    
    cm.auditLogger.WriteLog(ctx, auditLog)
    
    return nil
}

// 设置单个消息保留
func (cm *ComplianceManager) setMessageRetention(ctx context.Context, messageID string, req *compliance.SetLegalHoldReq) error {
    msg, err := cm.msgDatabase.GetMsgByID(ctx, messageID)
    if err != nil {
        return err
    }
    
    // 如果是燃烧消息，更新保留状态
    if msg.BurnState != nil {
        msg.BurnState.RetentionReason = req.Reason
        
        retention := &RetentionLog{
            Operator:    req.Operator,
            Reason:      req.Reason,
            Duration:    req.Duration,
            CaseNumber:  req.CaseNumber,
            SetTime:     time.Now().Unix(),
        }
        
        if msg.BurnAudit == nil {
            msg.BurnAudit = &BurnAudit{}
        }
        msg.BurnAudit.RetentionLogs = append(msg.BurnAudit.RetentionLogs, retention)
        
        // 更新数据库
        updateData := map[string]interface{}{
            "burn_state":  msg.BurnState,
            "burn_audit":  msg.BurnAudit,
        }
        
        return cm.msgDatabase.UpdateMessage(ctx, msg.ConversationID, msg.Seq, updateData)
    }
    
    return nil
}

// 生成合规报告
func (cm *ComplianceManager) GenerateComplianceReport(ctx context.Context, req *compliance.GenerateReportReq) (*compliance.ComplianceReport, error) {
    report := &compliance.ComplianceReport{
        ReportID:    generateReportID(),
        ReportType:  req.ReportType,
        StartTime:   req.StartTime,
        EndTime:     req.EndTime,
        GenerateTime: time.Now().Unix(),
        GeneratedBy: req.Operator,
    }
    
    switch req.ReportType {
    case "burn_summary":
        report.Data = cm.generateBurnSummaryReport(ctx, req)
    case "burn_detail":
        report.Data = cm.generateBurnDetailReport(ctx, req)
    case "violation_report":
        report.Data = cm.generateViolationReport(ctx, req)
    case "retention_report":
        report.Data = cm.generateRetentionReport(ctx, req)
    default:
        return nil, errors.New("unsupported report type")
    }
    
    // 保存报告
    err := cm.saveComplianceReport(ctx, report)
    if err != nil {
        return nil, err
    }
    
    return report, nil
}

// 生成燃烧摘要报告
func (cm *ComplianceManager) generateBurnSummaryReport(ctx context.Context, req *compliance.GenerateReportReq) interface{} {
    stats, err := cm.msgDatabase.GetBurnMessageStats(ctx, req.StartTime, req.EndTime)
    if err != nil {
        log.ZError(ctx, "failed to get burn message stats", err)
        return nil
    }
    
    summary := map[string]interface{}{
        "total_burn_messages":    stats.TotalBurnMessages,
        "completed_burns":        stats.CompletedBurns,
        "active_burns":          stats.ActiveBurns,
        "retained_messages":     stats.RetainedMessages,
        "violation_count":       stats.ViolationCount,
        "top_conversations":     stats.TopConversations,
        "burn_duration_stats":   stats.DurationStats,
        "trigger_mode_stats":    stats.TriggerModeStats,
    }
    
    return summary
}

// 审计日志写入器
type AuditLogger struct {
    writer      io.Writer
    encryptor   *encrypt.BurnMessageEncryptor
    mutex       sync.Mutex
}

func (al *AuditLogger) WriteLog(ctx context.Context, auditLog *AuditLog) error {
    al.mutex.Lock()
    defer al.mutex.Unlock()
    
    // 序列化日志
    logBytes, err := json.Marshal(auditLog)
    if err != nil {
        return err
    }
    
    // 加密日志（如果启用）
    if al.encryptor != nil {
        encryptedLog, err := al.encryptor.EncryptBurnMessage(string(logBytes), auditLog.ID)
        if err != nil {
            log.ZError(ctx, "failed to encrypt audit log", err)
            // 继续写入未加密日志
        } else {
            logBytes = []byte(encryptedLog)
        }
    }
    
    // 添加时间戳和换行
    logLine := fmt.Sprintf("[%s] %s\n", 
        time.Unix(auditLog.Timestamp, 0).Format(time.RFC3339),
        string(logBytes))
    
    // 写入日志
    _, err = al.writer.Write([]byte(logLine))
    return err
}

// 导出合规数据
func (cm *ComplianceManager) ExportComplianceData(ctx context.Context, req *compliance.ExportDataReq) (*compliance.ExportDataResp, error) {
    // 验证导出权限
    if !cm.hasExportPermission(ctx, req.Operator) {
        return nil, errors.New("insufficient permissions for data export")
    }
    
    // 获取数据
    data, err := cm.getExportData(ctx, req)
    if err != nil {
        return nil, err
    }
    
    // 根据格式导出
    var exportedData []byte
    switch req.Format {
    case "json":
        exportedData, err = json.Marshal(data)
    case "csv":
        exportedData, err = cm.exportToCSV(data)
    case "pdf":
        exportedData, err = cm.exportToPDF(data)
    default:
        return nil, errors.New("unsupported export format")
    }
    
    if err != nil {
        return nil, err
    }
    
    // 记录导出操作
    auditLog := &AuditLog{
        Timestamp:  time.Now().Unix(),
        Operator:   req.Operator,
        Action:     "data_export",
        DataSize:   len(exportedData),
        Format:     req.Format,
        StartTime:  req.StartTime,
        EndTime:    req.EndTime,
    }
    
    cm.auditLogger.WriteLog(ctx, auditLog)
    
    return &compliance.ExportDataResp{
        Data:     exportedData,
        Format:   req.Format,
        Size:     int64(len(exportedData)),
        Checksum: calculateChecksum(exportedData),
    }, nil
}
```

### 7.3 权限控制

```go
// pkg/common/permission/burn_permission.go
package permission

import (
    "context"
    "time"
)

type BurnPermissionManager struct {
    roleCache    *cache.RoleCache
    policyEngine *PolicyEngine
    auditLogger  *AuditLogger
}

type BurnPermission struct {
    UserID              string
    ConversationID      string
    
    // 基础权限
    CanSendBurnMessage  bool
    CanSetBurnConfig    bool
    CanViewBurnStatus   bool
    
    // 管理权限
    CanForceBurn        bool
    CanSetRetention     bool
    CanExportData       bool
    
    // 时间限制
    MaxBurnDuration     int32
    MinBurnDuration     int32
    
    // 功能限制
    AllowedTriggerModes []int32
    AllowedContentTypes []int32
    
    // 有效期
    GrantedAt           int64
    ExpiresAt           int64
    GrantedBy           string
}

// 检查燃烧消息发送权限
func (pm *BurnPermissionManager) CheckSendBurnPermission(ctx context.Context, userID, conversationID string, burnConfig *BurnConfig) error {
    permission, err := pm.getUserBurnPermission(ctx, userID, conversationID)
    if err != nil {
        return err
    }
    
    // 检查基础权限
    if !permission.CanSendBurnMessage {
        return errors.New("no permission to send burn messages")
    }
    
    // 检查时长限制
    if burnConfig.Duration > permission.MaxBurnDuration {
        return fmt.Errorf("burn duration %d exceeds maximum %d", 
            burnConfig.Duration, permission.MaxBurnDuration)
    }
    
    if burnConfig.Duration < permission.MinBurnDuration {
        return fmt.Errorf("burn duration %d below minimum %d", 
            burnConfig.Duration, permission.MinBurnDuration)
    }
    
    // 检查触发模式
    if !pm.isTriggerModeAllowed(burnConfig.TriggerMode, permission.AllowedTriggerModes) {
        return fmt.Errorf("trigger mode %d not allowed", burnConfig.TriggerMode)
    }
    
    // 检查权限有效期
    now := time.Now().Unix()
    if permission.ExpiresAt > 0 && now > permission.ExpiresAt {
        return errors.New("burn permission expired")
    }
    
    return nil
}

// 检查配置设置权限
func (pm *BurnPermissionManager) CheckSetConfigPermission(ctx context.Context, userID, conversationID string) error {
    permission, err := pm.getUserBurnPermission(ctx, userID, conversationID)
    if err != nil {
        return err
    }
    
    if !permission.CanSetBurnConfig {
        return errors.New("no permission to set burn configuration")
    }
    
    return nil
}

// 检查法务保留权限
func (pm *BurnPermissionManager) CheckLegalHoldPermission(ctx context.Context, userID string) error {
    permission, err := pm.getUserBurnPermission(ctx, userID, "")
    if err != nil {
        return err
    }
    
    if !permission.CanSetRetention {
        return errors.New("no permission to set legal hold")
    }
    
    return nil
}

// 获取用户燃烧权限
func (pm *BurnPermissionManager) getUserBurnPermission(ctx context.Context, userID, conversationID string) (*BurnPermission, error) {
    // 从缓存获取
    cacheKey := fmt.Sprintf("burn_perm:%s:%s", userID, conversationID)
    if perm, ok := pm.roleCache.Get(cacheKey); ok {
        return perm.(*BurnPermission), nil
    }
    
    // 从数据库获取用户角色
    roles, err := pm.getUserRoles(ctx, userID, conversationID)
    if err != nil {
        return nil, err
    }
    
    // 计算综合权限
    permission := pm.calculatePermissions(ctx, roles, userID, conversationID)
    
    // 缓存权限
    pm.roleCache.SetWithExpire(cacheKey, permission, 5*time.Minute)
    
    return permission, nil
}

// 计算用户权限
func (pm *BurnPermissionManager) calculatePermissions(ctx context.Context, roles []string, userID, conversationID string) *BurnPermission {
    permission := &BurnPermission{
        UserID:         userID,
        ConversationID: conversationID,
        GrantedAt:      time.Now().Unix(),
    }
    
    // 默认权限策略
    for _, role := range roles {
        switch role {
        case "admin":
            permission.CanSendBurnMessage = true
            permission.CanSetBurnConfig = true
            permission.CanViewBurnStatus = true
            permission.CanForceBurn = true
            permission.CanSetRetention = true
            permission.CanExportData = true
            permission.MaxBurnDuration = 7 * 24 * 3600 // 7天
            permission.MinBurnDuration = 1
            permission.AllowedTriggerModes = []int32{1, 2}
            
        case "moderator":
            permission.CanSendBurnMessage = true
            permission.CanSetBurnConfig = true
            permission.CanViewBurnStatus = true
            permission.CanForceBurn = true
            permission.MaxBurnDuration = 24 * 3600 // 1天
            permission.MinBurnDuration = 1
            permission.AllowedTriggerModes = []int32{1, 2}
            
        case "user":
            permission.CanSendBurnMessage = true
            permission.CanViewBurnStatus = true
            permission.MaxBurnDuration = 3600 // 1小时
            permission.MinBurnDuration = 30
            permission.AllowedTriggerModes = []int32{2} // 仅阅读后触发
            
        case "guest":
            permission.CanViewBurnStatus = true
            // 访客无其他权限
        }
    }
    
    // 应用自定义策略
    customPolicy := pm.policyEngine.GetCustomPolicy(userID, conversationID)
    if customPolicy != nil {
        pm.applyCustomPolicy(permission, customPolicy)
    }
    
    return permission
}
```

## 八、配置文件

### 8.1 服务端配置
```yaml
# config/openim-rpc-msg.yml
burnAfterRead:
  enabled: true
  
  # 默认设置
  defaultSettings:
    duration: 300              # 默认5分钟
    triggerMode: 2             # 默认阅读后触发
    deleteMode: 2              # 默认硬删除
    screenshotAlert: true      # 默认开启截图提醒
    previewEnabled: true       # 默认允许预览

  # 安全设置  
  securitySettings:
    minDuration: 5             # 最小5秒
    maxDuration: 604800        # 最大7天
    encryptionRequired: true   # 必须加密
    antiScreenshot: true       # 防截图
    antiDebug: false           # 防调试（生产环境建议开启）
    secureDelete: true         # 安全删除
    memoryProtection: true     # 内存保护

  # 合规设置
  complianceSettings:
    auditEnabled: true         # 审计日志
    retentionEnabled: true     # 法务保留
    retentionDays: 90          # 保留90天
    autoReport: false          # 自动报告
    exportFormat: "json"       # 导出格式

  # 性能设置
  performanceSettings:
    cleanupInterval: 60        # 清理间隔60秒
    batchSize: 1000           # 批处理1000条
    cacheSize: 10000          # 缓存10000个任务
    maxConcurrent: 10         # 最大并发10个

  # 通知设置
  notificationSettings:
    enablePush: true          # 启用推送
    burnStartNotify: true     # 燃烧开始通知
    burnCompleteNotify: true  # 燃烧完成通知
    violationNotify: true     # 违规通知

# config/openim-crontask.yml
cronTask:
  # 现有任务
  cronExecuteTime: 0 2 * * *
  retainChatRecords: 365
  fileExpireTime: 180
  
  # 新增燃烧清理任务
  burnAfterReadCleanup: "*/1 * * * *"    # 每分钟执行
  burnAuditLogCleanup: "0 3 * * *"       # 每天3点清理审计日志
  burnComplianceReport: "0 1 * * 1"      # 每周一1点生成合规报告
```

### 8.2 客户端配置
```json
// pkg/cliconf/burn_config.json
{
    "burnAfterRead": {
        "enabled": true,
        "security": {
            "antiScreenshot": true,
            "antiDebug": false,
            "antiRoot": false,
            "memoryProtection": true,
            "encryptLocalStorage": true
        },
        "ui": {
            "showCountdown": true,
            "blurWhenBurning": false,
            "confirmBeforeBurn": true,
            "animateDelete": true
        },
        "defaults": {
            "duration": 300,
            "triggerMode": 2,
            "screenshotAlert": true
        },
        "limits": {
            "maxDuration": 604800,
            "minDuration": 5,
            "allowedContentTypes": [1, 2, 3, 4, 5, 6]
        }
    }
}
```

## 九、部署与运维

### 9.1 数据库迁移脚本

```sql
-- MongoDB燃烧消息索引
db.msg.createIndex(
    { 
        "burn_state.deadline_time": 1, 
        "burn_state.status": 1 
    },
    { 
        name: "idx_burn_deadline",
        partialFilterExpression: { 
            "burn_config.enabled": true,
            "burn_state.status": { $in: [0, 1] }
        }
    }
)

-- 审计日志索引
db.msg.createIndex(
    { 
        "burn_audit.create_time": 1,
        "burn_audit.creator_id": 1
    },
    { name: "idx_burn_audit" }
)

-- SQLite客户端迁移
ALTER TABLE local_chat_logs ADD COLUMN burn_config TEXT DEFAULT '';
ALTER TABLE local_chat_logs ADD COLUMN burn_status INTEGER DEFAULT 0;
ALTER TABLE local_chat_logs ADD COLUMN burn_start_time INTEGER DEFAULT 0;
ALTER TABLE local_chat_logs ADD COLUMN burn_deadline INTEGER DEFAULT 0;
ALTER TABLE local_chat_logs ADD COLUMN local_burn_timer INTEGER DEFAULT 0;
ALTER TABLE local_chat_logs ADD COLUMN is_local_deleted BOOLEAN DEFAULT false;
ALTER TABLE local_chat_logs ADD COLUMN delete_proof TEXT DEFAULT '';
ALTER TABLE local_chat_logs ADD COLUMN original_content TEXT DEFAULT '';

-- 创建索引
CREATE INDEX idx_local_burn_status ON local_chat_logs(burn_status, burn_deadline);
CREATE INDEX idx_local_burn_deadline ON local_chat_logs(burn_deadline) WHERE burn_deadline > 0;
```

### 9.2 监控指标

```yaml
# prometheus配置
groups:
- name: openim_burn_after_read
  rules:
  # 燃烧消息指标
  - alert: HighBurnMessageFailureRate
    expr: rate(openim_burn_message_failures_total[5m]) > 0.1
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "High burn message failure rate"
      description: "Burn message failure rate is {{ $value }} per second"

  - alert: BurnCleanupTaskFailed
    expr: increase(openim_burn_cleanup_failures_total[1h]) > 0
    for: 0m
    labels:
      severity: critical
    annotations:
      summary: "Burn cleanup task failed"
      description: "Burn cleanup task has failed {{ $value }} times in the last hour"

  - alert: HighBurnViolationRate
    expr: rate(openim_burn_violations_total[10m]) > 0.05
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High burn violation rate detected"
      description: "Burn violation rate is {{ $value }} per second"

  - alert: BurnAuditLogStorageFull
    expr: openim_burn_audit_storage_usage > 0.9
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Burn audit log storage nearly full"
      description: "Burn audit log storage usage is {{ $value | humanizePercentage }}"
```

### 9.3 日志配置

```yaml
# config/log.yml
burnAfterRead:
  level: "info"
  format: "json"
  outputs:
    - type: "file"
      path: "logs/burn-after-read.log"
      maxSize: 100MB
      maxAge: 30
      maxBackups: 10
      compress: true
    - type: "elasticsearch"
      hosts: ["localhost:9200"]
      index: "openim-burn-logs"
      
  # 敏感信息脱敏
  sanitize:
    enabled: true
    rules:
      - field: "content"
        action: "mask"
        pattern: "***MASKED***"
      - field: "user_id"
        action: "hash"
        algorithm: "sha256"
```

## 十、测试计划

### 10.1 单元测试

```go
// internal/rpc/msg/burn_test.go
func TestBurnCoordinator(t *testing.T) {
    tests := []struct{
        name     string
        duration int32
        trigger  int32
        expect   string
    }{
        {"immediate_burn", 0, 1, "deleted"},
        {"delayed_burn", 300, 2, "scheduled"},
        {"invalid_config", -1, 3, "error"},
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // 测试逻辑
        })
    }
}
```

### 10.2 集成测试

```go
// test/burn_integration_test.go
func TestBurnAfterReadIntegration(t *testing.T) {
    // 1. 发送燃烧消息
    // 2. 模拟阅读
    // 3. 验证定时器
    // 4. 验证删除
    // 5. 验证通知
}
```

### 10.3 压力测试

```bash
# 燃烧消息发送测试
artillery run --config burn-load-test.yml

# burn-load-test.yml
config:
  target: 'http://localhost:10002'
  phases:
    - duration: 60
      arrivalRate: 100
scenarios:
  - name: "Send burn messages"
    requests:
      - post:
          url: "/msg/send_burn_after_read"
          json:
            content: "test burn message"
            burnDuration: 60
```

## 十一、总结

本实现方案基于对主流IM应用的深度调研，采用了Signal模式的增强版架构，具有以下特点：

### 11.1 核心优势

1. **安全性优先**：端到端加密 + 多层防护 + 物理删除
2. **用户体验友好**：直观的界面 + 灵活的配置 + 清晰的反馈  
3. **合规性完备**：审计日志 + 法务保留 + 合规报告
4. **系统性能优良**：批量处理 + 缓存优化 + 异步执行
5. **扩展性强**：模块化设计 + 插件架构 + 配置驱动

### 11.2 技术创新

1. **双重计时机制**：同时支持发送后和阅读后两种触发模式
2. **智能违规检测**：多维度安全防护和实时违规监控
3. **灵活的合规功能**：自动化法务保留和合规报告生成  
4. **增强的用户控制**：细粒度权限管理和个性化配置

### 11.3 实施建议

1. **分阶段实施**：基础功能 → 体验优化 → 高级功能
2. **充分测试**：单元测试 + 集成测试 + 压力测试
3. **用户教育**：功能说明 + 安全提醒 + 最佳实践
4. **监控完善**：性能监控 + 安全监控 + 合规监控

这套方案为OpenIM提供了完整的阅后即焚功能实现路径，平衡了安全性、可用性和合规性的要求，可以满足不同场景下的隐私保护需求。

---

**文档版本**：1.0  
**编写日期**：2024-12-28  
**作者**：OpenIM技术团队  
**审核状态**：待审核