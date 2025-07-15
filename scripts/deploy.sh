#!/bin/bash

# Build và Deploy Blog Microservices với Istio
set -e

echo "🚀 Đang bắt đầu triển khai Blog Microservices với Istio..."

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

# Hàm kiểm tra port có sẵn không
check_port() {
    if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 1  # Port đang được sử dụng
    fi
    return 0  # Port có sẵn
}

# Hàm tìm port có sẵn
find_available_port() {
    local base_port=$1
    local port=$base_port
    
    while ! check_port $port; do
        port=$((port + 1))
        if [ $port -gt $((base_port + 50)) ]; then
            echo "0"  # Không tìm thấy port có sẵn
            return 1
        fi
    done
    echo $port
}

# Kiểm tra xem minikube có đang chạy không
print_status "Đang kiểm tra trạng thái Minikube..."
if ! minikube status > /dev/null 2>&1; then
    print_error "Minikube không chạy. Vui lòng khởi động minikube trước:"
    echo "minikube start"
    exit 1
fi
print_success "Minikube đang chạy"

# Chuyển sang môi trường docker của minikube
print_status "Đang chuyển sang môi trường Docker của Minikube..."
eval $(minikube -p minikube docker-env)

# Build Docker images
print_status "Đang build Docker images..."

# Lấy thư mục gốc của project
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "${PROJECT_ROOT}/frontend"
print_status "Đang build frontend image..."
docker build -t blog-frontend:latest .

cd "${PROJECT_ROOT}/blog-service"
print_status "Đang build blog-service image..."
docker build -t blog-service:latest .

cd "${PROJECT_ROOT}/comment-service"
print_status "Đang build comment-service image..."
docker build -t comment-service:latest .

cd "${PROJECT_ROOT}/user-service"
print_status "Đang build user-service image..."
docker build -t user-service:latest .

cd "${PROJECT_ROOT}/notification-service"
print_status "Đang build notification-service image..."
docker build -t notification-service:latest .

print_success "Tất cả Docker images đã được build thành công"

# Kiểm tra xem Istio đã được cài đặt chưa
print_status "Đang kiểm tra cài đặt Istio..."
if ! kubectl get namespace istio-system > /dev/null 2>&1; then
    print_error "Istio chưa được cài đặt. Vui lòng cài đặt Istio trước:"
    echo "curl -L https://istio.io/downloadIstio | sh -"
    echo "export PATH=\$PWD/istio-*/bin:\$PATH"
    echo "istioctl install --set values.defaultRevision=default"
    exit 1
fi
print_success "Istio đã được cài đặt"

# Cài đặt Istio addons để monitoring
print_status "Đang cài đặt Istio monitoring addons..."

# Dọn dẹp các components cũ nếu có
print_status "Dọn dẹp Kiali và Jaeger cũ (nếu có)..."
kubectl delete deployment kiali -n istio-system 2>/dev/null || true
kubectl delete service kiali -n istio-system 2>/dev/null || true
kubectl delete deployment jaeger -n istio-system 2>/dev/null || true
kubectl delete service jaeger -n istio-system 2>/dev/null || true
kubectl delete service jaeger-collector -n istio-system 2>/dev/null || true
kubectl delete service tracing -n istio-system 2>/dev/null || true
kubectl delete service zipkin -n istio-system 2>/dev/null || true

# Hàm để cài đặt component một cách an toàn
install_component() {
    local component=$1
    local url=$2
    
    print_status "Đang cài đặt $component..."
    
    if kubectl get deployment $component -n istio-system > /dev/null 2>&1; then
        print_warning "$component đã được cài đặt rồi, bỏ qua..."
        return 0
    fi
    
    # Download và apply
    if curl -s $url | kubectl apply -f -; then
        print_success "$component đã được cài đặt thành công"
        # Đợi deployment có sẵn
        kubectl wait --for=condition=available --timeout=180s deployment/$component -n istio-system 2>/dev/null || {
            print_warning "$component deployment có thể cần nhiều thời gian hơn để sẵn sàng"
        }
    else
        print_error "Lỗi khi cài đặt $component"
        return 1
    fi
}

# Cài đặt các components
install_component "prometheus" "https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml"
install_component "grafana" "https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml"

print_success "Monitoring stack đã được cài đặt thành công"

# Triển khai Kubernetes resources
print_status "Đang triển khai Kubernetes resources..."

cd "${PROJECT_ROOT}/k8s"

