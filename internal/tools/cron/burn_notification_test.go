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
	"testing"

	"github.com/openimsdk/protocol/constant"
	"github.com/stretchr/testify/assert"
)

func TestParseConversationID(t *testing.T) {
	server := &cronServer{}
	
	t.Run("单聊会话ID解析", func(t *testing.T) {
		conversationID := "user123_user456"
		sessionType, sendID, recvID := server.parseConversationID(conversationID)
		
		assert.Equal(t, int32(constant.SingleChatType), sessionType)
		assert.Equal(t, "user123", sendID)
		assert.Equal(t, "user456", recvID)
	})
	
	t.Run("群聊会话ID解析", func(t *testing.T) {
		conversationID := "group123"
		sessionType, sendID, recvID := server.parseConversationID(conversationID)
		
		assert.Equal(t, int32(constant.ReadGroupChatType), sessionType)
		assert.Equal(t, "", sendID)
		assert.Equal(t, "group123", recvID)
	})
	
	t.Run("不规范的单聊会话ID", func(t *testing.T) {
		conversationID := "user123_user456_extra"
		sessionType, sendID, recvID := server.parseConversationID(conversationID)
		
		// 应该被解析为群聊（因为不是标准的单聊格式）
		assert.Equal(t, int32(constant.ReadGroupChatType), sessionType)
		assert.Equal(t, "", sendID)
		assert.Equal(t, "user123_user456_extra", recvID)
	})
	
	t.Run("空会话ID", func(t *testing.T) {
		conversationID := ""
		sessionType, sendID, recvID := server.parseConversationID(conversationID)
		
		assert.Equal(t, int32(constant.ReadGroupChatType), sessionType)
		assert.Equal(t, "", sendID)
		assert.Equal(t, "", recvID)
	})
}