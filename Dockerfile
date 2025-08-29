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

# Create startup script with Discord notification
COPY <<EOF /usr/local/bin/start-openim.sh
#!/bin/bash
cd /openim-server

# Discord webhook URL
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1410921882714116227/M4NJjctluETrJk5JnWwW8U0uWCcgO_MYSCy-w8QefRI56zmMkY3Ii5C47MegO4A_1Vjm"

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
                {\"name\": \"容器\", \"value\": \"\$(hostname)\", \"inline\": true},
                {\"name\": \"启动时间\", \"value\": \"\$(date)\", \"inline\": true}
            ]
        }]
    }" 2>/dev/null || echo "Discord notification failed"
}

# Function to monitor mage start and send notifications
start_with_notification() {
    echo "Starting OpenIM Server using mage start..."
    
    # Run mage start in background and capture its process
    mage start &
    MAGE_PID=\$!
    
    # Wait a bit for services to initialize
    sleep 20
    
    # Check if mage process is still running (services started successfully)
    if kill -0 \$MAGE_PID 2>/dev/null; then
        # Test API endpoint to confirm services are working
        if curl -X POST http://localhost:10002/msg/get_server_time >/dev/null 2>&1; then
            echo "✅ OpenIM Server started successfully"
            send_notification "✅ OpenIM Server - 服务启动成功" "通过mage start启动，所有服务正常响应" "3066993"
        else
            echo "⚠️ Services started but API not responding"
            send_notification "⚠️ OpenIM Server - 服务启动异常" "mage start已执行但API响应异常" "16776960"
        fi
        
        # Wait for mage process to complete
        wait \$MAGE_PID
    else
        echo "❌ mage start failed"
        send_notification "❌ OpenIM Server - 启动失败" "mage start命令执行失败" "15158332"
        exit 1
    fi
}

# Wait for dependencies
echo "Waiting for dependencies to be ready..."
sleep 10

# Start OpenIM using mage with notification
start_with_notification
EOF

RUN chmod +x /usr/local/bin/start-openim.sh

# Set the command to run when the container starts
ENTRYPOINT ["/usr/local/bin/start-openim.sh"]
