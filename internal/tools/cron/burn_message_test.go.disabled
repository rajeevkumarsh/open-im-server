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
	"errors"
	"fmt"
	"testing"

	"github.com/openimsdk/open-im-server/v3/pkg/common/config"
	"github.com/openimsdk/protocol/msg"
	"github.com/openimsdk/protocol/sdkws"
	"github.com/robfig/cron/v3"
	"github.com/stretchr/testify/assert"
	"google.golang.org/grpc"
)

// 简化的测试mock客户端
type testMsgClient struct {
	getExpiredBurnMessagesFunc func(ctx context.Context, req *msg.GetExpiredBurnMessagesReq) (*msg.GetExpiredBurnMessagesResp, error)
	deleteBurnMessageFunc      func(ctx context.Context, req *msg.DeleteBurnMessageReq) (*msg.DeleteBurnMessageResp, error)
}

func (t *testMsgClient) GetExpiredBurnMessages(ctx context.Context, req *msg.GetExpiredBurnMessagesReq, opts ...grpc.CallOption) (*msg.GetExpiredBurnMessagesResp, error) {
	if t.getExpiredBurnMessagesFunc != nil {
		return t.getExpiredBurnMessagesFunc(ctx, req)
	}
	return &msg.GetExpiredBurnMessagesResp{Messages: []*msg.BurnMessage{}}, nil
}

func (t *testMsgClient) DeleteBurnMessage(ctx context.Context, req *msg.DeleteBurnMessageReq, opts ...grpc.CallOption) (*msg.DeleteBurnMessageResp, error) {
	if t.deleteBurnMessageFunc != nil {
		return t.deleteBurnMessageFunc(ctx, req)
	}
	return &msg.DeleteBurnMessageResp{}, nil
}