# Tạo namespace và bật Istio injection
print_status "Đang tạo namespace..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: blog-microservices
  labels:
    istio-injection: enabled
EOF

# Triển khai services
print_status "Đang triển khai services..."
kubectl apply -f services.yaml

# Triển khai Istio configurations
print_status "Đang triển khai Istio Gateway..."
kubectl apply -f istio-gateway.yaml

print_status "Đang triển khai Destination Rules..."
kubectl apply -f destination-rules.yaml

# Triển khai Grafana dashboard
print_status "Đang triển khai custom Grafana dashboard..."
kubectl apply -f grafana-dashboard.yaml

# Cấu hình monitoring
print_status "Đang cấu hình Prometheus monitoring..."

# Cấu hình Prometheus scraping cho microservices
print_status "Đang thêm Prometheus scraping annotations cho services..."
for service in frontend blog-service comment-service user-service notification-service; do
    kubectl patch service $service -n blog-microservices -p '{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/port":"3000","prometheus.io/path":"/metrics"}}}' 2>/dev/null || true
done

# Cấu hình Istio telemetry cơ bản
kubectl apply -f - <<EOF > /dev/null 2>&1 || print_warning "Cấu hình Telemetry có thể đã thất bại"
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: blog-microservices
spec:
  mtls:
    mode: PERMISSIVE
EOF

print_success "Cấu hình monitoring đã hoàn tất"

print_success "Tất cả resources đã được triển khai thành công"

# Đợi các deployments sẵn sàng
print_status "Đang đợi các deployments sẵn sàng..."
kubectl wait --for=condition=available --timeout=300s deployment --all -n blog-microservices

print_success "Tất cả deployments đã sẵn sàng"

print_success "🎉 Triển khai hoàn tất thành công!"
echo ""

# Hàm dừng các port-forwards hiện tại
stop_existing_port_forwards() {
    print_status "Đang dừng các port-forwards hiện tại..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 2
}

# Dừng các port-forwards hiện tại trước
stop_existing_port_forwards

print_status "📊 Đang khởi động Monitoring Dashboards:"

# Khởi động các monitoring tools
monitoring_services=(
    "grafana:3000:istio-system"
    "prometheus:9090:istio-system"
)

app_services=(
    "frontend:3000:blog-microservices"
)

for service_info in "${monitoring_services[@]}"; do
    IFS=':' read -r service_name service_port namespace <<< "$service_info"
    port=$(find_available_port $service_port)
    if [ "$port" != "0" ]; then
        kubectl port-forward svc/$service_name $port:$service_port -n $namespace > /dev/null 2>&1 &
        pid=$!
        if [ "$service_name" == "grafana" ]; then
            echo "   ✅ Grafana: http://localhost:$port (admin/admin) - PID: $pid"
        else
            service_display=$(echo "$service_name" | sed 's/^./\U&/')
            echo "   ✅ $service_display: http://localhost:$port - PID: $pid"
        fi
    else
        service_display=$(echo "$service_name" | sed 's/^./\U&/')
        echo "   ❌ $service_display: Không tìm thấy port có sẵn"
    fi
done

for service_info in "${app_services[@]}"; do
    IFS=':' read -r service_name service_port namespace <<< "$service_info"
    port=$(find_available_port 8080)
    if [ "$port" != "0" ]; then
        kubectl port-forward svc/$service_name $port:$service_port -n $namespace > /dev/null 2>&1 &
        pid=$!
        echo "   ✅ Frontend App: http://localhost:$port - PID: $pid"
        FRONTEND_PORT=$port
    else
        echo "   ❌ Frontend: Không tìm thấy port có sẵn"
        FRONTEND_PORT="0"
    fi
done

echo ""
print_success "🚀 Blog Microservices với Istio đã triển khai hoàn toàn!"

echo ""
print_status "🎯 Hành động nhanh:"
if [ "$FRONTEND_PORT" != "0" ]; then
    echo "   📱 Truy cập ứng dụng: http://localhost:$FRONTEND_PORT"
fi
echo "   🛑 Dừng tất cả Port-forwards: pkill -f 'kubectl port-forward'"

echo ""
print_status "🔧 Lệnh Kubernetes hữu ích:"
echo "   kubectl get pods -n blog-microservices"
echo "   kubectl get svc -n blog-microservices"

# Trở về thư mục scripts
cd "${PROJECT_ROOT}/scripts"
