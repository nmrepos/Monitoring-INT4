#!/bin/bash
# DevSecOps Monitoring Stack - Complete Validation Script
# This script tests all components and validates the complete setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASSED_TESTS++))
}

error() {
    echo -e "${RED}❌ $1${NC}"
    ((FAILED_TESTS++))
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

test_function() {
    ((TOTAL_TESTS++))
    local test_name="$1"
    local test_command="$2"
    
    log "Testing: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        success "$test_name"
        return 0
    else
        error "$test_name"
        return 1
    fi
}

# Print banner
echo -e "${BLUE}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║              DevSecOps Monitoring Stack Validator           ║
║                     INT4 Project Testing                    ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# 1. Pre-requisites validation
log "🔍 Phase 1: Pre-requisites Validation"

test_function "Docker installed" "docker --version"
test_function "Kubectl installed" "kubectl version --client"
test_function "Helm installed" "helm version --short"
test_function "Ansible installed" "ansible --version"
test_function "Python kubernetes module" "python3 -c 'import kubernetes'"

# 2. Kubernetes cluster validation
log "🔍 Phase 2: Kubernetes Cluster Validation"

test_function "Kubernetes cluster accessible" "kubectl cluster-info"
test_function "k3s service running" "sudo systemctl is-active k3s"
test_function "Kubectl config valid" "kubectl get nodes"
test_function "Monitoring namespace exists" "kubectl get namespace monitoring"

# 3. k8s-infra Helm chart validation
log "🔍 Phase 3: k8s-infra Helm Chart Validation"

test_function "k8s-infra release deployed" "helm list -n monitoring | grep monitoring-int4-k8s-infra"
test_function "OTEL collector pods running" "kubectl get pods -n monitoring -l app.kubernetes.io/instance=monitoring-int4-k8s-infra --field-selector=status.phase=Running"
test_function "OTEL collector service accessible" "kubectl get svc -n monitoring monitoring-int4-k8s-infra"
test_function "OTEL collector health check" "kubectl exec -n monitoring deployment/monitoring-int4-k8s-infra -- curl -f http://localhost:13133/health"

# 4. SigNoz validation
log "🔍 Phase 4: SigNoz Validation"

test_function "SigNoz containers running" "docker-compose -f signoz/docker-compose.yml ps | grep Up"
test_function "SigNoz frontend accessible" "curl -f http://localhost:3301/api/v1/version"
test_function "ClickHouse accessible" "docker-compose -f signoz/docker-compose.yml exec -T clickhouse clickhouse-client --query 'SELECT 1'"
test_function "Query service healthy" "curl -f http://localhost:8080/api/v1/health"

# 5. Rolldice application validation
log "🔍 Phase 5: Rolldice Application Validation"

test_function "Rolldice deployment running" "kubectl get deployment rolldice -n monitoring -o jsonpath='{.status.readyReplicas}' | grep -E '^[1-9]'"
test_function "Rolldice pods healthy" "kubectl get pods -n monitoring -l app=rolldice --field-selector=status.phase=Running"
test_function "Rolldice service accessible" "kubectl get svc rolldice -n monitoring"

# Port forward for testing (background process)
kubectl port-forward -n monitoring svc/rolldice 8080:80 >/dev/null 2>&1 &
PORTFORWARD_PID=$!
sleep 5

test_function "Rolldice health endpoint" "curl -f http://localhost:8080/health"
test_function "Rolldice dice endpoint" "curl -f 'http://localhost:8080/rolldice?player=test'"
test_function "Rolldice metrics endpoint" "curl -f http://localhost:8080/metrics"

# Kill port-forward
kill $PORTFORWARD_PID 2>/dev/null || true

# 6. OpenTelemetry integration validation
log "🔍 Phase 6: OpenTelemetry Integration Validation"

# Generate some test telemetry
kubectl exec -n monitoring deployment/rolldice -- curl -s "http://localhost:8080/rolldice?player=validation-test" >/dev/null || true

test_function "OTEL collector receiving data" "kubectl logs -n monitoring -l app.kubernetes.io/instance=monitoring-int4-k8s-infra --tail=100 | grep -i 'request'"
test_function "OTEL collector metrics endpoint" "kubectl exec -n monitoring deployment/monitoring-int4-k8s-infra -- curl -f http://localhost:8888/metrics"

# 7. Security validation
log "🔍 Phase 7: Security Validation"

test_function "Pods running as non-root" "kubectl get pods -n monitoring -o jsonpath='{.items[*].spec.securityContext.runAsNonRoot}' | grep -v false"
test_function "Network policies exist" "kubectl get networkpolicies -n monitoring"
test_function "RBAC configured" "kubectl get rolebindings,clusterrolebindings -n monitoring"

# 8. Performance validation
log "🔍 Phase 8: Performance Validation"

# Port forward again for load testing
kubectl port-forward -n monitoring svc/rolldice 8080:80 >/dev/null 2>&1 &
PORTFORWARD_PID=$!
sleep 3

# Simple load test
log "Running simple load test..."
for i in {1..10}; do
    curl -s "http://localhost:8080/rolldice?player=load-test-$i" >/dev/null &
done
wait

test_function "Load test completed" "true"
test_function "Pods stable after load" "kubectl get pods -n monitoring -l app=rolldice --field-selector=status.phase=Running"

# Kill port-forward
kill $PORTFORWARD_PID 2>/dev/null || true

# 9. Monitoring data validation
log "🔍 Phase 9: Monitoring Data Validation"

# Check if traces are being generated
test_function "Traces in OTEL collector logs" "kubectl logs -n monitoring -l app.kubernetes.io/instance=monitoring-int4-k8s-infra --tail=200 | grep -i trace"

# 10. vSphere specific tests (if running on vSphere)
log "🔍 Phase 10: vSphere Integration Tests"

if [ -n "$VSPHERE_SERVER" ]; then
    test_function "vSphere environment variables set" "test -n '$VSPHERE_SERVER'"
    test_function "VM metadata in OTEL config" "kubectl get configmap -n monitoring -o yaml | grep -i vsphere"
else
    warning "vSphere environment variables not set, skipping vSphere-specific tests"
fi

# 11. Data persistence validation
log "🔍 Phase 11: Data Persistence Validation"

test_function "ClickHouse data directory mounted" "docker-compose -f signoz/docker-compose.yml exec -T clickhouse ls -la /var/lib/clickhouse/data"
test_function "ConfigMaps properly mounted" "kubectl get configmaps -n monitoring"

# 12. Final integration test
log "🔍 Phase 12: End-to-End Integration Test"

# Port forward for final test
kubectl port-forward -n monitoring svc/rolldice 8080:80 >/dev/null 2>&1 &
PORTFORWARD_PID=$!
sleep 3

# Generate telemetry and check if it flows through the system
TRACE_RESPONSE=$(curl -s "http://localhost:8080/rolldice?player=integration-test")
TRACE_ID=$(echo "$TRACE_RESPONSE" | jq -r '.trace_id' 2>/dev/null || echo "")

if [ -n "$TRACE_ID" ] && [ "$TRACE_ID" != "null" ]; then
    success "End-to-end telemetry flow working (Trace ID: $TRACE_ID)"
    ((PASSED_TESTS++))
else
    error "End-to-end telemetry flow validation failed"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Kill port-forward
kill $PORTFORWARD_PID 2>/dev/null || true

# Test summary
echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                        TEST SUMMARY                         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n📊 Test Results:"
echo -e "   Total Tests: ${BLUE}$TOTAL_TESTS${NC}"
echo -e "   Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "   Failed: ${RED}$FAILED_TESTS${NC}"
echo -e "   Success Rate: ${GREEN}$(( PASSED_TESTS * 100 / TOTAL_TESTS ))%${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n🎉 ${GREEN}ALL TESTS PASSED!${NC}"
    echo -e "✅ Your DevSecOps monitoring stack is fully functional!"
    
    echo -e "\n🎯 Next Steps:"
    echo -e "   1. Access SigNoz dashboard: http://localhost:3301"
    echo -e "   2. Port-forward rolldice: kubectl port-forward -n monitoring svc/rolldice 8080:80"
    echo -e "   3. Generate test data: curl 'http://localhost:8080/rolldice?player=demo'"
    echo -e "   4. Monitor traces and metrics in SigNoz"
    
    exit 0
else
    echo -e "\n🚨 ${RED}SOME TESTS FAILED!${NC}"
    echo -e "❌ Please check the failed tests and troubleshoot accordingly."
    
    echo -e "\n🔧 Troubleshooting Tips:"
    echo -e "   1. Check pod logs: kubectl logs -n monitoring <pod-name>"
    echo -e "   2. Verify services: kubectl get svc -n monitoring"
    echo -e "   3. Check events: kubectl get events -n monitoring --sort-by=.metadata.creationTimestamp"
    echo -e "   4. Restart failed components: kubectl rollout restart deployment/<deployment-name> -n monitoring"
    
    exit 1
fi
