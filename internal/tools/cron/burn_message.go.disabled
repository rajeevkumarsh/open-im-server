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

package cron

import (
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/openimsdk/protocol/constant"
	"github.com/openimsdk/protocol/msg"
	"github.com/openimsdk/protocol/sdkws"
	"github.com/openimsdk/tools/errs"
	"github.com/openimsdk/tools/log"
	"github.com/openimsdk/tools/mcontext"
	"google.golang.org/protobuf/proto"
)

// cleanupBurnMessages 清理过期的燃烧消息
func (c *cronServer) cleanupBurnMessages() error {
	now := time.Now()
	currentTime := now.Unix()
	operationID := fmt.Sprintf("cron_burn_cleanup_%d_%d", os.Getpid(), currentTime)
	ctx := mcontext.SetOperationID(c.ctx, operationID)
	
	log.ZInfo(ctx, "Starting burn message cleanup", "currentTime", currentTime)
	
	batch := c.config.CronTask.BurnMessageCleanBatch
	if batch <= 0 {
		batch = 100 // 默认批次大小
	}
	
	// 使用配置或默认值
	maxIterations := 1000
	if c.config.CronTask.BurnMessageMaxIterations > 0 {
		maxIterations = c.config.CronTask.BurnMessageMaxIterations
	}
	totalDeleted := 0
	
	for i := 0; i < maxIterations; i++ {
		iterationCtx := mcontext.SetOperationID(c.ctx, fmt.Sprintf("%s_%d", operationID, i))
		
		// 获取过期的燃烧消息
		resp, err := c.msgClient.GetExpiredBurnMessages(iterationCtx, &msg.GetExpiredBurnMessagesReq{
			CurrentTime: currentTime,
			Limit:       int32(batch),
		})
		if err != nil {
			log.ZError(iterationCtx, "failed to get expired burn messages", err)
			return errs.WrapMsg(err, "failed to get expired burn messages")
		}
		
		if len(resp.Messages) == 0 {
			log.ZInfo(iterationCtx, "no more expired burn messages to cleanup")
			break
		}
		
		log.ZInfo(iterationCtx, "found expired burn messages", "count", len(resp.Messages))
		
		// 删除每个过期的燃烧消息
		deleted := 0
		for _, burnMsg := range resp.Messages {
			// 删除消息
			_, err := c.msgClient.DeleteBurnMessage(iterationCtx, &msg.DeleteBurnMessageReq{
				ConversationID: burnMsg.ConversationID,
				Seq:            burnMsg.Seq,
			})
			if err != nil {
				log.ZError(iterationCtx, "failed to delete burn message", err,
					"conversationID", burnMsg.ConversationID,
					"seq", burnMsg.Seq,
					"serverMsgID", burnMsg.ServerMsgID)
				continue
			}
			
			// 发送燃烧删除通知
			c.sendBurnDeleteNotification(iterationCtx, burnMsg)
			deleted++
		}
		
		totalDeleted += deleted
		log.ZInfo(iterationCtx, "deleted burn messages in batch", 
			"batchDeleted", deleted, 
			"totalDeleted", totalDeleted)
		
		// 如果这批消息数量小于批次大小，说明已经处理完所有过期消息
		if len(resp.Messages) < batch {
			break
		}
		
		// 短暂休眠，避免对数据库造成过大压力
		time.Sleep(100 * time.Millisecond)
	}
	
	elapsed := time.Since(now)
	log.ZInfo(ctx, "burn message cleanup completed", 
		"totalDeleted", totalDeleted, 
		"duration", elapsed)
	
	return nil
}

// sendBurnDeleteNotification 发送燃烧删除通知
func (c *cronServer) sendBurnDeleteNotification(ctx context.Context, burnMsg *msg.BurnMessage) {
	deleteTime := time.Now().Unix()
	log.ZInfo(ctx, "sending burn delete notification", 
		"conversationID", burnMsg.ConversationID,
		"seq", burnMsg.Seq,
		"clientMsgID", burnMsg.ClientMsgID,
		"deleteTime", deleteTime)
	
	// 解析 conversationID 以确定会话类型和相关用户
	sessionType, sendID, recvID := c.parseConversationID(burnMsg.ConversationID)
	
	// 发送燃烧删除通知给发送者和接收者
	c.sendBurnDeleteNotificationToUser(ctx, burnMsg, sessionType, sendID, recvID, sendID)
	if sessionType == constant.SingleChatType && sendID != recvID {
		c.sendBurnDeleteNotificationToUser(ctx, burnMsg, sessionType, sendID, recvID, recvID)
	}
	
	log.ZDebug(ctx, "burn delete notification sent", 
		"conversationID", burnMsg.ConversationID,
		"sessionType", sessionType)
}

// parseConversationID 解析 conversationID 获取会话信息
func (c *cronServer) parseConversationID(conversationID string) (sessionType int32, sendID, recvID string) {
	// 单聊格式: sendID_recvID  
	// 群聊格式: groupID
	if strings.Contains(conversationID, "_") {
		// 单聊
		parts := strings.Split(conversationID, "_")
		if len(parts) == 2 {
			return constant.SingleChatType, parts[0], parts[1]
		}
	}
	// 群聊
	return constant.ReadGroupChatType, "", conversationID
}

// sendBurnDeleteNotificationToUser 向特定用户发送燃烧删除通知
func (c *cronServer) sendBurnDeleteNotificationToUser(ctx context.Context, burnMsg *msg.BurnMessage, sessionType int32, sendID, recvID, targetUserID string) {
	// 构建通知消息数据
	notification := &sdkws.BurnDeleteNotification{
		ConversationID: burnMsg.ConversationID,
		Seq:           burnMsg.Seq,
		ClientMsgID:   burnMsg.ClientMsgID,
	}
	
	// 将通知封装为MsgData
	notificationData, err := proto.Marshal(notification)
	if err != nil {
		log.ZError(ctx, "failed to marshal burn delete notification", err,
			"conversationID", burnMsg.ConversationID,
			"seq", burnMsg.Seq)
		return
	}
	
	msgData := &sdkws.MsgData{
		SendID:      "system", // 系统消息
		RecvID:      targetUserID,
		GroupID:     recvID,
		SessionType: sessionType,
		MsgFrom:     constant.SysMsgType,
		ContentType: constant.BurnDeleteNotification,
		Content:     notificationData,
		CreateTime:  time.Now().UnixMilli(),
	}
	
	// 发送通知消息
	_, err = c.msgClient.SendMsg(ctx, &msg.SendMsgReq{MsgData: msgData})
	if err != nil {
		log.ZError(ctx, "failed to send burn delete notification", err,
			"targetUserID", targetUserID,
			"conversationID", burnMsg.ConversationID,
			"seq", burnMsg.Seq)
	} else {
		log.ZDebug(ctx, "burn delete notification sent to user",
			"targetUserID", targetUserID,
			"conversationID", burnMsg.ConversationID,
			"seq", burnMsg.Seq)
	}
}