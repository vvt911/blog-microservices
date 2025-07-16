# 📚 Hướng dẫn Triển khai và Sử dụng

## 🎯 Mục lục
1. [Cài đặt Môi trường](#cài-đặt-môi-trường)
2. [Triển khai Local Development](#triển-khai-local-development)
3. [Triển khai Production với Kubernetes](#triển-khai-production-với-kubernetes)
4. [Monitoring và Observability](#monitoring-và-observability)
5. [Testing và Validation](#testing-và-validation)
6. [Troubleshooting](#troubleshooting)

## 🔧 Cài đặt Môi trường

### Prerequisites
```bash
# 1. Node.js (v18 trở lên)
node --version

# 2. Docker
docker --version

# 3. Kubernetes (Minikube hoặc Kind)
minikube version
# hoặc
kind version

# 4. kubectl
kubectl version --client

# 5. Istio
istioctl version
```

### Cài đặt Istio
```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -

# Add to PATH
export PATH=$PWD/istio-*/bin:$PATH

# Install Istio
istioctl install --set values.defaultRevision=default

# Enable namespace injection
kubectl label namespace default istio-injection=enabled
```

## 🚀 Triển khai Local Development

### 1. Clone Repository
```bash
git clone <repository-url>
cd blog-microservices
```

### 2. Install Dependencies
```bash
# Install dependencies cho tất cả services
cd blog-service && npm install && cd ..
cd comment-service && npm install && cd ..
cd user-service && npm install && cd ..
cd notification-service && npm install && cd ..
cd frontend && npm install && cd ..
```

### 3. Start Development Mode
```bash
# Option 1: Manual start
cd blog-service && npm start &
cd comment-service && npm start &
cd user-service && npm start &
cd notification-service && npm start &
cd frontend && npm start &

# Option 2: Using script (if available)
cd scripts
chmod +x start-dev.sh
./start-dev.sh
```

### 4. Access Services
- **Frontend**: http://localhost:3000
- **Blog Service**: http://localhost:3001
- **Comment Service**: http://localhost:3002
- **User Service**: http://localhost:3003
- **Notification Service**: http://localhost:3004

## ☁️ Triển khai Production với Kubernetes

### 1. Start Minikube
```bash
minikube start --cpus=4 --memory=8192
```

### 2. Build Docker Images
```bash
# Build all images
docker build -t blog-service:latest ./blog-service
docker build -t comment-service:latest ./comment-service
docker build -t user-service:latest ./user-service
docker build -t notification-service:latest ./notification-service
docker build -t blog-frontend:latest ./frontend

# Load images to Minikube
minikube image load blog-service:latest
minikube image load comment-service:latest
minikube image load user-service:latest
minikube image load notification-service:latest
minikube image load blog-frontend:latest
```

### 3. Deploy to Kubernetes
```bash
# Deploy all services
kubectl apply -f k8s/services.yaml

# Deploy Istio configuration
kubectl apply -f k8s/istio-gateway.yaml
kubectl apply -f k8s/destination-rules.yaml

# Verify deployment
kubectl get pods -n blog-microservices
kubectl get svc -n blog-microservices
```

### 4. Access Application
```bash
# Get Istio Gateway URL
export INGRESS_HOST=$(minikube ip)
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')

echo "Application URL: http://$INGRESS_HOST:$INGRESS_PORT"
```

### 5. One-Command Deploy
```bash
# Sử dụng script tự động
cd scripts
chmod +x deploy.sh
./deploy.sh
```

## 📊 Monitoring và Observability

### 1. Deploy Monitoring Stack
```bash
# Deploy Prometheus
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/addons/prometheus.yaml

# Deploy Grafana
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/addons/grafana.yaml

# Deploy Jaeger
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/addons/jaeger.yaml

# Deploy Kiali
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/addons/kiali.yaml
```

### 2. Access Monitoring Tools
```bash
# Grafana
kubectl port-forward -n istio-system svc/grafana 3000:3000

# Prometheus
kubectl port-forward -n istio-system svc/prometheus 9090:9090

# Jaeger
kubectl port-forward -n istio-system svc/jaeger 16686:16686

# Kiali
kubectl port-forward -n istio-system svc/kiali 20001:20001
```

### 3. Custom Grafana Dashboard
```bash
# Apply custom dashboard
kubectl apply -f k8s/grafana-dashboard.yaml
```

## 🧪 Testing và Validation

### 1. Health Checks
```bash
# Check service health
curl http://localhost:3001/health
curl http://localhost:3002/health
curl http://localhost:3003/health
curl http://localhost:3004/health
```

### 2. API Testing
```bash
# Test Blog Service
curl -X POST http://localhost:3001/api/blogs \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Blog","content":"Test content","author":"Test User"}'

# Test Comment Service
curl -X POST http://localhost:3002/api/comments \
  -H "Content-Type: application/json" \
  -d '{"blogId":1,"content":"Test comment","author":"Test User"}'

# Test User Service
curl -X POST http://localhost:3003/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com"}'
```

### 3. Load Testing
```bash
# Install hey tool
go install github.com/rakyll/hey@latest

# Load test Frontend
hey -n 1000 -c 10 http://localhost:3000

# Load test Blog Service
hey -n 1000 -c 10 http://localhost:3001/api/blogs
```

### 4. Istio Traffic Testing
```bash
# Test script
cd scripts
chmod +x test-traffic.sh
./test-traffic.sh
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Port Conflicts
```bash
# Check ports in use
lsof -i :3000
lsof -i :3001
lsof -i :3002
lsof -i :3003
lsof -i :3004

# Kill processes
kill -9 <PID>
```

#### 2. Docker Issues
```bash
# Check Docker daemon
docker info

# Clean up Docker
docker system prune -f

# Check images
docker images | grep blog
```

#### 3. Kubernetes Issues
```bash
# Check cluster status
kubectl cluster-info

# Check node status
kubectl get nodes

# Check pod status
kubectl get pods -n blog-microservices

# Check logs
kubectl logs -f deployment/blog-service -n blog-microservices
```

#### 4. Istio Issues
```bash
# Check Istio status
istioctl proxy-status

# Check configuration
istioctl analyze

# Check proxy configuration
istioctl proxy-config cluster blog-service-xxx -n blog-microservices
```

### Debug Commands

#### Service Communication
```bash
# Check service endpoints
kubectl get endpoints -n blog-microservices

# Test service connectivity
kubectl exec -it <pod-name> -n blog-microservices -- curl http://blog-service:3001/health
```

#### Istio Configuration
```bash
# Check Virtual Services
kubectl get virtualservices -n blog-microservices

# Check Destination Rules
kubectl get destinationrules -n blog-microservices

# Check Gateway
kubectl get gateway -n blog-microservices
```

#### Performance Issues
```bash
# Check resource usage
kubectl top pods -n blog-microservices
kubectl top nodes

# Check events
kubectl get events -n blog-microservices --sort-by=.metadata.creationTimestamp
```

## 🔄 Maintenance

### 1. Updates
```bash
# Update images
docker build -t blog-service:v2 ./blog-service
kubectl set image deployment/blog-service blog-service=blog-service:v2 -n blog-microservices

# Rolling update
kubectl rollout status deployment/blog-service -n blog-microservices
```

### 2. Scaling
```bash
# Scale services
kubectl scale deployment blog-service --replicas=3 -n blog-microservices
kubectl scale deployment comment-service --replicas=2 -n blog-microservices
```

### 3. Cleanup
```bash
# Stop development services
./scripts/stop-dev.sh

# Cleanup Kubernetes
kubectl delete namespace blog-microservices
```

## 📝 Development Tips

### 1. Code Changes
```bash
# Auto-restart in development
npm install -g nodemon

# Start with nodemon
nodemon server.js
```

### 2. Debugging
```bash
# Debug mode
DEBUG=* npm start

# Log levels
LOG_LEVEL=debug npm start
```

### 3. Environment Variables
```bash
# Create .env file
echo "NODE_ENV=development" > .env
echo "LOG_LEVEL=debug" >> .env
echo "NOTIFICATION_SERVICE_URL=http://localhost:3004" >> .env
```

---

**Hướng dẫn này cung cấp các bước chi tiết để triển khai và vận hành hệ thống Blog Microservices với Istio từ development đến production environment.**
