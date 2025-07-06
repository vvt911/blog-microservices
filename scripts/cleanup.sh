#!/bin/bash

# Clean up Kubernetes resources
set -e

echo "🧹 Cleaning up Blog Microservices from Kubernetes..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Delete Kubernetes resources
print_status "Deleting Kubernetes resources..."

cd ../k8s

# Delete Istio configurations
print_status "Deleting Istio configurations..."
kubectl delete -f destination-rules.yaml --ignore-not-found=true
kubectl delete -f istio-gateway.yaml --ignore-not-found=true

# Delete services and deployments
print_status "Deleting services and deployments..."
kubectl delete -f services.yaml --ignore-not-found=true

# Delete namespace
print_status "Deleting namespace..."
kubectl delete namespace blog-microservices --ignore-not-found=true

print_success "All Kubernetes resources deleted"

# Clean up Docker images (optional)
read -p "Do you want to delete Docker images? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Deleting Docker images..."
    
    # Switch to minikube docker environment
    eval $(minikube -p minikube docker-env)
    
    docker rmi blog-frontend:latest 2>/dev/null || print_warning "blog-frontend image not found"
    docker rmi blog-service:latest 2>/dev/null || print_warning "blog-service image not found"
    docker rmi comment-service:latest 2>/dev/null || print_warning "comment-service image not found"
    docker rmi user-service:latest 2>/dev/null || print_warning "user-service image not found"
    docker rmi notification-service:latest 2>/dev/null || print_warning "notification-service image not found"
    
    print_success "Docker images deleted"
fi

cd ../scripts

print_success "🎉 Cleanup completed successfully!"
echo ""
print_status "To deploy again, run:"
echo "   ./deploy.sh"
