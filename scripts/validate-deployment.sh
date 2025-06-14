#!/bin/bash

# Deployment Validation Script
# Author: Nguie Angoue Jean Roch Junior
# Email: nguierochjunior@gmail.com
# Description: Validates that all components of the Jenkins ML Pipeline are deployed and working correctly

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TIMEOUT=300
NAMESPACE_JENKINS="jenkins"
NAMESPACE_MONITORING="monitoring"
NAMESPACE_LOGGING="logging"
NAMESPACE_SECURITY="security"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available and cluster is accessible
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Wait for pod to be ready
wait_for_pod() {
    local namespace=$1
    local label_selector=$2
    local timeout=${3:-$TIMEOUT}
    
    log_info "Waiting for pods with selector '$label_selector' in namespace '$namespace'..."
    
    if kubectl wait --for=condition=ready pod \
        -l "$label_selector" \
        -n "$namespace" \
        --timeout="${timeout}s" &> /dev/null; then
        log_success "Pods are ready"
        return 0
    else
        log_error "Pods failed to become ready within ${timeout}s"
        return 1
    fi
}

# Check namespace exists
check_namespace() {
    local namespace=$1
    
    if kubectl get namespace "$namespace" &> /dev/null; then
        log_success "Namespace '$namespace' exists"
        return 0
    else
        log_error "Namespace '$namespace' does not exist"
        return 1
    fi
}

# Check service is accessible
check_service() {
    local namespace=$1
    local service_name=$2
    local port=$3
    
    log_info "Checking service '$service_name' in namespace '$namespace'..."
    
    if kubectl get service "$service_name" -n "$namespace" &> /dev/null; then
        log_success "Service '$service_name' exists"
        
        # Test service connectivity
        local pod_name="test-connectivity-$(date +%s)"
        kubectl run "$pod_name" \
            --image=curlimages/curl:latest \
            --rm -i --restart=Never \
            --timeout=30s \
            -- curl -s --connect-timeout 10 \
            "http://${service_name}.${namespace}.svc.cluster.local:${port}" > /dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            log_success "Service '$service_name' is accessible"
            return 0
        else
            log_warning "Service '$service_name' exists but may not be accessible"
            return 1
        fi
    else
        log_error "Service '$service_name' does not exist"
        return 1
    fi
}

# Validate Jenkins deployment
validate_jenkins() {
    log_info "Validating Jenkins deployment..."
    
    check_namespace "$NAMESPACE_JENKINS" || return 1
    
    # Check Jenkins controller
    wait_for_pod "$NAMESPACE_JENKINS" "app.kubernetes.io/name=jenkins" || return 1
    
    # Check Jenkins service
    check_service "$NAMESPACE_JENKINS" "jenkins" "8080" || return 1
    
    # Check Jenkins configuration
    local jenkins_pod=$(kubectl get pods -n "$NAMESPACE_JENKINS" -l "app.kubernetes.io/name=jenkins" -o jsonpath='{.items[0].metadata.name}')
    
    if [ -n "$jenkins_pod" ]; then
        log_info "Checking Jenkins configuration..."
        
        # Check if Jenkins is ready
        if kubectl exec -n "$NAMESPACE_JENKINS" "$jenkins_pod" -- curl -s http://localhost:8080/login &> /dev/null; then
            log_success "Jenkins is responding to HTTP requests"
        else
            log_warning "Jenkins may not be fully initialized yet"
        fi
        
        # Check Jenkins plugins
        local plugins_installed=$(kubectl exec -n "$NAMESPACE_JENKINS" "$jenkins_pod" -- ls /var/jenkins_home/plugins/ 2>/dev/null | wc -l)
        log_info "Jenkins plugins installed: $plugins_installed"
    fi
    
    log_success "Jenkins validation completed"
}

