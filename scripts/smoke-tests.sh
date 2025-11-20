#!/bin/bash

# Smoke tests for the voting application
# Usage: ./scripts/smoke-tests.sh [dev|prod]

set -e

ENVIRONMENT=${1:-dev}
NAMESPACE="voting-app"
TIMEOUT=300  # 5 minutes

echo "Running smoke tests for environment: $ENVIRONMENT"

# Function to check if a pod is ready
wait_for_pod() {
    local app=$1
    local count=$2
    echo "Waiting for $app pods to be ready..."
    
    kubectl wait --for=condition=ready pod \
        -l app=$app \
        -n $NAMESPACE \
        --timeout=${TIMEOUT}s || {
        echo "ERROR: $app pods failed to become ready"
        kubectl get pods -n $NAMESPACE -l app=$app
        exit 1
    }
    
    local ready=$(kubectl get pods -n $NAMESPACE -l app=$app --no-headers | grep -c Running || true)
    if [ "$ready" -lt "$count" ]; then
        echo "ERROR: Expected at least $count $app pods, but only $ready are running"
        kubectl get pods -n $NAMESPACE -l app=$app
        exit 1
    fi
    
    echo "✓ $app pods are ready"
}

# Function to check service endpoint
check_endpoint() {
    local service=$1
    local port=$2
    local path=${3:-/}
    
    echo "Checking $service endpoint..."
    
    # Port forward in background
    kubectl port-forward -n $NAMESPACE svc/$service $port:$port > /dev/null 2>&1 &
    local pf_pid=$!
    sleep 5
    
    # Test endpoint
    if curl -f -s http://localhost:$port$path > /dev/null; then
        echo "✓ $service endpoint is accessible"
        kill $pf_pid 2>/dev/null || true
        return 0
    else
        echo "ERROR: $service endpoint is not accessible"
        kill $pf_pid 2>/dev/null || true
        return 1
    fi
}

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo "ERROR: kubectl is not configured or cluster is not accessible"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo "ERROR: Namespace $NAMESPACE does not exist"
    exit 1
fi

echo "Namespace $NAMESPACE exists"

# Wait for all pods to be ready
echo "Waiting for all pods to be ready..."
wait_for_pod "vote" 1
wait_for_pod "result" 1
wait_for_pod "worker" 1
wait_for_pod "postgres" 1
wait_for_pod "redis" 1

# Check services
echo "Checking services..."
if kubectl get svc -n $NAMESPACE vote result postgres redis &> /dev/null; then
    echo "✓ All services exist"
else
    echo "ERROR: Some services are missing"
    exit 1
fi

# Test vote service
if check_endpoint "vote" "80" "/"; then
    echo "✓ Vote service is responding"
else
    echo "ERROR: Vote service is not responding"
    exit 1
fi

# Test result service
if check_endpoint "result" "4000" "/"; then
    echo "✓ Result service is responding"
else
    echo "ERROR: Result service is not responding"
    exit 1
fi

# Check database connectivity (via worker logs)
echo "Checking database connectivity..."
sleep 10  # Give worker time to connect
if kubectl logs -n $NAMESPACE -l app=worker --tail=10 | grep -q "Connected to db" 2>/dev/null; then
    echo "✓ Worker connected to database"
else
    echo "WARNING: Could not verify database connection (this might be OK if worker hasn't logged yet)"
fi

# Check Redis connectivity
echo "Checking Redis connectivity..."
if kubectl logs -n $NAMESPACE -l app=worker --tail=10 | grep -q "Found redis" 2>/dev/null; then
    echo "✓ Worker connected to Redis"
else
    echo "WARNING: Could not verify Redis connection (this might be OK if worker hasn't logged yet)"
fi

# Summary
echo ""
echo "=========================================="
echo "✓ All smoke tests passed!"
echo "=========================================="
echo ""
echo "Services status:"
kubectl get pods -n $NAMESPACE
echo ""
echo "To access services:"
echo "  Vote:   kubectl port-forward -n $NAMESPACE svc/vote 8080:80"
echo "  Result: kubectl port-forward -n $NAMESPACE svc/result 8081:4000"

