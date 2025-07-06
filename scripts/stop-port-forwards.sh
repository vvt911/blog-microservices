#!/bin/bash

# Stop all port-forward processes for blog microservices
set -e

echo "🧹 Stopping all port-forwards for Blog Microservices..."

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

# Function to kill port-forward processes
kill_port_forwards() {
    local service_name=$1
    local namespace=$2
    
    # Find kubectl port-forward processes for this service
    local pids=$(pgrep -f "kubectl port-forward.*$service_name.*$namespace" 2>/dev/null || echo "")
    
    if [ -n "$pids" ]; then
        print_status "Stopping port-forwards for $service_name..."
        echo "$pids" | while read pid; do
            if kill $pid 2>/dev/null; then
                print_success "Stopped port-forward process $pid for $service_name"
            fi
        done
    else
        print_warning "No port-forward found for $service_name"
    fi
}

# Stop monitoring dashboards
print_status "Stopping monitoring dashboard port-forwards..."
kill_port_forwards "prometheus" "istio-system"
kill_port_forwards "grafana" "istio-system"
kill_port_forwards "kiali" "istio-system"
kill_port_forwards "jaeger" "istio-system"

# Stop application port-forwards
print_status "Stopping application port-forwards..."
kill_port_forwards "frontend" "blog-microservices"

# Kill any remaining kubectl port-forward processes
print_status "Checking for remaining port-forward processes..."
remaining_pids=$(pgrep -f "kubectl port-forward" 2>/dev/null || echo "")

if [ -n "$remaining_pids" ]; then
    print_status "Found additional port-forward processes, stopping them..."
    echo "$remaining_pids" | while read pid; do
        process_info=$(ps -p $pid -o args= 2>/dev/null || echo "Unknown process")
        if kill $pid 2>/dev/null; then
            print_success "Stopped: $process_info"
        fi
    done
else
    print_success "No remaining port-forward processes found"
fi

# Check ports that might still be in use
print_status "Checking common ports..."
common_ports=(3000 8080 9090 16686 20001)

for port in "${common_ports[@]}"; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        process_info=$(lsof -Pi :$port -sTCP:LISTEN | tail -n +2)
        print_warning "Port $port is still in use:"
        echo "$process_info"
    fi
done

print_success "🎉 Port-forward cleanup completed!"

echo ""
print_status "📋 To restart monitoring:"
echo "   ./scripts/start-monitoring.sh"
echo ""
print_status "🔧 To manually check running processes:"
echo "   pgrep -f 'kubectl port-forward'"
echo "   lsof -i :8080  # Check specific port"
