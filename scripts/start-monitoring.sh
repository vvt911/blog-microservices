#!/bin/bash

# Start all monitoring dashboards
set -e

echo "🚀 Starting monitoring dashboards for Blog Microservices..."

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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if monitoring components are running
print_status "Checking monitoring components status..."

if ! kubectl get deployment prometheus -n istio-system > /dev/null 2>&1; then
    print_error "Prometheus is not deployed. Please run deploy.sh first."
    exit 1
fi

if ! kubectl get deployment grafana -n istio-system > /dev/null 2>&1; then
    print_error "Grafana is not deployed. Please run deploy.sh first."
    exit 1
fi

if ! kubectl get deployment kiali -n istio-system > /dev/null 2>&1; then
    print_error "Kiali is not deployed. Please run deploy.sh first."
    exit 1
fi

print_success "All monitoring components are available"

# Function to check if port is available
check_port() {
    if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_warning "Port $1 is already in use. Trying next available port..."
        return 1
    fi
    return 0
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

# Store PIDs and ports for cleanup
PIDS=()
PORTS=()

# Start Grafana port-forward
GRAFANA_PORT=$(find_available_port 3000)
if [ "$GRAFANA_PORT" != "0" ]; then
    print_status "Starting Grafana port-forward on port $GRAFANA_PORT..."
    kubectl port-forward svc/grafana $GRAFANA_PORT:3000 -n istio-system > /dev/null 2>&1 &
    GRAFANA_PID=$!
    PIDS+=($GRAFANA_PID)
    PORTS+=("Grafana:$GRAFANA_PORT")
    print_success "Grafana accessible at: http://localhost:$GRAFANA_PORT"
    echo "           Default credentials: admin/admin"
fi

# Start Prometheus port-forward
PROMETHEUS_PORT=$(find_available_port 9090)
if [ "$PROMETHEUS_PORT" != "0" ]; then
    print_status "Starting Prometheus port-forward on port $PROMETHEUS_PORT..."
    kubectl port-forward svc/prometheus $PROMETHEUS_PORT:9090 -n istio-system > /dev/null 2>&1 &
    PROMETHEUS_PID=$!
    PIDS+=($PROMETHEUS_PID)
    PORTS+=("Prometheus:$PROMETHEUS_PORT")
    print_success "Prometheus accessible at: http://localhost:$PROMETHEUS_PORT"
fi

# Start Kiali port-forward
KIALI_PORT=$(find_available_port 20001)
if [ "$KIALI_PORT" != "0" ]; then
    print_status "Starting Kiali port-forward on port $KIALI_PORT..."
    kubectl port-forward svc/kiali $KIALI_PORT:20001 -n istio-system > /dev/null 2>&1 &
    KIALI_PID=$!
    PIDS+=($KIALI_PID)
    PORTS+=("Kiali:$KIALI_PORT")
    print_success "Kiali accessible at: http://localhost:$KIALI_PORT"
fi

# Start Jaeger port-forward
JAEGER_PORT=$(find_available_port 16686)
if [ "$JAEGER_PORT" != "0" ]; then
    print_status "Starting Jaeger port-forward on port $JAEGER_PORT..."
    kubectl port-forward svc/jaeger $JAEGER_PORT:16686 -n istio-system > /dev/null 2>&1 &
    JAEGER_PID=$!
    PIDS+=($JAEGER_PID)
    PORTS+=("Jaeger:$JAEGER_PORT")
    print_success "Jaeger accessible at: http://localhost:$JAEGER_PORT"
fi

# Start Frontend port-forward if available
FRONTEND_PORT=$(find_available_port 8080)
if [ "$FRONTEND_PORT" != "0" ]; then
    print_status "Starting Frontend port-forward on port $FRONTEND_PORT..."
    kubectl port-forward svc/frontend $FRONTEND_PORT:3000 -n blog-microservices > /dev/null 2>&1 &
    FRONTEND_PID=$!
    PIDS+=($FRONTEND_PID)
    PORTS+=("Frontend:$FRONTEND_PORT")
    print_success "Frontend accessible at: http://localhost:$FRONTEND_PORT"
fi

echo ""
print_success "🎉 All monitoring dashboards are running!"
echo ""
print_status "📊 Access URLs:"
for port_info in "${PORTS[@]}"; do
    service=$(echo $port_info | cut -d: -f1)
    port=$(echo $port_info | cut -d: -f2)
    case $service in
        "Frontend")
            echo "   Frontend App:        http://localhost:$port"
            ;;
        "Grafana")
            echo "   Grafana Dashboards:  http://localhost:$port  (admin/admin)"
            ;;
        "Prometheus")
            echo "   Prometheus Metrics:  http://localhost:$port"
            ;;
        "Kiali")
            echo "   Kiali Service Mesh:  http://localhost:$port"
            ;;
        "Jaeger")
            echo "   Jaeger Tracing:      http://localhost:$port"
            ;;
    esac
done
echo ""
print_status "🔍 Useful Grafana Dashboards:"
echo "   - Istio Service Dashboard"
echo "   - Istio Workload Dashboard"
echo "   - Istio Mesh Dashboard"
echo "   - Istio Performance Dashboard"
echo ""
print_status "📈 Generate some traffic to see metrics:"
echo "   while true; do curl http://localhost:8080; sleep 1; done"
echo ""
print_warning "⚠️  Press Ctrl+C to stop all port-forwards"

# Create cleanup function
cleanup() {
    echo ""
    print_status "Stopping all port-forwards..."
    for pid in "${PIDS[@]}"; do
        if kill -0 $pid 2>/dev/null; then
            kill $pid
        fi
    done
    print_success "All port-forwards stopped"
    exit 0
}

# Set trap for cleanup
trap cleanup INT TERM

# Keep script running
while true; do
    sleep 1
done
