#!/bin/bash

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

# Cleanup function
cleanup() {
    print_status "Dọn dẹp resources..."
    kubectl delete pod test-mtls -n blog-microservices 2>/dev/null || true
    kubectl delete pod test-mtls-with-sidecar -n blog-microservices 2>/dev/null || true
}

# Trap cleanup function, script dừng cleanup tự chạy
# trap cleanup EXIT

echo "🔒 Bắt đầu test mTLS..."
echo "================================================="

# Test Case 1: Kiểm tra mode mTLS hiện tại
echo ""
print_status "Test Case 1: Kiểm tra mode mTLS hiện tại"
MTLS_MODE=$(kubectl get peerauthentication -n blog-microservices -o jsonpath='{.items[0].spec.mtls.mode}')
echo "Mode mTLS hiện tại: $MTLS_MODE"
echo ""

# Test Case 2: Tạo pod không có Istio sidecar
echo ""
print_status "Test Case 2: Tạo pod test không có Istio sidecar"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-mtls
  namespace: blog-microservices
  labels:
    app: test-mtls
  annotations:
    sidecar.istio.io/inject: "false"
spec:
  containers:
  - name: curl
    image: curlimages/curl
    command: ["sleep", "infinity"]
EOF

# Chờ pod sẵn sàng
print_status "Đang chờ pod test-mtls sẵn sàng..."
kubectl wait --for=condition=ready pod/test-mtls -n blog-microservices --timeout=60s

# Test Case 3: Tạo pod có Istio sidecar
echo ""
print_status "Test Case 3: Tạo pod test có Istio sidecar"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-mtls-with-sidecar
  namespace: blog-microservices
  labels:
    app: test-mtls-with-sidecar
spec:
  containers:
  - name: curl
    image: curlimages/curl
    command: ["sleep", "infinity"]
EOF

# Chờ pod sẵn sàng
print_status "Đang chờ pod test-mtls-with-sidecar sẵn sàng..."
kubectl wait --for=condition=ready pod/test-mtls-with-sidecar -n blog-microservices --timeout=60s

echo ""
print_status "Test với PERMISSIVE mode..."
echo "================================================="

# Test Case 4: Test kết nối từ pod không có sidecar
print_status "Test Case 4: Test kết nối từ pod không có sidecar đến blog-service (Kỳ vọng: thành công)"
kubectl exec -n blog-microservices test-mtls -- curl -I http://blog-service:3001/health
echo ""

# Test Case 5: Test kết nối từ pod có sidecar
echo ""
print_status "Test Case 5: Test kết nối từ pod có sidecar đến blog-service (Kỳ vọng: thành công)"
kubectl exec -n blog-microservices test-mtls-with-sidecar -- curl -I http://blog-service:3001/health
echo ""

echo ""
print_status "Chuyển sang STRICT mode và test lại..."
echo "================================================="

# Test Case 6: Chuyển sang STRICT mode
print_status "Test Case 6: Chuyển mTLS sang STRICT mode"
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: blog-microservices
spec:
  mtls:
    mode: STRICT
EOF

# Chờ một chút để policy được áp dụng
sleep 5

echo ""
# Test Case 7: Test lại kết nối từ pod không có sidecar
print_status "Test Case 7: Test lại kết nối từ pod không có sidecar đến blog-service (Kỳ vọng: thất bại)"
kubectl exec -n blog-microservices test-mtls -- curl -I http://blog-service:3001/health
echo ""

echo ""
# Test Case 8: Test lại kết nối từ pod có sidecar
print_status "Test Case 8: Test lại kết nối từ pod có sidecar đến blog-service (Kỳ vọng: thành công)"
kubectl exec -n blog-microservices test-mtls-with-sidecar -- curl -I http://blog-service:3001/health
echo ""

# Test Case 9: Kiểm tra trạng thái mTLS trong Kiali
print_status "Test Case 9: Kiểm tra visualization trong Kiali"
echo "Mở Kiali dashboard (http://localhost:20001) và kiểm tra:"
echo "1. Graph view: Tìm biểu tượng khóa trên các kết nối"
echo "2. Kiểm tra Security tab trong chi tiết service"

echo ""
print_status "Khôi phục lại PERMISSIVE mode..."
echo "================================================="

# Khôi phục về PERMISSIVE mode
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: blog-microservices
spec:
  mtls:
    mode: PERMISSIVE
EOF

print_success "Test mTLS hoàn tất!"
echo "Kết quả test sẽ cho thấy:"
echo "1. Trong PERMISSIVE mode: Cả hai loại pod đều có thể kết nối"
echo "2. Trong STRICT mode: Chỉ pod có sidecar mới kết nối được"
echo "3. Kiểm tra Kiali để xem trực quan các kết nối mTLS"
