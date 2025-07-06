#!/bin/bash

# Stop local development environment
set -e

echo "🛑 Stopping Blog Microservices development environment..."

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

# Function to stop service by PID file
stop_service() {
    local service_name=$1
    local pid_file=".$service_name.pid"
    
    if [ -f $pid_file ]; then
        local pid=$(cat $pid_file)
        if ps -p $pid > /dev/null 2>&1; then
            print_status "Stopping $service_name (PID: $pid)..."
            kill $pid
            sleep 2
            if ps -p $pid > /dev/null 2>&1; then
                print_warning "Force killing $service_name..."
                kill -9 $pid
            fi
            print_success "$service_name stopped"
        else
            print_warning "$service_name was not running"
        fi
        rm -f $pid_file
    else
        print_warning "No PID file found for $service_name"
    fi
}

# Stop all services
stop_service "frontend"
stop_service "blog"
stop_service "comment"
stop_service "user"
stop_service "notification"

# Kill any remaining node processes on our ports
print_status "Checking for any remaining processes..."
for port in 3000 3001 3002 3003 3004; do
    pid=$(lsof -ti:$port 2>/dev/null || true)
    if [ ! -z "$pid" ]; then
        print_status "Killing process on port $port (PID: $pid)..."
        kill -9 $pid 2>/dev/null || true
    fi
done

print_success "🎉 All services stopped successfully!"
echo ""
print_status "To start services again, run:"
echo "   ./start-dev.sh"
