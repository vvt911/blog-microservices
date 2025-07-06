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

print_success "All resources deployed successfully"

# Wait for deployments to be ready
print_status "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment --all -n blog-microservices

print_success "All deployments are ready"

print_success "🎉 Deployment completed successfully!"
echo ""
print_status "🔧 Useful Commands:"
echo "   View pods: kubectl get pods -n blog-microservices"
echo "   View services: kubectl get svc -n blog-microservices"
echo "   View gateway: kubectl get gateway -n blog-microservices"
echo "   View Istio config: kubectl get virtualservice -n blog-microservices"
echo "   Port forward frontend: kubectl port-forward svc/frontend 8080:3000 -n blog-microservices"
echo ""
print_status "📊 Monitor with Kiali:"
echo "   kubectl port-forward svc/kiali 20001:20001 -n istio-system"
echo "   Access: http://localhost:20001"
echo ""
print_status "🌐 Starting port-forward to access frontend..."
echo "   Starting kubectl port-forward in background..."
kubectl port-forward svc/frontend 8080:3000 -n blog-microservices &
PORT_FORWARD_PID=$!
echo "   Frontend accessible at: http://localhost:8080"
echo "   Port-forward PID: $PORT_FORWARD_PID"
echo "   To stop port-forward: kill $PORT_FORWARD_PID"

# Return to scripts directory
cd "${PROJECT_ROOT}/scripts"
