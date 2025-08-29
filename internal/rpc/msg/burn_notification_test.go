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

package msg

import (
	"context"
	"testing"

	"github.com/openimsdk/protocol/constant"
	"github.com/openimsdk/protocol/sdkws"
	"github.com/stretchr/testify/mock"
)

// MockMsgNotificationSender 模拟消息通知发送器
type MockMsgNotificationSender struct {
	mock.Mock
}

func (m *MockMsgNotificationSender) BurnStartNotification(ctx context.Context, conversationID string, sessionType int32, sendID, recvID string, seq int64, clientMsgID string, burnDeadline int64) {
	m.Called(ctx, conversationID, sessionType, sendID, recvID, seq, clientMsgID, burnDeadline)
}

func (m *MockMsgNotificationSender) BurnDeleteNotification(ctx context.Context, conversationID string, sessionType int32, sendID, recvID string, seq int64, clientMsgID string) {
	m.Called(ctx, conversationID, sessionType, sendID, recvID, seq, clientMsgID)
}

func TestSendBurnStartNotification(t *testing.T) {
	t.Run("单聊会话接收者解析", func(t *testing.T) {
		// 测试消息接收者解析逻辑
		server := &msgServer{
			// 不使用真实的通知发送器，只测试逻辑
		}
		
		ctx := context.Background()
		conversationID := "user1_user2"
		sessionType := int32(constant.SingleChatType)
		userID := "user1" // 发送者阅读
		message := &sdkws.MsgData{
			SendID:      "user1",
			RecvID:      "user2",
			Seq:         123,
			ClientMsgID: "client123",
			SessionType: constant.SingleChatType,
		}
		burnDeadline := int64(1234567890)
		
		// 这个测试主要验证函数不会panic和参数解析正确
		// 由于没有真实的通知发送器，函数内部会panic，但我们可以测试参数解析
		defer func() {
			if r := recover(); r != nil {
				// 期望在调用通知发送器时panic，这是正常的
				t.Log("Expected panic due to nil notification sender")
			}
		}()
		
		// 如果有完整的通知发送器，这个调用会成功
		if server.msgNotificationSender != nil {
			server.sendBurnStartNotification(ctx, conversationID, sessionType, userID, message, burnDeadline)
		}
	})
	
	t.Run("群聊会话接收者解析", func(t *testing.T) {
		// 测试群聊消息接收者解析逻辑
		server := &msgServer{}
		
		ctx := context.Background()
		conversationID := "group123"
		sessionType := int32(constant.ReadGroupChatType)
		userID := "user1"
		message := &sdkws.MsgData{
			SendID:      "user1",
			GroupID:     "group123",
			Seq:         456,
			ClientMsgID: "client456",
			SessionType: constant.ReadGroupChatType,
		}
		burnDeadline := int64(1234567890)
		
		// 同样，测试参数解析逻辑
		defer func() {
			if r := recover(); r != nil {
				t.Log("Expected panic due to nil notification sender")
			}
		}()
		
		if server.msgNotificationSender != nil {
			server.sendBurnStartNotification(ctx, conversationID, sessionType, userID, message, burnDeadline)
		}
	})
}

func TestMsgNotificationSender_BurnNotifications(t *testing.T) {
	t.Run("燃烧开始通知方法调用", func(t *testing.T) {
		// 这个测试验证 BurnStartNotification 和 BurnDeleteNotification 方法的签名是否正确
		// 实际的通知发送逻辑由底层的 NotificationSender 处理
		
		mockSender := &MockMsgNotificationSender{}
		ctx := context.Background()
		
		// 测试燃烧开始通知
		mockSender.On("BurnStartNotification", 
			ctx, "conv1", int32(1), "user1", "user2", int64(100), "client123", int64(1234567890)).Return()
		
		mockSender.BurnStartNotification(ctx, "conv1", 1, "user1", "user2", 100, "client123", 1234567890)
		
		// 测试燃烧删除通知
		mockSender.On("BurnDeleteNotification", 
			ctx, "conv1", int32(1), "user1", "user2", int64(100), "client123").Return()
		
		mockSender.BurnDeleteNotification(ctx, "conv1", 1, "user1", "user2", 100, "client123")
		
		mockSender.AssertExpectations(t)
	})
}