#!/bin/bash

# Build and Deploy Blog Microservices with Istio
set -e

echo "🚀 Starting Blog Microservices deployment with Istio..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to check if port is available
check_port() {
    if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 1  # Port is in use
    fi
    return 0  # Port is available
}

# Function to find available port
find_available_port() {
    local base_port=$1
    local port=$base_port
    
    while ! check_port $port; do
        port=$((port + 1))
        if [ $port -gt $((base_port + 10)) ]; then
            echo "0"  # No available port found in range
            return
        fi
    done
    echo $port
}

# Check if minikube is running
print_status "Checking Minikube status..."
if ! minikube status > /dev/null 2>&1; then
    print_error "Minikube is not running. Please start minikube first:"
    echo "minikube start"
    exit 1
fi
print_success "Minikube is running"

# Switch to minikube docker environment
print_status "Switching to Minikube Docker environment..."
eval $(minikube -p minikube docker-env)

# Build Docker images
print_status "Building Docker images..."

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "${PROJECT_ROOT}/frontend"
print_status "Building frontend image..."
docker build -t blog-frontend:latest .

cd "${PROJECT_ROOT}/blog-service"
print_status "Building blog-service image..."
docker build -t blog-service:latest .

cd "${PROJECT_ROOT}/comment-service"
print_status "Building comment-service image..."
docker build -t comment-service:latest .

cd "${PROJECT_ROOT}/user-service"
print_status "Building user-service image..."
docker build -t user-service:latest .

cd "${PROJECT_ROOT}/notification-service"
print_status "Building notification-service image..."
docker build -t notification-service:latest .

print_success "All Docker images built successfully"

# Check if Istio is installed
print_status "Checking Istio installation..."
if ! kubectl get namespace istio-system > /dev/null 2>&1; then
    print_error "Istio is not installed. Please install Istio first:"
    echo "curl -L https://istio.io/downloadIstio | sh -"
    echo "export PATH=\$PWD/istio-*/bin:\$PATH"
    echo "istioctl install --set values.defaultRevision=default"
    exit 1
fi
print_success "Istio is installed"

# Install Istio addons for monitoring
print_status "Installing Istio monitoring addons..."

# Function to install component safely
install_component() {
    local component=$1
    local url=$2
    
    print_status "Installing $component..."
    
    if kubectl get deployment $component -n istio-system > /dev/null 2>&1; then
        print_warning "$component is already installed, skipping..."
        return 0
    fi
    
    # Download and apply
    if curl -s $url | kubectl apply -f -; then
        print_success "$component installed successfully"
        # Wait for deployment to be available
        kubectl wait --for=condition=available --timeout=180s deployment/$component -n istio-system 2>/dev/null || {
            print_warning "$component deployment may take longer to be ready"
        }
    else
        print_error "Failed to install $component"
        return 1
    fi
}

# Install components
install_component "prometheus" "https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml"
install_component "grafana" "https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml"
install_component "kiali" "https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml"
install_component "jaeger" "https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml"

print_success "Monitoring stack installed successfully"

# Deploy Kubernetes resources
print_status "Deploying Kubernetes resources..."

cd "${PROJECT_ROOT}/k8s"

# Create namespace and enable Istio injection
print_status "Creating namespace..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: blog-microservices
  labels:
    istio-injection: enabled
EOF

# Deploy services
print_status "Deploying services..."
kubectl apply -f services.yaml

# Deploy Istio configurations
print_status "Deploying Istio Gateway..."
kubectl apply -f istio-gateway.yaml

print_status "Deploying Destination Rules..."
kubectl apply -f destination-rules.yaml

# Deploy Grafana dashboard
print_status "Deploying custom Grafana dashboard..."
kubectl apply -f grafana-dashboard.yaml

# Configure monitoring
print_status "Configuring Prometheus monitoring..."

# Configure Prometheus scraping for microservices using Istio annotations
print_status "Adding Prometheus scraping annotations to services..."
kubectl patch service frontend -n blog-microservices -p '{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/port":"3000","prometheus.io/path":"/metrics"}}}' 2>/dev/null || true
kubectl patch service blog-service -n blog-microservices -p '{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/port":"3001","prometheus.io/path":"/metrics"}}}' 2>/dev/null || true
kubectl patch service comment-service -n blog-microservices -p '{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/port":"3002","prometheus.io/path":"/metrics"}}}' 2>/dev/null || true
kubectl patch service user-service -n blog-microservices -p '{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/port":"3003","prometheus.io/path":"/metrics"}}}' 2>/dev/null || true
kubectl patch service notification-service -n blog-microservices -p '{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/port":"3004","prometheus.io/path":"/metrics"}}}' 2>/dev/null || true

# Configure Istio telemetry
kubectl apply -f - <<EOF > /dev/null 2>&1 || print_warning "Telemetry configuration may have failed"
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: blog-microservices
spec:
  mtls:
    mode: PERMISSIVE
---
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: default-metrics
  namespace: blog-microservices
