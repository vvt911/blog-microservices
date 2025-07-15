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
print_status "🗑️  Xóa toàn bộ deployments và resources..."

# Hỏi xác nhận trước khi xóa
echo ""
print_warning "⚠️  CẢNH BÁO: Lệnh này sẽ XÓA HOÀN TOÀN tất cả deployments và resources!"
echo "Bạn có chắc chắn muốn tiếp tục? (y/N)"
read -r confirmation

if [[ $confirmation =~ ^[Yy]$ ]]; then
    print_status "Đang xóa namespace blog-microservices..."
    kubectl delete namespace blog-microservices 2>/dev/null || print_warning "Namespace blog-microservices không tồn tại hoặc đã được xóa"
    
    print_status "Đang xóa monitoring components..."
    kubectl delete deployment grafana -n istio-system 2>/dev/null || print_warning "Grafana đã được xóa hoặc không tồn tại"
    kubectl delete deployment prometheus -n istio-system 2>/dev/null || print_warning "Prometheus đã được xóa hoặc không tồn tại"
    
    # Xóa services related
    kubectl delete service grafana -n istio-system 2>/dev/null || true
    kubectl delete service prometheus -n istio-system 2>/dev/null || true
    
    # Xóa configmaps nếu có
    kubectl delete configmap blog-microservices-dashboard -n istio-system 2>/dev/null || true
    
    print_success "✅ Đã xóa toàn bộ deployments và resources thành công!"
    
    # Kiểm tra lại
    print_status "Kiểm tra kết quả..."
    remaining_pods=$(kubectl get pods -n blog-microservices 2>/dev/null | grep -v "No resources found" | wc -l)
    if [ "$remaining_pods" -eq 0 ]; then
        print_success "Tất cả resources đã được xóa sạch"
    else
        print_warning "Vẫn còn một số resources chưa được xóa"
    fi
else
    print_warning "Hủy bỏ việc xóa deployments. Chỉ dừng port-forwards."
fi

echo ""
print_success "🎉 Hoàn tất việc dọn dẹp hệ thống!"

echo ""
print_status "📋 Lệnh hữu ích:"
echo "   • Kiểm tra pods còn lại: kubectl get pods -A | grep -E '(blog|grafana|prometheus)'"
echo "   • Khởi động lại deployment: ./deploy.sh"
echo "   • Kiểm tra namespaces: kubectl get namespaces"

# Trở về thư mục scripts
cd "${PROJECT_ROOT}/scripts"