// 实现完整的 msg.MsgClient 接口 - 只实现需要测试的方法，其他方法返回nil
func (t *testMsgClient) GetMaxSeq(ctx context.Context, req *sdkws.GetMaxSeqReq, opts ...grpc.CallOption) (*sdkws.GetMaxSeqResp, error) { return nil, nil }
func (t *testMsgClient) GetMaxSeqs(ctx context.Context, req *msg.GetMaxSeqsReq, opts ...grpc.CallOption) (*msg.SeqsInfoResp, error) { return nil, nil }
func (t *testMsgClient) GetHasReadSeqs(ctx context.Context, req *msg.GetHasReadSeqsReq, opts ...grpc.CallOption) (*msg.SeqsInfoResp, error) { return nil, nil }
func (t *testMsgClient) GetMsgByConversationIDs(ctx context.Context, req *msg.GetMsgByConversationIDsReq, opts ...grpc.CallOption) (*msg.GetMsgByConversationIDsResp, error) { return nil, nil }
func (t *testMsgClient) GetConversationMaxSeq(ctx context.Context, req *msg.GetConversationMaxSeqReq, opts ...grpc.CallOption) (*msg.GetConversationMaxSeqResp, error) { return nil, nil }
func (t *testMsgClient) PullMessageBySeqs(ctx context.Context, req *sdkws.PullMessageBySeqsReq, opts ...grpc.CallOption) (*sdkws.PullMessageBySeqsResp, error) { return nil, nil }
func (t *testMsgClient) GetSeqMessage(ctx context.Context, req *msg.GetSeqMessageReq, opts ...grpc.CallOption) (*msg.GetSeqMessageResp, error) { return nil, nil }
func (t *testMsgClient) SearchMessage(ctx context.Context, req *msg.SearchMessageReq, opts ...grpc.CallOption) (*msg.SearchMessageResp, error) { return nil, nil }
func (t *testMsgClient) SendMsg(ctx context.Context, req *msg.SendMsgReq, opts ...grpc.CallOption) (*msg.SendMsgResp, error) { return nil, nil }
func (t *testMsgClient) SendSimpleMsg(ctx context.Context, req *msg.SendSimpleMsgReq, opts ...grpc.CallOption) (*msg.SendSimpleMsgResp, error) { return nil, nil }
func (t *testMsgClient) SetUserConversationsMinSeq(ctx context.Context, req *msg.SetUserConversationsMinSeqReq, opts ...grpc.CallOption) (*msg.SetUserConversationsMinSeqResp, error) { return nil, nil }
func (t *testMsgClient) ClearConversationsMsg(ctx context.Context, req *msg.ClearConversationsMsgReq, opts ...grpc.CallOption) (*msg.ClearConversationsMsgResp, error) { return nil, nil }
func (t *testMsgClient) UserClearAllMsg(ctx context.Context, req *msg.UserClearAllMsgReq, opts ...grpc.CallOption) (*msg.UserClearAllMsgResp, error) { return nil, nil }
func (t *testMsgClient) DeleteMsgs(ctx context.Context, req *msg.DeleteMsgsReq, opts ...grpc.CallOption) (*msg.DeleteMsgsResp, error) { return nil, nil }
func (t *testMsgClient) DeleteMsgPhysicalBySeq(ctx context.Context, req *msg.DeleteMsgPhysicalBySeqReq, opts ...grpc.CallOption) (*msg.DeleteMsgPhysicalBySeqResp, error) { return nil, nil }
func (t *testMsgClient) DeleteMsgPhysical(ctx context.Context, req *msg.DeleteMsgPhysicalReq, opts ...grpc.CallOption) (*msg.DeleteMsgPhysicalResp, error) { return nil, nil }
func (t *testMsgClient) SetSendMsgStatus(ctx context.Context, req *msg.SetSendMsgStatusReq, opts ...grpc.CallOption) (*msg.SetSendMsgStatusResp, error) { return nil, nil }
func (t *testMsgClient) GetSendMsgStatus(ctx context.Context, req *msg.GetSendMsgStatusReq, opts ...grpc.CallOption) (*msg.GetSendMsgStatusResp, error) { return nil, nil }
func (t *testMsgClient) RevokeMsg(ctx context.Context, req *msg.RevokeMsgReq, opts ...grpc.CallOption) (*msg.RevokeMsgResp, error) { return nil, nil }
func (t *testMsgClient) MarkMsgsAsRead(ctx context.Context, req *msg.MarkMsgsAsReadReq, opts ...grpc.CallOption) (*msg.MarkMsgsAsReadResp, error) { return nil, nil }
func (t *testMsgClient) MarkConversationAsRead(ctx context.Context, req *msg.MarkConversationAsReadReq, opts ...grpc.CallOption) (*msg.MarkConversationAsReadResp, error) { return nil, nil }
func (t *testMsgClient) SetConversationHasReadSeq(ctx context.Context, req *msg.SetConversationHasReadSeqReq, opts ...grpc.CallOption) (*msg.SetConversationHasReadSeqResp, error) { return nil, nil }
func (t *testMsgClient) GetConversationsHasReadAndMaxSeq(ctx context.Context, req *msg.GetConversationsHasReadAndMaxSeqReq, opts ...grpc.CallOption) (*msg.GetConversationsHasReadAndMaxSeqResp, error) { return nil, nil }
func (t *testMsgClient) GetActiveUser(ctx context.Context, req *msg.GetActiveUserReq, opts ...grpc.CallOption) (*msg.GetActiveUserResp, error) { return nil, nil }
func (t *testMsgClient) GetActiveGroup(ctx context.Context, req *msg.GetActiveGroupReq, opts ...grpc.CallOption) (*msg.GetActiveGroupResp, error) { return nil, nil }
func (t *testMsgClient) GetServerTime(ctx context.Context, req *msg.GetServerTimeReq, opts ...grpc.CallOption) (*msg.GetServerTimeResp, error) { return nil, nil }
func (t *testMsgClient) ClearMsg(ctx context.Context, req *msg.ClearMsgReq, opts ...grpc.CallOption) (*msg.ClearMsgResp, error) { return nil, nil }
func (t *testMsgClient) DestructMsgs(ctx context.Context, req *msg.DestructMsgsReq, opts ...grpc.CallOption) (*msg.DestructMsgsResp, error) { return nil, nil }
func (t *testMsgClient) GetActiveConversation(ctx context.Context, req *msg.GetActiveConversationReq, opts ...grpc.CallOption) (*msg.GetActiveConversationResp, error) { return nil, nil }
func (t *testMsgClient) SetUserConversationMaxSeq(ctx context.Context, req *msg.SetUserConversationMaxSeqReq, opts ...grpc.CallOption) (*msg.SetUserConversationMaxSeqResp, error) { return nil, nil }
func (t *testMsgClient) SetUserConversationMinSeq(ctx context.Context, req *msg.SetUserConversationMinSeqReq, opts ...grpc.CallOption) (*msg.SetUserConversationMinSeqResp, error) { return nil, nil }
func (t *testMsgClient) GetLastMessageSeqByTime(ctx context.Context, req *msg.GetLastMessageSeqByTimeReq, opts ...grpc.CallOption) (*msg.GetLastMessageSeqByTimeResp, error) { return nil, nil }
func (t *testMsgClient) GetLastMessage(ctx context.Context, req *msg.GetLastMessageReq, opts ...grpc.CallOption) (*msg.GetLastMessageResp, error) { return nil, nil }
func (t *testMsgClient) SendBurnMessage(ctx context.Context, req *msg.SendBurnMessageReq, opts ...grpc.CallOption) (*msg.SendBurnMessageResp, error) { return nil, nil }


