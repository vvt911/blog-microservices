# Blog Microservices Monitoring Guide

## Tổng quan

Hệ thống monitoring cho Blog Microservices bao gồm:

- **Prometheus**: Thu thập metrics từ Istio và các microservices
- **Grafana**: Visualization và dashboards
- **Kiali**: Service mesh observability
- **Jaeger**: Distributed tracing

## Cài đặt và Khởi chạy

### ✨ Một lệnh deploy tất cả
```bash
./scripts/deploy.sh
```

Script này sẽ **tự động**:
- Build Docker images cho tất cả microservices
- Deploy Kubernetes resources
- Cài đặt Istio monitoring stack (Prometheus, Grafana, Kiali, Jaeger)
- Cấu hình custom Grafana dashboard
- Thiết lập ServiceMonitors cho Prometheus
- **Tự động tìm và sử dụng ports có sẵn**
- Khởi động tất cả monitoring dashboards
- Hiển thị access URLs với ports đã được gán

### 🚀 Sau khi chạy deploy.sh
Bạn sẽ thấy output như:
```
📊 Starting All Monitoring Dashboards:
   ✅ Grafana: http://localhost:3000 (admin/admin) - PID: 12345
   ✅ Prometheus: http://localhost:9090 - PID: 12346
   ✅ Kiali: http://localhost:20001 - PID: 12347
   ✅ Jaeger: http://localhost:16686 - PID: 12348
   ✅ Frontend App: http://localhost:8080 - PID: 12349

🚀 Blog Microservices with Istio fully deployed!
```

## Access URLs

Sau khi chạy `start-monitoring.sh`:

| Service | URL | Credentials |
|---------|-----|-------------|
| Frontend App | http://localhost:8080 | - |
| Grafana | http://localhost:3000 | admin/admin |
| Prometheus | http://localhost:9090 | - |
| Kiali | http://localhost:20001 | - |
| Jaeger | http://localhost:16686 | - |

## Grafana Dashboards

### Pre-built Istio Dashboards
- **Istio Service Dashboard**: Metrics cho từng service
- **Istio Workload Dashboard**: Workload performance
- **Istio Mesh Dashboard**: Tổng quan toàn bộ mesh
- **Istio Performance Dashboard**: Chi tiết performance

### Custom Blog Microservices Dashboard
Dashboard tùy chỉnh bao gồm:
- Request rate by service
- Success rate by service  
- Response time P99
- Request volume
- Error rate
- Service topology

## Metrics được thu thập

### Istio Metrics
- `istio_requests_total`: Tổng số requests
- `istio_request_duration_milliseconds`: Response time
- `istio_request_bytes`: Request size
- `istio_response_bytes`: Response size

### Application Metrics
Mỗi service expose metrics tại `/metrics` endpoint:
- HTTP request metrics
- Custom business metrics
- Node.js runtime metrics

## Monitoring Use Cases

### 1. Service Health Monitoring
```promql
# Success rate
sum(rate(istio_requests_total{response_code!~"5.*"}[1m])) / sum(rate(istio_requests_total[1m])) * 100

# Error rate
sum(rate(istio_requests_total{response_code=~"5.*"}[1m])) by (destination_service_name)
```

### 2. Performance Monitoring
```promql
# P99 latency
histogram_quantile(0.99, sum(rate(istio_request_duration_milliseconds_bucket[1m])) by (le))

# Request throughput
sum(rate(istio_requests_total[1m])) by (destination_service_name)
```

### 3. Service Dependencies
Kiali cung cấp service graph visualization:
- Traffic flow giữa services
- Request success/failure rates
- Response times

### 4. Distributed Tracing
Jaeger tracking:
- End-to-end request flows
- Service dependencies
- Performance bottlenecks

## Alerting (Optional)

Có thể cấu hình alerts với Prometheus AlertManager:

```yaml
# Ví dụ alert rule
groups:
- name: blog-microservices
  rules:
  - alert: HighErrorRate
    expr: sum(rate(istio_requests_total{response_code=~"5.*"}[5m])) / sum(rate(istio_requests_total[5m])) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: High error rate detected
```

## Troubleshooting

### 1. Kiểm tra monitoring components
```bash
kubectl get pods -n istio-system
kubectl get svc -n istio-system
```

### 2. Kiểm tra metrics endpoints
```bash
kubectl port-forward svc/prometheus 9090:9090 -n istio-system
# Visit http://localhost:9090/targets
```

### 3. Kiểm tra Istio injection
```bash
kubectl get pods -n blog-microservices -o jsonpath='{.items[*].spec.containers[*].name}'
# Should include 'istio-proxy'
```

### 4. Generate traffic để test metrics
```bash
while true; do
  curl http://localhost:8080
  sleep 1
done
```

## Scripts

- **`deploy.sh`**: ⭐ **SCRIPT CHÍNH** - Deploy toàn bộ hệ thống với monitoring tự động
- `cleanup.sh`: Cleanup resources
- `start-dev.sh`: Development mode (không dùng Istio)
- `stop-dev.sh`: Stop development mode

### 🎯 Chỉ cần chạy một lệnh:
```bash
./scripts/deploy.sh
```
**Và bạn sẽ có ngay hệ thống hoàn chỉnh với monitoring!**

## Tùy chỉnh

### Thêm custom metrics
1. Cập nhật application code để expose metrics
2. Cập nhật ServiceMonitor configuration
3. Tạo Grafana dashboard panels

### Cấu hình retention
```bash
# Prometheus retention (default 15 days)
kubectl patch deployment prometheus -n istio-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"prometheus","args":["--retention.time=30d"]}]}}}}'
```
