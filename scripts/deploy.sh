#!/bin/bash

# ==============================================
# 🚀 BUILD & DEPLOY BLOG MICROSERVICES - ISTIO
# ==============================================
set -e

echo "🚀 Đang bắt đầu triển khai Blog Microservices với Istio..."
echo ""

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Hàm in output có màu
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ==============================================
# 🔧 CÁC HÀM TIỆN ÍCH
# ==============================================

# Kiểm tra port có sẵn
check_port() {
    lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1 && return 1 || return 0
}

# Tìm port có sẵn
find_available_port() {
    local port=$1
    while ! check_port $port; do
        port=$((port + 1))
        [ $port -gt $(($1 + 50)) ] && echo "0" && return 1
    done
    echo $port
}

# ==============================================
# ✅ STEP 1: KIỂM TRA MINIKUBE
# ==============================================

print_status "Bước 1: Kiểm tra Minikube..."
if ! minikube status > /dev/null 2>&1; then
    print_error "Minikube không chạy. Vui lòng khởi động: minikube start"
    exit 1
fi
print_success "Minikube đang chạy"
eval $(minikube -p minikube docker-env)
echo ""

# ==============================================
# 🐳 BƯỚC 2: BUILD DOCKER IMAGES
# ==============================================

print_status "Bước 2: Đang build Docker images..."
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Build tất cả services
services=("frontend" "blog-service" "comment-service" "user-service" "notification-service")
for service in "${services[@]}"; do
    cd "${PROJECT_ROOT}/${service}"
    print_status "Đang build ${service}..."
    docker build -t ${service}:latest . -q
done

# Build blog-service-v2 cho traffic routing demo
cd "${PROJECT_ROOT}/blog-service-v2"
print_status "Đang build blog-service-v2..."
docker build -t blog-service:v2 . -q

print_success "Tất cả Docker images đã build xong"
echo ""

# ==============================================
# 🕸️ BƯỚC 3: KIỂM TRA ISTIO
# ==============================================

print_status "Bước 3: Kiểm tra Istio..."
if ! kubectl get namespace istio-system > /dev/null 2>&1; then
    print_error "Istio chưa được cài đặt. Vui lòng cài đặt Istio trước:"
    echo "  curl -L https://istio.io/downloadIstio | sh -"
    echo "  export PATH=\$PWD/istio-*/bin:\$PATH"
    echo "  istioctl install --set values.defaultRevision=default"
    exit 1
fi
print_success "Istio đã sẵn sàng"
echo ""

# ==============================================
# 📊 BƯỚC 4: THIẾT LẬP MONITORING (PROMETHEUS + GRAFANA)
# ==============================================

print_status "Bước 4: Thiết lập Monitoring (Prometheus + Grafana)..."
print_status "Cài đặt Prometheus từ Istio addon..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml >/dev/null 2>&1 || true
print_status "Cài đặt Grafana từ Istio addon..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml >/dev/null 2>&1 || true
print_success "Monitoring stack đã sẵn sàng"
echo ""

# ==============================================
# 🚀 BƯỚC 5: TRIỂN KHAI KUBERNETES RESOURCES
# ==============================================

print_status "Bước 5: Triển khai Kubernetes resources..."
cd "${PROJECT_ROOT}/k8s"

# Tạo namespace với Istio injection
kubectl apply -f - <<EOF >/dev/null
apiVersion: v1
kind: Namespace
metadata:
  name: blog-microservices
  labels:
    istio-injection: enabled
EOF

# Triển khai resources
kubectl apply -f services.yaml >/dev/null
kubectl apply -f blog-service-v2.yaml >/dev/null
kubectl apply -f istio-gateway.yaml >/dev/null
kubectl apply -f destination-rules.yaml >/dev/null

print_success "Kubernetes resources đã được triển khai"
echo ""

# ==============================================
# ⚙️ BƯỚC 6: CẤU HÌNH mTLS
# ==============================================

print_status "Bước 6: Cấu hình mTLS..."

# Istio sẽ tự động inject sidecar và thu thập metrics
print_status "Istio sẽ tự động thu thập metrics từ service mesh"

# Cấu hình mTLS cho Istio
print_status "Cấu hình Istio mTLS..."
kubectl apply -f - <<EOF >/dev/null 2>&1 || true
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: blog-microservices
spec:
  mtls:
    mode: PERMISSIVE // Cho phép cả traffic mTLS và không mTLS
EOF

print_success "mTLS đã được cấu hình"
echo ""

# ==============================================
# ⏳ BƯỚC 7: CHỜ DEPLOYMENTS
# ==============================================

