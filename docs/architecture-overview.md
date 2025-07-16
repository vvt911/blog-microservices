# 🏗️ Kiến trúc Chi tiết Hệ thống Blog Microservices với Istio

## 📋 Tổng quan Hệ thống

Hệ thống Blog Microservices là một ứng dụng demo được thiết kế để minh họa việc triển khai microservices với Istio Service Mesh trên Kubernetes. Hệ thống bao gồm 5 microservices chính được viết bằng Node.js/Express và một frontend web.

## 🎯 Luồng Kiến trúc Tổng quan

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        ISTIO SERVICE MESH (Minikube)                                │
│                                                                                     │
│  ┌─────────────────┐                                                                │
│  │ blog-gateway    │  (Port 80)                                                     │
│  │ (Istio Gateway) │                                                                │
│  └─────────┬───────┘                                                                │
│            │                                                                        │
│            ▼                                                                        │  
│  ┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐             │
│  │   Frontend      │    │   Blog Service   │    │  Notification       │             │
│  │   (Port: 3000)  │───▶│   (Port: 3001)   │───▶│  Service            │             │
│  │ API Proxy       │    │ In-Memory Store  │    │  (Port: 3004)       │             │
│  └─────────┬───────┘    └──────────────────┘    │ In-Memory Store     │             │
│            │                        │           └─────────────────────┘             │
│            │                        │                        ▲                      │
│            ▼                        ▼                        │                      │
│  ┌─────────────────┐    ┌──────────────────┐                │                       │
│  │ Comment Service │    │   User Service   │                │                       │
│  │ (Port: 3002)    │───▶│   (Port: 3003)   │───────────────┘                        │
│  │ In-Memory Store │    │ In-Memory Store  │                                        │
│  └─────────────────┘    └──────────────────┘                                        │
│                                                                                     │
│  ┌───────────────────────────────────────────────────────────────────────────┐      │
│  │                   MONITORING STACK (istio-system)                         │      │
│  │  ┌─────────────┐    ┌─────────────┐                                       │      │
│  │  │ Prometheus  │    │   Grafana   │                                       │      │
│  │  │ (Port:9090) │    │ (Port:3000) │                                       │      │
│  │  │ Istio Addon │    │ Istio Addon │                                       │      │
│  │  └─────────────┘    └─────────────┘                                       │      │
│  └───────────────────────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 🔄 Luồng Dữ liệu Chi tiết

### 1. **Luồng Người dùng Truy cập**

```
[User Browser] 
    ↓ HTTP Request
[Istio Gateway] (Port 80)
    ↓ Route to Frontend
[Frontend Service] (Port 3000)
    ↓ Serve HTML/CSS/JS
[User Browser] 
    ↓ API Calls via JavaScript
[Frontend Service] → [Backend Services]
```

### 2. **Luồng Tạo Blog Post**

```
[User] → POST /api/blogs {title, content, author}
    ↓
[Frontend] → POST /blogs {title, content, author}
    ↓
[Blog Service] (Port 3001)
    ↓ Store in memory array
[In-Memory Storage: blogs[]]
    ↓ POST /notify {type: "blog_created", message, blogId}
[Notification Service] (Port 3004)
    ↓ Store in memory array
[In-Memory Storage: notifications[]]
```

### 3. **Luồng Tạo Comment**

```
[User] → POST /api/comments {blogId, author, content}
    ↓
[Frontend] → POST /comments {blogId, author, content}
    ↓
[Comment Service] (Port 3002)
    ↓ GET /blogs/{blogId} (validate blog exists)
[Blog Service] (Port 3001)
    ↓ Store comment in memory array
[Comment Service Storage: comments[]]
    ↓ POST /notify {type: "comment_created", message, commentId}
[Notification Service] (Port 3004)
```

### 4. **Luồng Quản lý User**

```
[User] → POST /api/users {name, email, role, bio}
    ↓
[Frontend] → POST /users {name, email, role, bio}
    ↓
[User Service] (Port 3003)
    ↓ Store user data in memory array
[In-Memory Storage: users[]]
    ↓ POST /notify {type: "user_registered", message, userId}
[Notification Service] (Port 3004)
```

## 🏠 Chi tiết từng Microservice

