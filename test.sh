#!/bin/bash

# Test script for monitoring infrastructure
echo "🧪 Testing Monitoring Infrastructure Setup..."

# Function to check if service is ready
check_service() {
    local service=$1
    local port=$2
    local max_attempts=30
    local attempt=0
    
    echo "⏳ Checking $service on port $port..."
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f "http://localhost:$port" >/dev/null 2>&1; then
            echo "✅ $service is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        echo "   Attempt $attempt/$max_attempts..."
        sleep 10
    done
    
    echo "❌ $service failed to start within timeout"
    return 1
}

# Function to test API endpoint
test_api() {
    local url=$1
    local description=$2
    
    echo "🔍 Testing $description..."
    response=$(curl -s -w "%{http_code}" "$url")
    http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        echo "✅ $description - OK"
        return 0
    else
        echo "❌ $description - Failed (HTTP $http_code)"
        return 1
    fi
}

# Check Kubernetes cluster
echo "🔧 Checking Kubernetes cluster..."
if kubectl cluster-info >/dev/null 2>&1; then
    echo "✅ Kubernetes cluster is accessible"
else
    echo "❌ Kubernetes cluster is not accessible"
    exit 1
fi

# Check namespace and pods
echo "🔍 Checking deployed resources..."

# Check SigNoz namespace
if kubectl get namespace signoz-system >/dev/null 2>&1; then
    echo "✅ signoz-system namespace exists"
    
    # Check OTEL collector
    if kubectl get pods -n signoz-system | grep -q "Running"; then
        echo "✅ OpenTelemetry collector is running"
    else
        echo "❌ OpenTelemetry collector is not running"
        kubectl get pods -n signoz-system
    fi
else
    echo "❌ signoz-system namespace not found"
fi

# Check rolldice app
if kubectl get pods | grep -q "rolldice-otel"; then
    echo "✅ Rolldice application is deployed"
    
    # Check if pods are running
    if kubectl get pods | grep "rolldice-otel" | grep -q "Running"; then
        echo "✅ Rolldice pods are running"
    else
        echo "❌ Rolldice pods are not running"
        kubectl get pods | grep "rolldice-otel"
    fi
else
    echo "❌ Rolldice application not found"
fi

# Check Docker containers (SigNoz)
echo "🐳 Checking Docker containers..."
if docker ps | grep -q "signoz"; then
    echo "✅ SigNoz containers are running"
else
    echo "❌ SigNoz containers are not running"
    echo "   Running containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}"
fi

# Wait for services to be ready and test them
echo "⏳ Waiting for services to be ready..."

# Port forward rolldice app in background
echo "🔄 Setting up port forwarding for rolldice app..."
kubectl port-forward service/rolldice-otel-service 8080:80 >/dev/null 2>&1 &
ROLLDICE_PF_PID=$!

# Give port forwarding time to establish
sleep 5

# Test rolldice application
if test_api "http://localhost:8080/health" "Rolldice health check"; then
    echo "🎲 Testing dice rolling..."
    roll_response=$(curl -s -X POST http://localhost:8080/api/roll)
    if echo "$roll_response" | grep -q "value"; then
        echo "✅ Dice rolling API works"
        echo "   Response: $roll_response"
    else
        echo "❌ Dice rolling API failed"
    fi
    
    echo "📊 Testing statistics API..."
    stats_response=$(curl -s http://localhost:8080/api/stats)
    if echo "$stats_response" | grep -q "totalRolls"; then
        echo "✅ Statistics API works"
        echo "   Response: $stats_response"
    else
        echo "❌ Statistics API failed"
    fi
fi

# Test SigNoz (assuming it's accessible on port 3301)
if check_service "SigNoz" "3301"; then
    echo "✅ SigNoz dashboard is accessible"
else
    echo "❌ SigNoz dashboard is not accessible"
fi

# Cleanup port forwarding
if [ ! -z "$ROLLDICE_PF_PID" ]; then
    kill $ROLLDICE_PF_PID 2>/dev/null
fi

# Check for telemetry data generation
echo "📈 Checking telemetry generation..."
if kubectl get cronjob rolldice-load-generator >/dev/null 2>&1; then
    echo "✅ Load generator CronJob is configured"
    
    # Check if any jobs have run
    job_count=$(kubectl get jobs | grep "rolldice-load-generator" | wc -l)
    if [ "$job_count" -gt 0 ]; then
        echo "✅ Load generator jobs have been created ($job_count jobs)"
    else
        echo "ℹ️  Load generator jobs haven't run yet (jobs run every minute)"
    fi
else
    echo "❌ Load generator CronJob not found"
fi

echo ""
echo "🎯 Test Summary:"
echo "=================="

# Final status check
failed_tests=0

# Check critical components
components=(
    "kubectl cluster-info:Kubernetes cluster"
    "kubectl get ns signoz-system:SigNoz namespace"
    "kubectl get pods | grep rolldice-otel:Rolldice application"
    "docker ps | grep signoz:SigNoz containers"
)

for component in "${components[@]}"; do
    cmd="${component%%:*}"
    name="${component##*:}"
    
    if eval "$cmd" >/dev/null 2>&1; then
        echo "✅ $name"
    else
        echo "❌ $name"
        failed_tests=$((failed_tests + 1))
    fi
done

echo ""
if [ $failed_tests -eq 0 ]; then
    echo "🎉 All tests passed! Your monitoring infrastructure is ready."
    echo ""
    echo "🔗 Access URLs:"
    echo "   SigNoz Dashboard: http://localhost:3301"
    echo "   Rolldice App: kubectl port-forward service/rolldice-otel-service 8080:80"
    echo "                 then visit http://localhost:8080"
    echo ""
    echo "📊 Check SigNoz for 'rolldice-otel' service telemetry data"
else
    echo "⚠️  $failed_tests test(s) failed. Check the output above for details."
    exit 1
fi