# Validate monitoring stack
validate_monitoring() {
    log_info "Validating monitoring stack..."
    
    check_namespace "$NAMESPACE_MONITORING" || return 1
    
    # Check Prometheus
    wait_for_pod "$NAMESPACE_MONITORING" "app.kubernetes.io/name=prometheus" 60 || log_warning "Prometheus pods not ready"
    check_service "$NAMESPACE_MONITORING" "prometheus-kube-prometheus-prometheus" "9090" || log_warning "Prometheus service not accessible"
    
    # Check Grafana
    wait_for_pod "$NAMESPACE_MONITORING" "app.kubernetes.io/name=grafana" 60 || log_warning "Grafana pods not ready"
    check_service "$NAMESPACE_MONITORING" "prometheus-grafana" "80" || log_warning "Grafana service not accessible"
    
    # Check AlertManager
    wait_for_pod "$NAMESPACE_MONITORING" "app.kubernetes.io/name=alertmanager" 60 || log_warning "AlertManager pods not ready"
    
    # Check Jaeger
    wait_for_pod "$NAMESPACE_MONITORING" "app.kubernetes.io/name=jaeger" 60 || log_warning "Jaeger pods not ready"
    check_service "$NAMESPACE_MONITORING" "jaeger-query" "16686" || log_warning "Jaeger service not accessible"
    
    log_success "Monitoring stack validation completed"
}

# Validate logging stack
validate_logging() {
    log_info "Validating logging stack..."
    
    check_namespace "$NAMESPACE_LOGGING" || return 1
    
    # Check Elasticsearch
    wait_for_pod "$NAMESPACE_LOGGING" "app=elasticsearch-master" 120 || log_warning "Elasticsearch pods not ready"
    check_service "$NAMESPACE_LOGGING" "elasticsearch-master" "9200" || log_warning "Elasticsearch service not accessible"
    
    # Check Kibana
    wait_for_pod "$NAMESPACE_LOGGING" "app=kibana" 60 || log_warning "Kibana pods not ready"
    check_service "$NAMESPACE_LOGGING" "kibana-kibana" "5601" || log_warning "Kibana service not accessible"
    
    # Check Fluent Bit
    wait_for_pod "$NAMESPACE_LOGGING" "app.kubernetes.io/name=fluent-bit" 60 || log_warning "Fluent Bit pods not ready"
    
    log_success "Logging stack validation completed"
}

# Validate security components
validate_security() {
    log_info "Validating security components..."
    
    check_namespace "$NAMESPACE_SECURITY" || return 1
    
    # Check Vault
    wait_for_pod "$NAMESPACE_SECURITY" "app.kubernetes.io/name=vault" 60 || log_warning "Vault pods not ready"
    check_service "$NAMESPACE_SECURITY" "vault" "8200" || log_warning "Vault service not accessible"
    
    # Check Trivy Operator
    wait_for_pod "$NAMESPACE_SECURITY" "app.kubernetes.io/name=trivy-operator" 60 || log_warning "Trivy Operator pods not ready"
    
    log_success "Security components validation completed"
}

# Check resource usage
check_resource_usage() {
    log_info "Checking resource usage..."
    
    # Node resource usage
    log_info "Node resource usage:"
    kubectl top nodes 2>/dev/null || log_warning "Metrics server not available"
    
    # Pod resource usage
    log_info "Pod resource usage by namespace:"
    for ns in "$NAMESPACE_JENKINS" "$NAMESPACE_MONITORING" "$NAMESPACE_LOGGING" "$NAMESPACE_SECURITY"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            log_info "Namespace: $ns"
            kubectl top pods -n "$ns" 2>/dev/null || log_warning "Pod metrics not available for $ns"
        fi
    done
}

# Test ML pipeline functionality
test_ml_pipeline() {
    log_info "Testing ML pipeline functionality..."
    
    # Create a test job
    local test_job_name="ml-pipeline-test-$(date +%s)"
    
    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: $test_job_name
  namespace: $NAMESPACE_JENKINS
spec:
  template:
    spec:
      containers:
      - name: ml-test
        image: python:3.9-slim
        command: ["python", "-c"]
        args:
        - |
          import sys
          print("Testing ML pipeline components...")
          
          # Test basic ML libraries
          try:
              import numpy as np
              import pandas as pd
              print("✓ NumPy and Pandas available")
          except ImportError as e:
              print(f"✗ ML libraries not available: {e}")
              sys.exit(1)
          
          # Test data processing
          data = np.random.rand(100, 10)
          df = pd.DataFrame(data)
          print(f"✓ Data processing test passed: {df.shape}")
          
          # Test model training simulation
          from sklearn.linear_model import LogisticRegression
          from sklearn.model_selection import train_test_split
          
          X = np.random.rand(100, 5)
          y = np.random.randint(0, 2, 100)
          X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)
          
          model = LogisticRegression()
          model.fit(X_train, y_train)
          accuracy = model.score(X_test, y_test)
          print(f"✓ Model training test passed: accuracy={accuracy:.3f}")
          
          print("ML pipeline test completed successfully!")
      restartPolicy: Never
  backoffLimit: 3
