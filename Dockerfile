# Use Go 1.22 Alpine as the base image for building the application
FROM golang:1.22-alpine AS builder

# Define the base directory for the application as an environment variable
ENV SERVER_DIR=/openim-server

# Set the working directory inside the container based on the environment variable
WORKDIR $SERVER_DIR

# Set the Go proxy to improve dependency resolution speed
# ENV GOPROXY=https://goproxy.io,direct

# Copy all files from the current directory into the container
COPY . .

RUN go mod download

# Install Mage to use for building the application
RUN go install github.com/magefile/mage@v1.15.0

# Build application for Linux AMD64 platform
ENV GOOS=linux GOARCH=amd64
RUN mage build

# Using Alpine Linux with Go environment for the final image
FROM golang:1.22-alpine

# Install necessary packages, such as bash
RUN apk add --no-cache bash

# Set the environment and work directory
ENV SERVER_DIR=/openim-server
WORKDIR $SERVER_DIR


# Copy the compiled binaries and mage from the builder image to the final image
COPY --from=builder $SERVER_DIR/_output $SERVER_DIR/_output
COPY --from=builder $SERVER_DIR/config $SERVER_DIR/config
COPY --from=builder /go/bin/mage /usr/local/bin/mage
COPY --from=builder $SERVER_DIR/magefile_windows.go $SERVER_DIR/
COPY --from=builder $SERVER_DIR/magefile_unix.go $SERVER_DIR/
COPY --from=builder $SERVER_DIR/magefile.go $SERVER_DIR/
COPY --from=builder $SERVER_DIR/start-config.yml $SERVER_DIR/
COPY --from=builder $SERVER_DIR/go.mod $SERVER_DIR/
COPY --from=builder $SERVER_DIR/go.sum $SERVER_DIR/

RUN go get github.com/openimsdk/gomake@v0.0.15-alpha.11

# Create startup script
COPY <<EOF /usr/local/bin/start-openim.sh
#!/bin/bash
cd /openim-server

# Discord webhook URL
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1410921882714116227/M4NJjctluETrJk5JnWwW8U0uWCcgO_MYSCy-w8QefRI56zmMkY3Ii5C47MegO4A_1Vjm"

# Get current time and image info
CURRENT_TIME=\$(date)
HOSTNAME=\$(hostname)

# Send startup notification
send_notification() {
    local title="\$1"
    local description="\$2"
    local color="\$3"
    
    curl -X POST "\$DISCORD_WEBHOOK_URL" -H "Content-Type: application/json" -d "{
        \"embeds\": [{
            \"title\": \"\$title\",
            \"description\": \"\$description\",
            \"color\": \$color,
            \"fields\": [
                {\"name\": \"容器\", \"value\": \"\$HOSTNAME\", \"inline\": true},
                {\"name\": \"启动时间\", \"value\": \"\$CURRENT_TIME\", \"inline\": true}
            ]
        }]
    }" 2>/dev/null || echo "Discord notification failed"
}

# Wait for dependencies to be ready
echo "Waiting for dependencies..."
sleep 10

# Start OpenIM services in background
echo "Starting OpenIM services..."
nohup ./_output/bin/openim-api --config /openim/config > /openim/logs/openim-api.log 2>&1 &
nohup ./_output/bin/openim-rpc-user --config /openim/config > /openim/logs/openim-rpc-user.log 2>&1 &
nohup ./_output/bin/openim-rpc-friend --config /openim/config > /openim/logs/openim-rpc-friend.log 2>&1 &
nohup ./_output/bin/openim-rpc-msg --config /openim/config > /openim/logs/openim-rpc-msg.log 2>&1 &
nohup ./_output/bin/openim-rpc-conversation --config /openim/config > /openim/logs/openim-rpc-conversation.log 2>&1 &
nohup ./_output/bin/openim-rpc-group --config /openim/config > /openim/logs/openim-rpc-group.log 2>&1 &
nohup ./_output/bin/openim-rpc-auth --config /openim/config > /openim/logs/openim-rpc-auth.log 2>&1 &
nohup ./_output/bin/openim-rpc-third --config /openim/config > /openim/logs/openim-rpc-third.log 2>&1 &
nohup ./_output/bin/openim-push --config /openim/config > /openim/logs/openim-push.log 2>&1 &
nohup ./_output/bin/openim-msgtransfer --config /openim/config > /openim/logs/openim-msgtransfer.log 2>&1 &
nohup ./_output/bin/openim-msggateway --config /openim/config > /openim/logs/openim-msggateway.log 2>&1 &
nohup ./_output/bin/openim-crontask --config /openim/config > /openim/logs/openim-crontask.log 2>&1 &

echo "All services started. Waiting for service initialization..."
sleep 15

# Test if API is responding
if curl -X POST http://localhost:10002/msg/get_server_time >/dev/null 2>&1; then
    echo "✅ OpenIM Server started successfully"
    send_notification "✅ OpenIM Server - 服务启动成功" "所有服务组件已启动并正常响应" "3066993"
else
    echo "⚠️ OpenIM Server may have issues"
    send_notification "⚠️ OpenIM Server - 服务启动异常" "服务已启动但API响应异常，请检查日志" "16776960"
fi

echo "Container is ready. Keeping running..."
# Keep container running
tail -f /dev/null
EOF

RUN chmod +x /usr/local/bin/start-openim.sh

# Set the command to run when the container starts
ENTRYPOINT ["/usr/local/bin/start-openim.sh"]
