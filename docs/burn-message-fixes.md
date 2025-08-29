# 阅后即焚功能关键问题修复记录

## 修复概述
针对代码审查中发现的关键问题，已完成以下修复工作：

## 1. Context 传播问题修复 (P0 - 已完成)

### 问题描述
- 原代码使用 `context.Background()` 导致链路追踪信息丢失
- 无法追踪异步任务的执行情况和性能问题

### 修复方案
文件：`/internal/rpc/msg/as_read.go`

```go
// 修复前
burnCtx := context.Background()

// 修复后
burnCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 30*time.Second)
defer cancel()
```

**改进点**：
- 使用 `context.WithoutCancel(ctx)` 保留原始context的追踪信息
- 添加30秒超时控制，避免任务无限执行
- 添加context取消检查，优雅处理中断

## 2. 并发控制实现 (P0 - 已完成)

### 问题描述
- 原代码为每个消息创建新的goroutine，可能导致goroutine泄露
- 高并发场景下可能耗尽系统资源

### 修复方案
新增文件：`/internal/rpc/msg/burn_worker_pool.go`

**实现特性**：
- Worker Pool模式，默认10个工作线程
- 任务队列容量1000，避免内存溢出
- 优雅关闭机制，确保任务完成
- 队列满时的降级处理策略

文件修改：
- `/internal/rpc/msg/server.go` - 添加worker pool初始化
- `/internal/rpc/msg/as_read.go` - 使用worker pool提交任务

## 3. OpenIM规范修复 (P1 - 已完成)

### 错误包装规范
文件：`/internal/rpc/msg/burn_after_read.go`

```go
// 修复前
return nil, err

// 修复后
return nil, errs.WrapMsg(err, "descriptive error message")
```

### 定时任务改进
文件：`/internal/tools/cron/burn_message.go`

- 移除硬编码的魔法数字
- 函数返回error而不是静默失败
- 错误日志记录符合OpenIM标准

## 4. 其他优化

### 配置项支持
- 添加 `BurnMessageMaxIterations` 配置项
- Worker pool的线程数和队列大小可配置

### 错误处理改进
- 所有数据库操作添加错误包装
- 异步任务失败不影响主流程
- 添加详细的错误上下文信息

## 待处理问题

### 数据库事务保护 (P1)
- processBurnMessage 函数需要事务保护
- 避免部分更新导致的数据不一致

### 架构优化 (P2)
- 将燃烧消息处理逻辑抽取为独立服务
- 减少 msgServer 的职责
- 提高代码的可测试性和可维护性

## 性能影响评估

### 正面影响
- Worker pool限制了并发数，避免资源耗尽
- Context超时控制避免任务无限执行
- 批处理减少数据库压力

### 潜在风险
- 队列满时可能丢失任务（已添加日志告警）
- 30秒超时可能对大批量消息处理不够
- 需要监控worker pool的队列长度

## 测试建议

1. **压力测试**
   - 大批量消息标记已读场景
   - Worker pool队列满的边界测试
   - Context超时的处理验证

2. **功能测试**
   - 链路追踪信息是否正确传递
   - 错误场景的降级处理
   - 优雅关闭时的任务处理

3. **监控指标**
   - Worker pool队列长度
   - 任务处理延迟
   - 错误率和重试情况

## 部署注意事项

1. 配置更新
   - 根据业务量调整worker pool参数
   - 设置合理的批处理大小

2. 监控告警
   - 监控burn_task_queue_full日志
   - 关注goroutine数量变化

3. 回滚方案
   - 保留原有代码的降级逻辑
   - 可通过配置快速切换

---

更新时间：2025-08-20
审核状态：待审核