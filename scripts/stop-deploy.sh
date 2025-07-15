#!/bin/bash

# Dừng tất cả các port-forwards được khởi chạy từ deploy.sh
set -e

echo "🛑 Đang dừng Blog Microservices port-forwards..."

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Không màu

# Hàm để in output có màu
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Lấy thư mục gốc của project
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Kiểm tra và hiển thị port-forwards hiện tại
print_status "Kiểm tra port-forwards hiện tại..."
port_forwards=$(pgrep -f "kubectl port-forward" 2>/dev/null || echo "")

if [ -n "$port_forwards" ]; then
    echo "Tìm thấy các port-forwards đang chạy:"
    echo "$port_forwards" | while read pid; do
        if [ -n "$pid" ]; then
            process_info=$(ps -p $pid -o args= 2>/dev/null || echo "Process không tồn tại")
            echo "   PID: $pid - $process_info"
        fi
    done
    
    # Dừng tất cả port-forwards
    print_status "Đang dừng tất cả port-forwards..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 2
    
    # Kiểm tra lại
    remaining=$(pgrep -f "kubectl port-forward" 2>/dev/null || echo "")
    if [ -z "$remaining" ]; then
        print_success "Đã dừng tất cả port-forwards thành công"
    else
        print_warning "Một số port-forwards vẫn còn chạy"
    fi
else
    print_warning "Không tìm thấy port-forwards nào đang chạy"
fi

echo ""
print_success "🎉 Hoàn tất việc dừng port-forwards!"

echo ""
print_status "� Lệnh hữu ích:"
echo "   • Kiểm tra port-forwards: pgrep -f 'kubectl port-forward'"
echo "   • Khởi động lại deployment: ./deploy.sh"
echo "   • Kiểm tra pods: kubectl get pods -n blog-microservices"
echo "   • Kiểm tra services: kubectl get svc -n blog-microservices"

# Trở về thư mục scripts
cd "${PROJECT_ROOT}/scripts"
