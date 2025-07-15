# Blog Microservices with Istio

Một hệ thống microservices đơn giản để demo Istio Service Mesh, được viết hoàn toàn bằng JavaScript/Node.js.

## 🏗️ Kiến trúc hệ thống

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Frontend      │    │   Blog Service   │    │  Notification       │
│   (Port: 3000)  │───▶│   (Port: 3001)   │───▶│  Service            │
│                 │    │                  │    │  (Port: 3004)       │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
         │                        │
         │                        │
         ▼                        ▼
┌─────────────────┐    ┌──────────────────┐
│ Comment Service │    │   User Service   │
│ (Port: 3002)    │    │   (Port: 3003)   │
└─────────────────┘    └──────────────────┘
```

## 📦 Các Services

### 1. **Frontend** (Port: 3000)
- Giao diện web đơn giản sử dụng HTML/CSS/JavaScript
- Hiển thị danh sách users, blogs và comments
- Theo dõi trạng thái của các services

### 2. **Blog Service** (Port: 3001)
- Quản lý bài viết blog
- REST API cho CRUD operations
- Tích hợp với Notification Service

### 3. **Comment Service** (Port: 3002)
- Quản lý bình luận cho các bài viết
- Liên kết với Blog Service để xác thực blog
- Gửi thông báo khi có comment mới

### 4. **User Service** (Port: 3003)
- Quản lý thông tin người dùng
- Theo dõi hoạt động của users
- Thống kê người dùng

### 5. **Notification Service** (Port: 3004)
- Gửi và quản lý thông báo
- Broadcast messages
- Theo dõi trạng thái đọc/chưa đọc

## 🚀 Quick Start

### Development Mode (Local)

1. **Cài đặt dependencies:**
   ```bash
   cd scripts
   chmod +x *.sh
   ./start-dev.sh
   ```

2. **Truy cập ứng dụng:**
   - Frontend: http://localhost:3000
   - Blog Service: http://localhost:3001
   - Comment Service: http://localhost:3002
   - User Service: http://localhost:3003
   - Notification Service: http://localhost:3004

3. **Dừng services:**
   ```bash
   ./stop-dev.sh
   ```

### Production Mode (Kubernetes + Istio)

1. **Khởi động Minikube:**
   ```bash
   minikube start
   ```

2. **Cài đặt Istio:**
   ```bash
   curl -L https://istio.io/downloadIstio | sh -
   export PATH=$PWD/istio-*/bin:$PATH
   istioctl install --set values.defaultRevision=default
   ```

3. **Deploy ứng dụng:**
   ```bash
   cd scripts
   ./deploy.sh
   ```

4. **Truy cập ứng dụng:**
   ```bash
   # Lấy URL từ output của deploy.sh
   # hoặc port-forward:
   kubectl port-forward svc/frontend 8080:3000 -n blog-microservices
   ```

5. **Cleanup:**
   ```bash
   ./cleanup.sh
   ```

## 🔧 API Endpoints

### Blog Service (3001)
```
GET    /blogs           # Lấy tất cả blogs
GET    /blogs/:id       # Lấy blog theo ID
POST   /blogs           # Tạo blog mới
PUT    /blogs/:id       # Cập nhật blog
DELETE /blogs/:id       # Xóa blog
POST   /blogs/:id/like  # Like blog
GET    /stats           # Thống kê blogs
```

### Comment Service (3002)
```
GET    /comments                # Lấy tất cả comments
GET    /comments/blog/:blogId   # Lấy comments của blog
POST   /comments               # Tạo comment mới
PUT    /comments/:id           # Cập nhật comment
DELETE /comments/:id           # Xóa comment
POST   /comments/:id/like      # Like comment
```

### User Service (3003)
```
GET    /users              # Lấy tất cả users
GET    /users/:id          # Lấy user theo ID
POST   /users              # Tạo user mới
PUT    /users/:id          # Cập nhật user
DELETE /users/:id          # Xóa user
GET    /users/role/:role   # Lấy users theo role
POST   /users/:id/activity # Cập nhật hoạt động
```

### Notification Service (3004)
```
GET    /notifications        # Lấy tất cả notifications
POST   /notify               # Tạo notification mới
PATCH  /notifications/:id/read # Đánh dấu đã đọc
POST   /broadcast            # Gửi broadcast
GET    /unread-count         # Đếm số chưa đọc
```

## 🔍 Monitoring với Istio

### Grafana
```bash
kubectl port-forward svc/grafana 3000:3000 -n istio-system
# Truy cập: http://localhost:3000
```

### Prometheus
```bash
kubectl port-forward svc/prometheus 9090:9090 -n istio-system
# Truy cập: http://localhost:9090
```

## 🎯 Tính năng Istio Demo

### 1. Traffic Management
- **Virtual Services:** Routing rules cho từng service
- **Destination Rules:** Load balancing và circuit breaker
- **Gateway:** External access thông qua Istio Ingress

### 2. Security
- **mTLS:** Automatic mutual TLS giữa các services
- **Authorization:** Service-to-service access control
- **Authentication:** JWT validation

### 3. Observability
- **Metrics:** Prometheus metrics tự động
- **Tracing:** Distributed tracing với Istio telemetry
- **Logging:** Centralized logging

## 📁 Cấu trúc thư mục

```
blog-microservices/
├── frontend/                 # Frontend service
│   ├── public/              # Static files
│   ├── server.js            # Express server
│   ├── package.json
│   └── Dockerfile
├── blog-service/            # Blog management service
├── comment-service/         # Comment management service
├── user-service/           # User management service  
├── notification-service/   # Notification service
├── k8s/                    # Kubernetes manifests
│   ├── services.yaml       # Deployments & Services
│   ├── istio-gateway.yaml  # Gateway & VirtualServices
│   └── destination-rules.yaml
└── scripts/                # Deployment scripts
    ├── deploy.sh           # Deploy to K8s
    ├── start-dev.sh        # Start local dev
    ├── stop-dev.sh         # Stop local dev
    └── cleanup.sh          # Cleanup K8s
```

## 🛠️ Yêu cầu hệ thống

- **Node.js** 18+
- **Docker** 
- **Minikube** 
- **kubectl**
- **Istio** 1.20+

## 🔧 Development

### Thêm Service mới
1. Tạo thư mục service mới
2. Thêm vào `k8s/services.yaml`
3. Tạo Istio VirtualService
4. Cập nhật `scripts/deploy.sh`

### Testing APIs
```bash
# Health checks
curl http://localhost:3001/health
curl http://localhost:3002/health
curl http://localhost:3003/health
curl http://localhost:3004/health

# Sample API calls
curl -X GET http://localhost:3001/blogs
curl -X GET http://localhost:3003/users
curl -X GET http://localhost:3002/comments/blog/1
```

## 📝 Notes

- Tất cả services sử dụng in-memory storage (phù hợp cho demo)
- Mỗi service có sample data được tạo sẵn
- Frontend tự động refresh mỗi 30 giây
- Service status được hiển thị real-time

## 🤝 Contributing

1. Fork the project
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## 📄 License

MIT License - xem file LICENSE để biết thêm chi tiết.