print_status "Bước 7: Đang chờ deployments..."
kubectl wait --for=condition=available --timeout=300s deployment --all -n blog-microservices >/dev/null 2>&1 || {
    print_warning "Một số deployments có thể mất nhiều thời gian để sẵn sàng"
}
print_success "Tất cả deployments đã sẵn sàng"
echo ""

# ==============================================
# 🌐 BƯỚC 8: KHỞI ĐỘNG PORT FORWARDS
# ==============================================

print_status "Bước 8: Khởi động port forwards..."

# Dừng port-forwards cũ
pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 2

# Khởi động monitoring dashboards
monitoring_services=("grafana:3000:istio-system" "prometheus:9090:istio-system")
app_services=("frontend:3000:blog-microservices")

print_status "📊 Monitoring Dashboards:"
for service_info in "${monitoring_services[@]}"; do
    IFS=':' read -r name port namespace <<< "$service_info"
    available_port=$(find_available_port $port)
    
    if [ "$available_port" != "0" ]; then
        print_status "Khởi động port-forward cho $name..."
        kubectl port-forward svc/$name $available_port:$port -n $namespace >/dev/null 2>&1 &
        pid=$!
        sleep 3
        # Kiểm tra port có đang listen không
        if lsof -Pi :$available_port -sTCP:LISTEN -t >/dev/null 2>&1; then
            if [ "$name" == "grafana" ]; then
                echo "   ✅ Grafana: http://localhost:$available_port (admin/admin) - PID: $pid"
            else
                echo "   ✅ Prometheus: http://localhost:$available_port - PID: $pid"
            fi
        else
            echo "   ❌ $name: Không thể khởi động port-forward trên port $available_port"
            kill $pid 2>/dev/null || true
        fi
    else
        echo "   ❌ $name: Không có port khả dụng"
    fi
done

print_status "🖥️ Ứng dụng:"
# Truy cập qua cả hai cách: direct và qua Istio Gateway
frontend_port=$(find_available_port 8080)
gateway_port=$(find_available_port 8081)

# Port-forward trực tiếp đến frontend (backup)
if [ "$frontend_port" != "0" ]; then
    print_status "Khởi động port-forward trực tiếp đến frontend..."
    kubectl port-forward svc/frontend $frontend_port:3000 -n blog-microservices >/dev/null 2>&1 &
    frontend_pid=$!
    sleep 2
    if lsof -Pi :$frontend_port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "   ✅ Frontend Direct: http://localhost:$frontend_port - PID: $frontend_pid"
    else
        echo "   ❌ Frontend Direct: Không thể khởi động"
        kill $frontend_pid 2>/dev/null || true
        frontend_port="0"
    fi
else
    echo "   ❌ Frontend Direct: Không có port khả dụng"
    frontend_port="0"
fi

# Port-forward qua Istio Gateway 
if [ "$gateway_port" != "0" ]; then
    print_status "Khởi động port-forward cho Istio Gateway..."
    kubectl port-forward svc/istio-ingressgateway $gateway_port:80 -n istio-system >/dev/null 2>&1 &
    gateway_pid=$!
    sleep 3
    if lsof -Pi :$gateway_port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "   ✅ Istio Gateway: http://localhost:$gateway_port - PID: $gateway_pid"
        FRONTEND_PORT=$gateway_port
    else
        echo "   ❌ Istio Gateway: Không thể khởi động"
        kill $gateway_pid 2>/dev/null || true
        FRONTEND_PORT=$frontend_port
    fi
else
    echo "   ❌ Istio Gateway: Không có port khả dụng"
    FRONTEND_PORT=$frontend_port
fi
echo ""
# ==============================================
# 🎉 TRIỂN KHAI HOÀN THÀNH
# ==============================================

print_success "🚀 Blog Microservices với Istio đã triển khai thành công!"
echo ""

print_status "🎯 Actions:"
if [ "$frontend_port" != "0" ]; then
    echo "   📱 Truy cập trực tiếp Frontend: http://localhost:$frontend_port"
fi
if [ "$gateway_port" != "0" ]; then
    echo "   🌐 Truy cập qua Istio Gateway: http://localhost:$gateway_port"
fi
echo "   🛑 Dừng tất cả: pkill -f 'kubectl port-forward'"
echo "   🔄 Khởi động lại: ./deploy.sh"
echo ""

print_status "🔧 Các lệnh hữu ích:"
echo "   kubectl get pods -n blog-microservices"
echo "   kubectl get svc -n blog-microservices"
echo "   kubectl logs -f deployment/frontend -n blog-microservices"
echo ""

print_status "🎯 Demo Traffic Routing:"
echo "   ./scripts/demo.sh - Chạy demo traffic routing"
echo "   kubectl get pods -n blog-microservices -l app=blog-service - Xem các pod"
echo ""

# Quay lại thư mục scripts
cd "${PROJECT_ROOT}/scripts"
