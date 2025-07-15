#!/bin/bash

# Khởi động môi trường phát triển local
set -e

echo "🚀 Đang khởi động Blog Microservices ở chế độ phát triển..."

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Không màu

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Hàm kiểm tra port có sẵn không
check_port() {
    if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null ; then
        echo "Port $1 đã được sử dụng"
        return 1
    fi
    return 0
}

# Kiểm tra cài đặt Node.js
if ! command -v node &> /dev/null; then
    echo "Node.js chưa được cài đặt. Vui lòng cài đặt Node.js trước."
    exit 1
fi

print_success "Node.js đã sẵn sàng"

# Kiểm tra các port
print_status "Đang kiểm tra port có sẵn không..."
for port in 3000 3001 3002 3003 3004; do
    if ! check_port $port; then
        echo "Vui lòng dừng tiến trình đang sử dụng port $port trước"
        exit 1
    fi
done

print_success "Tất cả port đều có sẵn"

# Cài đặt dependencies cho tất cả services
print_status "Đang cài đặt dependencies..."

cd ../frontend
print_status "Đang cài đặt dependencies cho frontend..."
npm install

cd ../blog-service
print_status "Đang cài đặt dependencies cho blog-service..."
npm install

cd ../comment-service
print_status "Đang cài đặt dependencies cho comment-service..."
npm install

cd ../user-service
print_status "Đang cài đặt dependencies cho user-service..."
npm install

cd ../notification-service
print_status "Đang cài đặt dependencies cho notification-service..."
npm install

cd ../scripts

print_success "Đã cài đặt xong tất cả dependencies"

# Khởi động các services ở chế độ background
print_status "Đang khởi động các services..."

cd ../notification-service
print_status "Đang khởi động notification-service trên port 3004..."
npm start &
NOTIFICATION_PID=$!

cd ../user-service
print_status "Đang khởi động user-service trên port 3003..."
npm start &
USER_PID=$!

cd ../comment-service
print_status "Đang khởi động comment-service trên port 3002..."
npm start &
COMMENT_PID=$!

cd ../blog-service
print_status "Đang khởi động blog-service trên port 3001..."
npm start &
BLOG_PID=$!

# Đợi một chút để các backend services khởi động
sleep 3

cd ../frontend
print_status "Đang khởi động frontend trên port 3000..."
npm start &
FRONTEND_PID=$!

cd ../scripts

# Đợi các services khởi động
sleep 5

print_success "🎉 Tất cả services đã khởi động thành công!"
echo ""
print_status "📋 Thông tin Services:"
echo -e "   ${GREEN}Frontend:${NC}           http://localhost:3000"
echo -e "   ${GREEN}Blog Service:${NC}       http://localhost:3001"
echo -e "   ${GREEN}Comment Service:${NC}    http://localhost:3002"
echo -e "   ${GREEN}User Service:${NC}       http://localhost:3003"
echo -e "   ${GREEN}Notification Service:${NC} http://localhost:3004"
echo ""
print_status "🔧 URLs kiểm tra tình trạng:"
echo "   curl http://localhost:3001/health"
echo "   curl http://localhost:3002/health"
echo "   curl http://localhost:3003/health"
echo "   curl http://localhost:3004/health"
echo ""
print_status "🛑 Để dừng tất cả services:"
echo "   ./stop-dev.sh"
echo ""

# Lưu PIDs vào file để cleanup
echo $FRONTEND_PID > .frontend.pid
echo $BLOG_PID > .blog.pid
echo $COMMENT_PID > .comment.pid
echo $USER_PID > .user.pid
echo $NOTIFICATION_PID > .notification.pid

print_status "PIDs đã được lưu vào các file .*.pid"
print_status "Các services đang chạy ở background..."
