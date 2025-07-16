#!/bin/bash

# ==============================================
# 🎯 DEMO TRAFFIC ROUTING ĐỠN GIẢN
# ==============================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🎯 Demo Traffic Routing với Istio${NC}"
echo ""

# Setup port forwarding
echo -e "${YELLOW}🔧 Setting up port forwarding...${NC}"
kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80 >/dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 3

GATEWAY_URL="http://localhost:8080"
echo -e "${YELLOW}Gateway URL: $GATEWAY_URL${NC}"

# Test connectivity
echo -e "${YELLOW}🔍 Testing connectivity...${NC}"
if curl -s --max-time 5 "$GATEWAY_URL/api/blogs" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Gateway is accessible${NC}"
else
    echo -e "${RED}❌ Cannot reach gateway. Please check port forwarding.${NC}"
    kill $PORT_FORWARD_PID 2>/dev/null
    exit 1
fi
echo ""

# Test function
test_traffic() {
    echo -e "${GREEN}=== $1 ===${NC}"
    echo "Gửi 10 requests để test..."
    
    v1_count=0
    v2_count=0
    
    for i in {1..10}; do
        response=$(curl -s "$GATEWAY_URL/api/blogs" 2>/dev/null)
        if echo "$response" | grep -q "V2 features"; then
            v2_count=$((v2_count + 1))
            echo "Request $i: ✅ Version V2"
        else
            v1_count=$((v1_count + 1))
            echo "Request $i: ⚪ Version V1"
        fi

        echo "Request $i: $response"
        echo '----------------------------'

        sleep 0.5
    done
    
    echo "Kết quả: V1=$v1_count, V2=$v2_count"
    echo ""
}

# Demo 1: Canary (70% v1, 30% v2)
echo -e "${GREEN}=== Applying Canary Deployment (70% v1, 30% v2) ===${NC}"
kubectl apply -f k8s/traffic-scenarios/canary.yaml
sleep 2

test_traffic "Canary Deployment (70% v1, 30% v2)"

# Demo 2: A/B Testing (50-50)
echo -e "${GREEN}=== Applying A/B Testing (50% v1, 50% v2) ===${NC}"
kubectl apply -f k8s/traffic-scenarios/ab-test.yaml
sleep 2

test_traffic "A/B Testing (50% v1, 50% v2)"

# # Demo 3: Header-based routing
# echo -e "${GREEN}=== Applying Header-based Routing ===${NC}"
# kubectl apply -f k8s/traffic-scenarios/header-routing.yaml
# sleep 2

# echo -e "${GREEN}=== Header-based Routing ===${NC}"
# echo "Test với header user-type: premium → V2"
# response=$(curl -s -H "user-type: premium" "$GATEWAY_URL/api/blogs" 2>/dev/null)
# if echo "$response" | grep -q "V2 features"; then
#     echo "✅ Premium user → Version V2"
# else
#     echo "❌ Premium user → Version V1 (có lỗi)"
# fi

# echo "Test không có header → V1"
# response=$(curl -s "$GATEWAY_URL/api/blogs" 2>/dev/null)
# if echo "$response" | grep -q "V2 features"; then
#     echo "❌ Normal user → Version V2 (có lỗi)"
# else
#     echo "✅ Normal user → Version V1"
# fi

echo ""
echo -e "${GREEN}✅ Demo hoàn thành!${NC}"
echo ""
echo -e "${YELLOW}🔄 Khôi phục VirtualService gốc...${NC}"
kubectl apply -f k8s/istio-gateway.yaml
echo ""
echo -e "${YELLOW}🧹 Cleaning up port forwarding...${NC}"
kill $PORT_FORWARD_PID 2>/dev/null
echo ""
echo -e "${YELLOW}💡 Các scenario có sẵn trong k8s/traffic-scenarios/:${NC}"
echo "- Canary Deployment (70-30): k8s/traffic-scenarios/canary.yaml"
# echo "- A/B Testing (50-50): k8s/traffic-scenarios/ab-test.yaml"
# echo "- Header-based Routing: k8s/traffic-scenarios/header-routing.yaml"
# echo "- Fault Injection: k8s/traffic-scenarios/fault-injection.yaml"
echo ""
echo -e "${YELLOW}📝 Để áp dụng scenario có sẵn:${NC}"
echo "kubectl apply -f k8s/traffic-scenarios/canary.yaml"
echo "kubectl apply -f k8s/traffic-scenarios/ab-test.yaml"
echo "kubectl apply -f k8s/traffic-scenarios/header-routing.yaml"