### 1. **Frontend Service** 
- **Chức năng**: API Gateway + Static Files Server
- **Công nghệ**: Node.js, Express.js, HTML/CSS/JavaScript
- **Port**: 3000
- **Chức năng chính**:
  - Serve static files từ /public (index.html, script.js, style.css)
  - API proxy cho tất cả /api/* routes
  - Environment variables: BLOG_SERVICE_URL, COMMENT_SERVICE_URL, USER_SERVICE_URL, NOTIFICATION_SERVICE_URL
- **API Routes**: Proxy tất cả requests đến backend services

### 2. **Blog Service**
- **Chức năng**: Quản lý bài viết blog
- **Công nghệ**: Node.js, Express.js
- **Port**: 3001
- **Data Storage**: In-memory array `blogs[]` với sample data
- **API Endpoints**:
  - `GET /blogs` - Lấy danh sách blogs
  - `POST /blogs` - Tạo blog mới
  - `GET /blogs/:id` - Lấy blog theo ID
  - `PUT /blogs/:id` - Cập nhật blog
  - `POST /blogs/:id/like` - Like blog
  - `DELETE /blogs/:id` - Xóa blog
  - `GET /stats` - Thống kê blog
  - `GET /health` - Health check
- **Tích hợp**: Fire-and-forget POST /notify đến Notification Service

### 3. **Comment Service**
- **Chức năng**: Quản lý bình luận
- **Công nghệ**: Node.js, Express.js
- **Port**: 3002
- **Data Storage**: In-memory array `comments[]` với sample data
- **API Endpoints**:
  - `GET /comments` - Lấy tất cả comments
  - `GET /comments/blog/:blogId` - Lấy comments theo blog
  - `GET /comments/:id` - Lấy comment theo ID
  - `POST /comments` - Tạo comment mới
  - `PUT /comments/:id` - Cập nhật comment
  - `POST /comments/:id/like` - Like comment
  - `DELETE /comments/:id` - Xóa comment
  - `GET /health` - Health check
- **Tích hợp**: Validate blog exists qua GET /blogs/:id, gửi notification

### 4. **User Service**
- **Chức năng**: Quản lý người dùng
- **Công nghệ**: Node.js, Express.js
- **Port**: 3003
- **Data Storage**: In-memory array `users[]` với sample data
- **API Endpoints**:
  - `GET /users` - Lấy danh sách users (có filter role, active)
  - `GET /users/:id` - Lấy user theo ID
  - `POST /users` - Tạo user mới
  - `PUT /users/:id` - Cập nhật user
  - `DELETE /users/:id` - Xóa user
  - `GET /users/stats` - Thống kê user
  - `GET /health` - Health check
- **Tích hợp**: Gửi notification khi user mới đăng ký

### 5. **Notification Service**
- **Chức năng**: Quản lý thông báo
- **Công nghệ**: Node.js, Express.js
- **Port**: 3004
- **Data Storage**: In-memory array `notifications[]` với sample data
- **API Endpoints**:
  - `GET /notifications` - Lấy notifications (có filter type, read, priority)
  - `GET /notifications/:id` - Lấy notification theo ID
  - `POST /notify` - Tạo notification mới
  - `PATCH /notifications/:id/read` - Đánh dấu đã đọc
  - `PATCH /notifications/read-all` - Đánh dấu tất cả đã đọc
  - `DELETE /notifications/:id` - Xóa notification
  - `GET /health` - Health check
- **Tích hợp**: Nhận notifications từ tất cả services

## 🔧 Istio Service Mesh Components

### 1. **Istio Gateway**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: blog-gateway
  namespace: blog-microservices
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
```

### 2. **Virtual Services**
- **blog-virtualservice**: Route traffic từ gateway đến frontend (/ → frontend:3000)
- **blog-service-vs**: Internal routing cho blog service (blog-service → :3001)
- **comment-service-vs**: Internal routing cho comment service (comment-service → :3002)
- **user-service-vs**: Internal routing cho user service (user-service → :3003)
- **notification-service-vs**: Internal routing cho notification service (notification-service → :3004)

### 3. **Destination Rules**
- **frontend-dr**: subset v1 với labels version: v1
- **blog-service-dr**: subset v1 với labels version: v1
- **comment-service-dr**: subset v1 với labels version: v1
- **user-service-dr**: subset v1 với labels version: v1
- **notification-service-dr**: subset v1 với labels version: v1

## 🐳 Containerization & Deployment

### Docker Images
Mỗi service có Dockerfile riêng:
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3001
CMD ["node", "server.js"]
```

### Kubernetes Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blog-service
  namespace: blog-microservices
  labels:
    app: blog-service
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: blog-service
      version: v1
  template:
    metadata:
      labels:
        app: blog-service
        version: v1
    spec:
      containers:
      - name: blog-service
        image: blog-service:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 3001
        env:
        - name: NOTIFICATION_SERVICE_URL
          value: "http://notification-service:3004"
```

## 📊 Monitoring & Observability

### 1. **Prometheus**
- Thu thập metrics từ Istio Envoy sidecars
- Deployed từ Istio addon: `kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml`
- Port: 9090
- Automatic service discovery cho tất cả services

### 2. **Grafana**
- Dashboards cho Istio service mesh metrics
- Deployed từ Istio addon: `kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml`
- Port: 3000
- Pre-configured dashboards cho Istio

## 🚀 Deployment Process

### 1. **Development Mode**
```bash
# Start all services locally (manual)
cd blog-service && npm start &
cd comment-service && npm start &
cd user-service && npm start &
cd notification-service && npm start &
cd frontend && npm start &

# Each service runs on its own port
# Frontend: http://localhost:3000
# Blog: http://localhost:3001
# Comment: http://localhost:3002
# User: http://localhost:3003
# Notification: http://localhost:3004
```

### 2. **Production Mode (Minikube + Istio)**
```bash
# Build and deploy to Kubernetes
./scripts/deploy.sh

# This will:
# 1. Check Minikube status
# 2. Build Docker images (imagePullPolicy: Never)
# 3. Deploy to Kubernetes với namespace blog-microservices
# 4. Configure Istio (Gateway, Virtual Services, Destination Rules)
# 5. Setup monitoring (Prometheus + Grafana từ Istio addons)
# 6. Port-forward services để access
```

## 🔐 Security Features

### 1. **Istio Security**
- Automatic mTLS between services (default Istio behavior)
- Namespace với istio-injection: enabled
- Envoy sidecar proxy cho tất cả services

### 2. **Service Security**
- CORS configuration cho tất cả services
- Input validation cho required fields
- Health check endpoints (/health) cho tất cả services
- Environment variables cho service URLs

## 🌐 Network Communication

### 1. **Service-to-Service Communication**
- HTTP/REST APIs
- Axios HTTP client cho inter-service calls
- Environment variables cho service URLs
- Istio Envoy sidecar proxy handling
- Automatic service discovery trong Kubernetes
- Fire-and-forget pattern cho notifications

### 2. **External Communication**
- Istio Gateway làm single entry point (port 80)
- Frontend service routing tất cả external requests
- Path-based routing: / → frontend, backend services internal only

## 📈 Scalability & Performance

### 1. **Horizontal Scaling**
- Kubernetes replicas (hiện tại: 1 replica cho mỗi service)
- Istio load balancing với Envoy sidecars
- Stateless service design với in-memory storage
- Ready cho HPA (Horizontal Pod Autoscaler)

### 2. **Performance Considerations**
- In-memory data storage (nhanh nhưng không persistent)
- Async notification pattern (fire-and-forget)
- Express.js middleware để handle requests
- Kubernetes resource limits (có thể cấu hình)

## 🔄 CI/CD Integration

### 1. **Build Process**
```bash
# Build all Docker images (thực hiện trong deploy.sh)
cd blog-service && docker build -t blog-service:latest .
cd comment-service && docker build -t comment-service:latest .
cd user-service && docker build -t user-service:latest .
cd notification-service && docker build -t notification-service:latest .
cd frontend && docker build -t blog-frontend:latest .

# Load images vào Minikube
eval $(minikube docker-env)
```

### 2. **Deployment Script**
- Automated deployment qua `./scripts/deploy.sh`
- Minikube environment setup
- Docker image building với local registry
- Kubernetes resource deployment
- Istio configuration application
- Monitoring setup (Prometheus + Grafana)
- Port forwarding setup cho local access

## 🎯 Key Features Demonstration

### 1. **Microservices Architecture**
- 5 independent services với different responsibilities
- In-memory data storage cho demo purposes
- HTTP/REST API communication
- Service independence và fault isolation

### 2. **Istio Service Mesh**
- Automatic sidecar injection
- Service-to-service mTLS
- Traffic management với Virtual Services và Destination Rules
- Observability với Prometheus metrics

### 3. **Kubernetes Deployment**
- Minikube local cluster
- Namespace isolation
- Service discovery
- Configuration management qua environment variables

### 4. **Monitoring & Observability**
- Istio addon Prometheus cho metrics collection
- Istio addon Grafana cho visualization
- Health check endpoints
- Console logging

## 🛠️ Troubleshooting

### Common Issues
1. **Port conflicts**: Deploy script tự động tìm available ports
2. **Minikube not running**: Kiểm tra `minikube status`
3. **Istio not installed**: Cần install Istio trước khi deploy
4. **Image pulling**: Sử dụng `imagePullPolicy: Never` cho local images
5. **Service communication**: Kiểm tra environment variables và service URLs

### Debug Commands
```bash
# Check Minikube status
minikube status

# Check service status
kubectl get pods -n blog-microservices
kubectl get svc -n blog-microservices

# Check Istio configuration
kubectl get gateway -n blog-microservices
kubectl get virtualservice -n blog-microservices
kubectl get destinationrule -n blog-microservices

# View logs
kubectl logs -f deployment/blog-service -n blog-microservices
kubectl logs -f deployment/frontend -n blog-microservices

# Check Istio sidecar injection
kubectl get pods -n blog-microservices -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
```

---

**Hệ thống này minh họa một kiến trúc microservices hoàn chỉnh với Istio Service Mesh, từ development đến production deployment, bao gồm monitoring, security, và scalability considerations.**