func TestCleanupBurnMessages(t *testing.T) {
	t.Run("成功清理过期燃烧消息", func(t *testing.T) {
		callCount := 0
		deletedMsgs := []string{}
		
		mockMsgClient := &testMsgClient{
			getExpiredBurnMessagesFunc: func(ctx context.Context, req *msg.GetExpiredBurnMessagesReq) (*msg.GetExpiredBurnMessagesResp, error) {
				callCount++
				if callCount == 1 {
					// 第一次调用返回满批次的过期消息，触发下次调用
					return &msg.GetExpiredBurnMessagesResp{
						Messages: []*msg.BurnMessage{
							{ConversationID: "conv1", Seq: 100, ServerMsgID: "server_msg_1", ClientMsgID: "client_msg_1"},
							{ConversationID: "conv2", Seq: 101, ServerMsgID: "server_msg_2", ClientMsgID: "client_msg_2"},
							{ConversationID: "conv3", Seq: 102, ServerMsgID: "server_msg_3", ClientMsgID: "client_msg_3"},
							{ConversationID: "conv4", Seq: 103, ServerMsgID: "server_msg_4", ClientMsgID: "client_msg_4"},
							{ConversationID: "conv5", Seq: 104, ServerMsgID: "server_msg_5", ClientMsgID: "client_msg_5"},
							{ConversationID: "conv6", Seq: 105, ServerMsgID: "server_msg_6", ClientMsgID: "client_msg_6"},
							{ConversationID: "conv7", Seq: 106, ServerMsgID: "server_msg_7", ClientMsgID: "client_msg_7"},
							{ConversationID: "conv8", Seq: 107, ServerMsgID: "server_msg_8", ClientMsgID: "client_msg_8"},
							{ConversationID: "conv9", Seq: 108, ServerMsgID: "server_msg_9", ClientMsgID: "client_msg_9"},
							{ConversationID: "conv10", Seq: 109, ServerMsgID: "server_msg_10", ClientMsgID: "client_msg_10"},
						},
					}, nil
				}
				// 第二次调用返回空，表示没有更多过期消息
				return &msg.GetExpiredBurnMessagesResp{Messages: []*msg.BurnMessage{}}, nil
			},
			deleteBurnMessageFunc: func(ctx context.Context, req *msg.DeleteBurnMessageReq) (*msg.DeleteBurnMessageResp, error) {
				deletedMsgs = append(deletedMsgs, fmt.Sprintf("%s:%d", req.ConversationID, req.Seq))
				return &msg.DeleteBurnMessageResp{}, nil
			},
		}
		
		// 创建测试服务器
		srv := &cronServer{
			ctx:       context.Background(),
			msgClient: mockMsgClient,
			config: &Config{
				CronTask: config.CronTask{
					BurnMessageCleanEnabled: true,
					BurnMessageCleanBatch:   10,
				},
			},
		}
		
		// 执行清理
		srv.cleanupBurnMessages()
		
		// 验证结果
		assert.Equal(t, 2, callCount)
		assert.Len(t, deletedMsgs, 10)
	})
	
	t.Run("获取过期消息失败", func(t *testing.T) {
		mockMsgClient := &testMsgClient{
			getExpiredBurnMessagesFunc: func(ctx context.Context, req *msg.GetExpiredBurnMessagesReq) (*msg.GetExpiredBurnMessagesResp, error) {
				return nil, errors.New("database error")
			},
		}
		
		srv := &cronServer{
			ctx:       context.Background(),
			msgClient: mockMsgClient,
			config: &Config{
				CronTask: config.CronTask{
					BurnMessageCleanEnabled: true,
					BurnMessageCleanBatch:   10,
				},
			},
		}
		
		// 执行清理（不应该崩溃）
		srv.cleanupBurnMessages()
	})
	
	t.Run("删除消息失败但继续处理其他消息", func(t *testing.T) {
		callCount := 0
		deleteCallCount := 0
		
		mockMsgClient := &testMsgClient{
			getExpiredBurnMessagesFunc: func(ctx context.Context, req *msg.GetExpiredBurnMessagesReq) (*msg.GetExpiredBurnMessagesResp, error) {
				callCount++
				if callCount == 1 {
					// 返回少于批次大小的消息，这样只会调用一次
					return &msg.GetExpiredBurnMessagesResp{
						Messages: []*msg.BurnMessage{
							{ConversationID: "conv1", Seq: 100, ServerMsgID: "server_msg_1", ClientMsgID: "client_msg_1"},
							{ConversationID: "conv2", Seq: 101, ServerMsgID: "server_msg_2", ClientMsgID: "client_msg_2"},
						},
					}, nil
				}
				return &msg.GetExpiredBurnMessagesResp{Messages: []*msg.BurnMessage{}}, nil
			},
			deleteBurnMessageFunc: func(ctx context.Context, req *msg.DeleteBurnMessageReq) (*msg.DeleteBurnMessageResp, error) {
				deleteCallCount++
				if req.ConversationID == "conv1" && req.Seq == 100 {
					return nil, errors.New("delete failed")
				}
				return &msg.DeleteBurnMessageResp{}, nil
			},
		}
		
		srv := &cronServer{
			ctx:       context.Background(),
			msgClient: mockMsgClient,
			config: &Config{
				CronTask: config.CronTask{
					BurnMessageCleanEnabled: true,
					BurnMessageCleanBatch:   10,
				},
			},
		}
		
		// 执行清理
		srv.cleanupBurnMessages()
		
		// 验证调用次数
		assert.Equal(t, 1, callCount)    // GetExpiredBurnMessages 调用1次（因为返回的消息数量小于批次大小）
		assert.Equal(t, 2, deleteCallCount) // DeleteBurnMessage 调用2次
	})
	
	t.Run("默认批次大小", func(t *testing.T) {
		batchSize := int32(0)
		
		mockMsgClient := &testMsgClient{
			getExpiredBurnMessagesFunc: func(ctx context.Context, req *msg.GetExpiredBurnMessagesReq) (*msg.GetExpiredBurnMessagesResp, error) {
				batchSize = req.Limit // 捕获使用的批次大小
				return &msg.GetExpiredBurnMessagesResp{Messages: []*msg.BurnMessage{}}, nil
			},
		}
		
		srv := &cronServer{
			ctx:       context.Background(),
			msgClient: mockMsgClient,
			config: &Config{
				CronTask: config.CronTask{
					BurnMessageCleanEnabled: true,
					BurnMessageCleanBatch:   0, // 应该使用默认值100
				},
			},
		}
		
		srv.cleanupBurnMessages()
		
		// 验证使用了默认批次大小100
		assert.Equal(t, int32(100), batchSize)
	})
}

func TestRegisterBurnMessageCleanup(t *testing.T) {
	t.Run("燃烧消息清理启用", func(t *testing.T) {
		// 使用真实的 cron 实例进行测试，因为我们只测试配置逻辑
		cronInstance := cron.New()
		
		srv := &cronServer{
			ctx:  context.Background(),
			cron: cronInstance,
			config: &Config{
				CronTask: config.CronTask{
					BurnMessageCleanEnabled: true,
					CronExecuteTime:        "*/10 * * * *", // 每10分钟执行一次
				},
			},
		}
		
		// 这个测试主要验证在启用状态下不会出错
		err := srv.registerBurnMessageCleanup()
		assert.NoError(t, err)
	})
	
	t.Run("燃烧消息清理禁用", func(t *testing.T) {
		cronInstance := cron.New()
		
		srv := &cronServer{
			ctx:  context.Background(),
			cron: cronInstance,
			config: &Config{
				CronTask: config.CronTask{
					BurnMessageCleanEnabled: false, // 禁用清理
				},
			},
		}
		
		// 这个测试主要验证在禁用状态下不会出错
		err := srv.registerBurnMessageCleanup()
		assert.NoError(t, err)
	})
}