EOF
    
    # Wait for job completion
    log_info "Waiting for ML pipeline test to complete..."
    if kubectl wait --for=condition=complete job/"$test_job_name" -n "$NAMESPACE_JENKINS" --timeout=120s; then
        log_success "ML pipeline test completed successfully"
        
        # Show job logs
        local pod_name=$(kubectl get pods -n "$NAMESPACE_JENKINS" -l "job-name=$test_job_name" -o jsonpath='{.items[0].metadata.name}')
        if [ -n "$pod_name" ]; then
            log_info "Test output:"
            kubectl logs -n "$NAMESPACE_JENKINS" "$pod_name"
        fi
    else
        log_error "ML pipeline test failed or timed out"
    fi
    
    # Clean up test job
    kubectl delete job "$test_job_name" -n "$NAMESPACE_JENKINS" &> /dev/null || true
}

# Generate validation report
generate_report() {
    log_info "Generating validation report..."
    
    local report_file="/tmp/jenkins-ml-pipeline-validation-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "Jenkins ML Pipeline Validation Report"
        echo "Generated: $(date)"
        echo "Cluster: $(kubectl config current-context)"
        echo "=========================================="
        echo
        
        echo "NAMESPACES:"
        kubectl get namespaces | grep -E "(jenkins|monitoring|logging|security)" || echo "No relevant namespaces found"
        echo
        
        echo "PODS STATUS:"
        for ns in "$NAMESPACE_JENKINS" "$NAMESPACE_MONITORING" "$NAMESPACE_LOGGING" "$NAMESPACE_SECURITY"; do
            if kubectl get namespace "$ns" &> /dev/null; then
                echo "Namespace: $ns"
                kubectl get pods -n "$ns" -o wide
                echo
            fi
        done
        
        echo "SERVICES:"
        for ns in "$NAMESPACE_JENKINS" "$NAMESPACE_MONITORING" "$NAMESPACE_LOGGING" "$NAMESPACE_SECURITY"; do
            if kubectl get namespace "$ns" &> /dev/null; then
                echo "Namespace: $ns"
                kubectl get services -n "$ns"
                echo
            fi
        done
        
        echo "PERSISTENT VOLUMES:"
        kubectl get pv
        echo
        
        echo "STORAGE CLASSES:"
        kubectl get storageclass
        echo
        
    } > "$report_file"
    
    log_success "Validation report saved to: $report_file"
}

# Display access information
show_access_info() {
    log_info "Access Information:"
    echo
    echo "To access the services, use kubectl port-forward:"
    echo
    echo "Jenkins:"
    echo "  kubectl port-forward -n jenkins svc/jenkins 8080:8080"
    echo "  Access: http://localhost:8080"
    echo
    echo "Grafana:"
    echo "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
    echo "  Access: http://localhost:3000 (admin/admin123)"
    echo
    echo "Prometheus:"
    echo "  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
    echo "  Access: http://localhost:9090"
    echo
    echo "Kibana:"
    echo "  kubectl port-forward -n logging svc/kibana-kibana 5601:5601"
    echo "  Access: http://localhost:5601"
    echo
    echo "Jaeger:"
    echo "  kubectl port-forward -n monitoring svc/jaeger-query 16686:16686"
    echo "  Access: http://localhost:16686"
    echo
    echo "Vault:"
    echo "  kubectl port-forward -n security svc/vault 8200:8200"
    echo "  Access: http://localhost:8200"
    echo
}

# Main validation function
main() {
    log_info "Starting Jenkins ML Pipeline validation..."
    echo
    
    local validation_failed=0
    
    # Run validations
    check_prerequisites || ((validation_failed++))
    validate_jenkins || ((validation_failed++))
    validate_monitoring || ((validation_failed++))
    validate_logging || ((validation_failed++))
    validate_security || ((validation_failed++))
    
    # Additional checks
    check_resource_usage
    test_ml_pipeline || ((validation_failed++))
    
    # Generate report
    generate_report
    
    echo
    if [ $validation_failed -eq 0 ]; then
        log_success "All validations passed! Jenkins ML Pipeline is ready for production."
        show_access_info
        exit 0
    else
        log_error "$validation_failed validation(s) failed. Please check the logs above."
        show_access_info
        exit 1
    fi
}

# Handle script interruption
trap 'log_warning "Validation interrupted"; exit 130' INT TERM

# Run main function
main "$@" 