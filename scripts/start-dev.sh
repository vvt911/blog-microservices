#!/bin/bash

# Start local development environment
set -e

echo "🚀 Starting Blog Microservices in development mode..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to check if port is available
check_port() {
    if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null ; then
        echo "Port $1 is already in use"
        return 1
    fi
    return 0
}

# Check Node.js installation
if ! command -v node &> /dev/null; then
    echo "Node.js is not installed. Please install Node.js first."
    exit 1
fi

print_success "Node.js is available"

# Check ports
print_status "Checking if ports are available..."
for port in 3000 3001 3002 3003 3004; do
    if ! check_port $port; then
        echo "Please stop the process using port $port first"
        exit 1
    fi
done

print_success "All ports are available"

# Install dependencies for all services
print_status "Installing dependencies..."

cd ../frontend
print_status "Installing frontend dependencies..."
npm install

cd ../blog-service
print_status "Installing blog-service dependencies..."
npm install

cd ../comment-service
print_status "Installing comment-service dependencies..."
npm install

cd ../user-service
print_status "Installing user-service dependencies..."
npm install

cd ../notification-service
print_status "Installing notification-service dependencies..."
npm install

cd ../scripts

print_success "All dependencies installed"

# Start services in background
print_status "Starting services..."

cd ../notification-service
print_status "Starting notification-service on port 3004..."
npm start &
NOTIFICATION_PID=$!

cd ../user-service
print_status "Starting user-service on port 3003..."
npm start &
USER_PID=$!

cd ../comment-service
print_status "Starting comment-service on port 3002..."
npm start &
COMMENT_PID=$!

cd ../blog-service
print_status "Starting blog-service on port 3001..."
npm start &
BLOG_PID=$!

# Wait a bit for backend services to start
sleep 3

cd ../frontend
print_status "Starting frontend on port 3000..."
npm start &
FRONTEND_PID=$!

cd ../scripts

# Wait for services to start
sleep 5

print_success "🎉 All services started successfully!"
echo ""
print_status "📋 Service Information:"
echo -e "   ${GREEN}Frontend:${NC}           http://localhost:3000"
echo -e "   ${GREEN}Blog Service:${NC}       http://localhost:3001"
echo -e "   ${GREEN}Comment Service:${NC}    http://localhost:3002"
echo -e "   ${GREEN}User Service:${NC}       http://localhost:3003"
echo -e "   ${GREEN}Notification Service:${NC} http://localhost:3004"
echo ""
print_status "🔧 Health Check URLs:"
echo "   curl http://localhost:3001/health"
echo "   curl http://localhost:3002/health"
echo "   curl http://localhost:3003/health"
echo "   curl http://localhost:3004/health"
echo ""
print_status "🛑 To stop all services:"
echo "   ./stop-dev.sh"
echo ""

# Save PIDs to file for cleanup
echo $FRONTEND_PID > .frontend.pid
echo $BLOG_PID > .blog.pid
echo $COMMENT_PID > .comment.pid
echo $USER_PID > .user.pid
echo $NOTIFICATION_PID > .notification.pid

print_status "PIDs saved to .*.pid files"
print_status "Services are running in the background..."
