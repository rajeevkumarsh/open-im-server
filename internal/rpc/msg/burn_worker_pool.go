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
	"sync"
	"time"

	"github.com/openimsdk/tools/errs"
	"github.com/openimsdk/tools/log"
)

// burnTask 定义燃烧消息处理任务
type burnTask struct {
	ctx            context.Context
	conversationID string
	seq            int64
	userID         string
}

// BurnWorkerPool 燃烧消息处理工作池
type BurnWorkerPool struct {
	maxWorkers int
	taskQueue  chan burnTask
	wg         sync.WaitGroup
	processor  func(ctx context.Context, conversationID string, seq int64, userID string) error
	closed     chan struct{}
	once       sync.Once
}

// NewBurnWorkerPool 创建新的燃烧消息处理工作池
func NewBurnWorkerPool(maxWorkers int, queueSize int, processor func(ctx context.Context, conversationID string, seq int64, userID string) error) *BurnWorkerPool {
	if maxWorkers <= 0 {
		maxWorkers = 10 // 默认工作线程数
	}
	if queueSize <= 0 {
		queueSize = 1000 // 默认队列大小
	}

	pool := &BurnWorkerPool{
		maxWorkers: maxWorkers,
		taskQueue:  make(chan burnTask, queueSize),
		processor:  processor,
		closed:     make(chan struct{}),
	}

	// 启动工作线程
	pool.start()

	return pool
}

// start 启动工作线程池
func (p *BurnWorkerPool) start() {
	for i := 0; i < p.maxWorkers; i++ {
		p.wg.Add(1)
		go p.worker(i)
	}
}

// worker 工作线程
func (p *BurnWorkerPool) worker(id int) {
	defer p.wg.Done()

	for {
		select {
		case task, ok := <-p.taskQueue:
			if !ok {
				// 队列已关闭
				return
			}

			// 处理任务
			if err := p.processor(task.ctx, task.conversationID, task.seq, task.userID); err != nil {
				log.ZWarn(task.ctx, "burn worker process message failed", err,
					"workerID", id,
					"conversationID", task.conversationID,
					"seq", task.seq,
					"userID", task.userID)
			}

		case <-p.closed:
			// 工作池已关闭
			return
		}
	}
}

// Submit 提交燃烧消息处理任务
func (p *BurnWorkerPool) Submit(ctx context.Context, conversationID string, seq int64, userID string) error {
	// 创建带超时的context，避免任务执行过长
	taskCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 30*time.Second)
	
	task := burnTask{
		ctx:            taskCtx,
		conversationID: conversationID,
		seq:            seq,
		userID:         userID,
	}

	select {
	case p.taskQueue <- task:
		// 任务成功加入队列
		return nil
	case <-ctx.Done():
		// Context已取消
		cancel()
		return ctx.Err()
	case <-p.closed:
		// 工作池已关闭
		cancel()
		return errs.New("worker pool is closed")
	default:
		// 队列已满，异步处理避免阻塞
		go func() {
			defer cancel()
			select {
			case p.taskQueue <- task:
				// 任务成功加入队列
			case <-time.After(5 * time.Second):
				// 超时，记录警告
				log.ZWarn(ctx, "burn task queue is full, dropping task",
					nil,
					"conversationID", conversationID,
					"seq", seq,
					"userID", userID)
			case <-p.closed:
				// 工作池已关闭
			}
		}()
		return nil
	}
}

// Close 关闭工作池
func (p *BurnWorkerPool) Close() {
	p.once.Do(func() {
		close(p.closed)
		close(p.taskQueue)
		p.wg.Wait()
	})
}

// QueueSize 获取当前队列大小
func (p *BurnWorkerPool) QueueSize() int {
	return len(p.taskQueue)
}