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
	"errors"
	"testing"

	"github.com/openimsdk/protocol/sdkws"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

// TestProcessBurnMessage 专门测试燃烧消息处理逻辑

func TestProcessBurnMessage(t *testing.T) {
	ctx := context.Background()
	conversationID := "conv123"
	seq := int64(101)
	userID := "user123"

	t.Run("燃烧消息处理成功", func(t *testing.T) {
		mockDB := &MockMsgDatabase{}
		server := &msgServer{
			MsgDatabase: mockDB,
		}

		burnMessage := &sdkws.MsgData{
			ClientMsgID:   "burn_msg_101",
			ServerMsgID:   "server_burn_101",
			SendID:        "sender456",
			RecvID:        userID,
			BurnAfterRead: true,
			BurnDuration:  30, // 30秒
			BurnStartTime: 0,  // 未开始
			BurnDeadline:  0,  // 未设置
			BurnStatus:    0,  // 未开始燃烧
		}

		mockDB.On("GetMsgBySeqs", ctx, userID, conversationID, []int64{seq}).
			Return(int64(seq), int64(seq), []*sdkws.MsgData{burnMessage}, nil)

		// 期望更新燃烧字段
		mockDB.On("UpdateBurnMessageFields", ctx, conversationID, seq, 
			mock.AnythingOfType("int64"), mock.AnythingOfType("int64"), int32(1)).
			Return(nil).Run(func(args mock.Arguments) {
			// 验证燃烧开始时间和截止时间的合理性
			burnStartTime := args.Get(3).(int64)
			burnDeadline := args.Get(4).(int64)
			assert.Greater(t, burnStartTime, int64(0))
			assert.Greater(t, burnDeadline, burnStartTime)
			assert.Equal(t, burnDeadline-burnStartTime, int64(30)) // 30秒的燃烧时间
		})

		err := server.processBurnMessage(ctx, conversationID, seq, userID)
		assert.NoError(t, err)
		mockDB.AssertExpectations(t)
	})

	t.Run("非燃烧消息跳过处理", func(t *testing.T) {
		mockDB := &MockMsgDatabase{}
		server := &msgServer{
			MsgDatabase: mockDB,
		}

		normalMessage := &sdkws.MsgData{
			ClientMsgID:   "normal_msg_101",
			ServerMsgID:   "server_normal_101",
			SendID:        "sender456",
			RecvID:        userID,
			BurnAfterRead: false, // 非燃烧消息
			BurnDuration:  0,
			BurnStatus:    0,
		}

		mockDB.On("GetMsgBySeqs", ctx, userID, conversationID, []int64{seq}).
			Return(int64(seq), int64(seq), []*sdkws.MsgData{normalMessage}, nil)

		// 不应该调用更新方法，所以不设置UpdateBurnMessageFields的期望

		err := server.processBurnMessage(ctx, conversationID, seq, userID)
		assert.NoError(t, err)
		mockDB.AssertExpectations(t)
	})

	t.Run("已燃烧消息跳过处理", func(t *testing.T) {
		mockDB := &MockMsgDatabase{}
		server := &msgServer{
			MsgDatabase: mockDB,
		}

		burnedMessage := &sdkws.MsgData{
			ClientMsgID:   "burned_msg_101",
			ServerMsgID:   "server_burned_101",
			SendID:        "sender456",
			RecvID:        userID,
			BurnAfterRead: true,
			BurnDuration:  30,
			BurnStatus:    1, // 已经在燃烧中
		}

		mockDB.On("GetMsgBySeqs", ctx, userID, conversationID, []int64{seq}).
			Return(int64(seq), int64(seq), []*sdkws.MsgData{burnedMessage}, nil)

		// 不应该调用更新方法，所以不设置UpdateBurnMessageFields的期望

		err := server.processBurnMessage(ctx, conversationID, seq, userID)
		assert.NoError(t, err)
		mockDB.AssertExpectations(t)
	})

	t.Run("消息不存在", func(t *testing.T) {
		mockDB := &MockMsgDatabase{}
		server := &msgServer{
			MsgDatabase: mockDB,
		}

		mockDB.On("GetMsgBySeqs", ctx, userID, conversationID, []int64{seq}).
			Return(int64(0), int64(0), []*sdkws.MsgData{}, nil)

		err := server.processBurnMessage(ctx, conversationID, seq, userID)
		assert.NoError(t, err)
		mockDB.AssertExpectations(t)
	})

	t.Run("数据库查询失败", func(t *testing.T) {
		mockDB := &MockMsgDatabase{}
		server := &msgServer{
			MsgDatabase: mockDB,
		}

		mockDB.On("GetMsgBySeqs", ctx, userID, conversationID, []int64{seq}).
			Return(int64(0), int64(0), []*sdkws.MsgData(nil), errors.New("database error"))

		err := server.processBurnMessage(ctx, conversationID, seq, userID)
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "database error")
		mockDB.AssertExpectations(t)
	})

	t.Run("更新燃烧字段失败", func(t *testing.T) {
		mockDB := &MockMsgDatabase{}
		server := &msgServer{
			MsgDatabase: mockDB,
		}

		burnMessage := &sdkws.MsgData{
			ClientMsgID:   "burn_msg_101",
			ServerMsgID:   "server_burn_101",
			SendID:        "sender456",
			RecvID:        userID,
			BurnAfterRead: true,
			BurnDuration:  30,
			BurnStartTime: 0,
			BurnDeadline:  0,
			BurnStatus:    0,
		}

		mockDB.On("GetMsgBySeqs", ctx, userID, conversationID, []int64{seq}).
			Return(int64(seq), int64(seq), []*sdkws.MsgData{burnMessage}, nil)

		mockDB.On("UpdateBurnMessageFields", ctx, conversationID, seq, 
			mock.AnythingOfType("int64"), mock.AnythingOfType("int64"), int32(1)).
			Return(errors.New("update failed"))

		err := server.processBurnMessage(ctx, conversationID, seq, userID)
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "update failed")
		mockDB.AssertExpectations(t)
	})
}