spec:
  metrics:
  - providers:
    - name: prometheus
  - overrides:
    - match:
        metric: ALL_METRICS
      tagOverrides:
        destination_service_name:
          value: "%{destination_service_name | 'unknown'}"
        destination_service_namespace:
          value: "%{destination_service_namespace | 'unknown'}"
        source_app:
          value: "%{source_app | 'unknown'}"
        destination_app:
          value: "%{destination_app | 'unknown'}"
EOF

print_success "Monitoring configuration completed"

print_success "All resources deployed successfully"

# Wait for deployments to be ready
print_status "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment --all -n blog-microservices

print_success "All deployments are ready"

print_success "🎉 Deployment completed successfully!"
echo ""

# Function to check if port is available
check_port() {
    if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 1  # Port is in use
    fi
    return 0  # Port is available
}

# Function to find available port
find_available_port() {
    local base_port=$1
    local port=$base_port
    
    while ! check_port $port; do
        port=$((port + 1))
        if [ $port -gt $((base_port + 100)) ]; then
            echo "0"  # No available port found
            return 1
        fi
    done
    echo $port
}

# Function to stop existing port-forwards
stop_existing_port_forwards() {
    print_status "Stopping existing port-forwards..."
    
    # Kill kubectl port-forward processes
    local pids=$(pgrep -f "kubectl port-forward" 2>/dev/null || echo "")
    if [ -n "$pids" ]; then
        echo "$pids" | while read pid; do
            kill $pid 2>/dev/null && print_status "Stopped port-forward process $pid" || true
        done
        sleep 2
    fi
}

# Stop existing port-forwards first
stop_existing_port_forwards

print_status "📊 Starting All Monitoring Dashboards:"

# Start Grafana
GRAFANA_PORT=$(find_available_port 3000)
if [ "$GRAFANA_PORT" != "0" ]; then
    kubectl port-forward svc/grafana $GRAFANA_PORT:3000 -n istio-system > /dev/null 2>&1 &
    GRAFANA_PID=$!
    echo "   ✅ Grafana: http://localhost:$GRAFANA_PORT (admin/admin) - PID: $GRAFANA_PID"
else
    echo "   ❌ Grafana: No available port found"
fi

# Start Prometheus
PROMETHEUS_PORT=$(find_available_port 9090)
if [ "$PROMETHEUS_PORT" != "0" ]; then
    kubectl port-forward svc/prometheus $PROMETHEUS_PORT:9090 -n istio-system > /dev/null 2>&1 &
    PROMETHEUS_PID=$!
    echo "   ✅ Prometheus: http://localhost:$PROMETHEUS_PORT - PID: $PROMETHEUS_PID"
else
    echo "   ❌ Prometheus: No available port found"
fi

# Start Kiali
KIALI_PORT=$(find_available_port 20001)
if [ "$KIALI_PORT" != "0" ]; then
    kubectl port-forward svc/kiali $KIALI_PORT:20001 -n istio-system > /dev/null 2>&1 &
    KIALI_PID=$!
    echo "   ✅ Kiali: http://localhost:$KIALI_PORT - PID: $KIALI_PID"
else
    echo "   ❌ Kiali: No available port found"
fi

# Start Jaeger
JAEGER_PORT=$(find_available_port 16686)
if [ "$JAEGER_PORT" != "0" ]; then
    kubectl port-forward svc/jaeger $JAEGER_PORT:16686 -n istio-system > /dev/null 2>&1 &
    JAEGER_PID=$!
    echo "   ✅ Jaeger: http://localhost:$JAEGER_PORT - PID: $JAEGER_PID"
else
    echo "   ❌ Jaeger: No available port found"
fi

# Start Frontend
FRONTEND_PORT=$(find_available_port 8080)
if [ "$FRONTEND_PORT" != "0" ]; then
    kubectl port-forward svc/frontend $FRONTEND_PORT:3000 -n blog-microservices > /dev/null 2>&1 &
    FRONTEND_PID=$!
    echo "   ✅ Frontend App: http://localhost:$FRONTEND_PORT - PID: $FRONTEND_PID"
else
    echo "   ❌ Frontend: No available port found"
fi

echo ""
print_success "🚀 Blog Microservices with Istio fully deployed!"

echo ""
print_status "🎯 Quick Actions:"
if [ "$FRONTEND_PORT" != "0" ]; then
    echo "   📱 Access Application: http://localhost:$FRONTEND_PORT"
    echo "   🔄 Generate Test Traffic: while true; do curl http://localhost:$FRONTEND_PORT 2>/dev/null; sleep 1; done"
fi
echo "   🛑 Stop All Port-forwards: pkill -f 'kubectl port-forward'"
echo "   👀 View Running Port-forwards: pgrep -f 'kubectl port-forward'"

echo ""
print_status "🔧 Kubernetes Commands:"
echo "   kubectl get pods -n blog-microservices"
echo "   kubectl get svc -n blog-microservices"
echo "   kubectl get gateway -n blog-microservices"
echo "   kubectl get virtualservice -n blog-microservices"

echo ""
print_status "📊 Monitoring Features:"
echo "   - Real-time service metrics and dashboards"
echo "   - Distributed tracing across microservices"
echo "   - Service mesh topology visualization"
echo "   - Traffic management and routing"
echo "   - Automatic metrics collection via Istio sidecars"

# Return to scripts directory
cd "${PROJECT_ROOT}/scripts"
