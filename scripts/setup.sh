#!/bin/bash

# Jenkins ML Pipeline - Complete Setup Script
# Author: Nguie Angoue Jean Roch Junior
# Email: nguierochjunior@gmail.com
# License: MIT

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="jenkins-ml-pipeline"
NAMESPACE_JENKINS="jenkins"
NAMESPACE_MONITORING="monitoring"
NAMESPACE_LOGGING="logging"
NAMESPACE_SECURITY="security"
ENVIRONMENT="development"
ENABLE_GPU=false
SKIP_CLUSTER_CREATION=false

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}
███████╗███████╗████████╗██╗   ██╗██████╗ 
██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
███████╗█████╗     ██║   ██║   ██║██████╔╝
╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ 
███████║███████╗   ██║   ╚██████╔╝██║     
╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     
                                          
Jenkins ML Pipeline Setup
${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check required tools
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v helm >/dev/null 2>&1 || missing_tools+=("helm")
    command -v terraform >/dev/null 2>&1 || missing_tools+=("terraform")
    command -v docker >/dev/null 2>&1 || missing_tools+=("docker")
    command -v jq >/dev/null 2>&1 || missing_tools+=("jq")
    command -v curl >/dev/null 2>&1 || missing_tools+=("curl")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_status "Installing missing tools..."
        install_prerequisites "${missing_tools[@]}"
    else
        print_status "All prerequisites are installed ✓"
    fi
}

# Function to install prerequisites
install_prerequisites() {
    local tools=("$@")
    
    # Detect OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command -v apt-get >/dev/null 2>&1; then
            # Ubuntu/Debian
            sudo apt-get update
            for tool in "${tools[@]}"; do
                case $tool in
                    kubectl)
                        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
                        rm kubectl
                        ;;
                    helm)
                        curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
                        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
                        sudo apt-get update
                        sudo apt-get install helm
                        ;;
                    terraform)
                        wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
                        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
                        sudo apt-get update && sudo apt-get install terraform
                        ;;
                    docker)
                        sudo apt-get install docker.io
                        sudo systemctl start docker
                        sudo systemctl enable docker
                        sudo usermod -aG docker $USER
                        ;;
                    jq)
                        sudo apt-get install jq
                        ;;
                    curl)
                        sudo apt-get install curl
                        ;;
                esac
            done
        elif command -v yum >/dev/null 2>&1; then
            # RHEL/CentOS
            for tool in "${tools[@]}"; do
                case $tool in
                    kubectl)
                        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
                        rm kubectl
                        ;;
                    helm)
                        curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
                        chmod 700 get_helm.sh
                        ./get_helm.sh
                        rm get_helm.sh
                        ;;
                    terraform)
                        sudo yum install -y yum-utils
                        sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
                        sudo yum -y install terraform
                        ;;
                    docker)
                        sudo yum install docker
                        sudo systemctl start docker
                        sudo systemctl enable docker
                        sudo usermod -aG docker $USER
                        ;;
                    jq)
                        sudo yum install jq
                        ;;
                    curl)
                        sudo yum install curl
                        ;;
                esac
            done
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # Mac OSX
        if command -v brew >/dev/null 2>&1; then
            for tool in "${tools[@]}"; do
                brew install "$tool"
            done
        else
            print_error "Homebrew not found. Please install Homebrew first: https://brew.sh/"
            exit 1
        fi
    else
        print_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --cluster-name)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            --enable-gpu)
                ENABLE_GPU=true
                shift
                ;;
            --skip-cluster)
                SKIP_CLUSTER_CREATION=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown parameter: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --environment ENV        Set environment (development|staging|production) [default: development]"
    echo "  --cluster-name NAME      Set cluster name [default: jenkins-ml-pipeline]"
    echo "  --enable-gpu            Enable GPU support for ML workloads"
    echo "  --skip-cluster          Skip Kubernetes cluster creation"
    echo "  --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --environment production --enable-gpu"
    echo "  $0 --cluster-name my-cluster --skip-cluster"
}

# Function to create Kubernetes cluster
create_cluster() {
    if [ "$SKIP_CLUSTER_CREATION" = true ]; then
        print_status "Skipping cluster creation as requested"
        return
    fi
    
    print_status "Creating Kubernetes cluster: $CLUSTER_NAME"
    
    # Check if running on cloud or local
    if command -v kind >/dev/null 2>&1; then
        print_status "Using kind for local development cluster"
        create_kind_cluster
    elif command -v minikube >/dev/null 2>&1; then
        print_status "Using minikube for local development cluster"
        create_minikube_cluster
    else
        print_status "Installing kind for local cluster creation"
        install_kind
        create_kind_cluster
    fi
}

# Function to create kind cluster
create_kind_cluster() {
    cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $CLUSTER_NAME
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 8080
    hostPort: 8080
    protocol: TCP
- role: worker
- role: worker
- role: worker
EOF

    if [ "$ENABLE_GPU" = true ]; then
        print_warning "GPU support requires additional configuration for kind clusters"
    fi
    
    kind create cluster --config kind-config.yaml --wait 300s
    rm kind-config.yaml
    
    # Set kubectl context
    kubectl cluster-info --context kind-$CLUSTER_NAME
}

# Function to create minikube cluster
create_minikube_cluster() {
    local extra_args=""
    
    if [ "$ENABLE_GPU" = true ]; then
        extra_args="--gpus=all"
    fi
    
    minikube start \
        --profile=$CLUSTER_NAME \
        --nodes=3 \
        --cpus=4 \
        --memory=8192 \
        --disk-size=50g \
        --kubernetes-version=v1.27.0 \
        $extra_args
        
    minikube profile $CLUSTER_NAME
}

# Function to install kind
install_kind() {
    print_status "Installing kind..."
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
}

# Function to create namespaces
create_namespaces() {
    print_status "Creating Kubernetes namespaces..."
    
    kubectl create namespace $NAMESPACE_JENKINS --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace $NAMESPACE_MONITORING --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace $NAMESPACE_LOGGING --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace $NAMESPACE_SECURITY --dry-run=client -o yaml | kubectl apply -f -
    
    # Label namespaces
    kubectl label namespace $NAMESPACE_JENKINS app=jenkins-ml-pipeline --overwrite
    kubectl label namespace $NAMESPACE_MONITORING app=jenkins-ml-pipeline --overwrite
    kubectl label namespace $NAMESPACE_LOGGING app=jenkins-ml-pipeline --overwrite
    kubectl label namespace $NAMESPACE_SECURITY app=jenkins-ml-pipeline --overwrite
}

# Function to deploy infrastructure with Terraform
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    # Initialize Terraform for each module
    for module in kubernetes jenkins observability security; do
        print_status "Deploying $module infrastructure..."
        cd terraform/$module
        
        terraform init
        terraform plan \
            -var="cluster_name=$CLUSTER_NAME" \
            -var="environment=$ENVIRONMENT" \
            -var="enable_gpu=$ENABLE_GPU"
        terraform apply -auto-approve \
            -var="cluster_name=$CLUSTER_NAME" \
            -var="environment=$ENVIRONMENT" \
            -var="enable_gpu=$ENABLE_GPU"
        
        cd ../..
    done
}

# Function to install Jenkins
install_jenkins() {
    print_status "Installing Jenkins with Helm..."
    
    # Add Jenkins Helm repository
    helm repo add jenkins https://charts.jenkins.io
    helm repo update
    
    # Create Jenkins values file
    cat <<EOF > jenkins-values.yaml
controller:
  serviceType: LoadBalancer
  servicePort: 8080
  adminUser: admin
  adminPassword: admin123
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2
      memory: 4Gi
  installPlugins:
    - kubernetes:4046.v45084ce53f7b
    - workflow-aggregator:596.v8c21c963d92d
    - git:5.0.0
    - configuration-as-code:1670.v564dc8b_982d0
    - blueocean:1.25.9
    - pipeline-stage-view:2.25
    - docker-workflow:563.vd5d2e5c4007f
    - prometheus:2.0.10
    - kubernetes-cli:1.12.1
    - pipeline-utility-steps:2.15.1
    - http_request:1.16
    - build-timestamp:1.0.3
    - timestamper:1.21
    - ws-cleanup:0.44
    - ant:475.vf34069fef73c
    - gradle:2.8.2
    - maven-integration:3.19
    - python:1.3
    - terraform:1.0.10

agent:
  enabled: true
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: 1
      memory: 2Gi

persistence:
  enabled: true
  size: 20Gi

serviceAccount:
  create: true
  name: jenkins
EOF

    # Install Jenkins
    helm upgrade --install jenkins jenkins/jenkins \
        --namespace $NAMESPACE_JENKINS \
        --values jenkins-values.yaml \
        --wait --timeout 600s
    
    rm jenkins-values.yaml
    
    print_status "Jenkins installed successfully!"
    print_status "Getting Jenkins admin password..."
    kubectl get secret --namespace $NAMESPACE_JENKINS jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode; echo
}

# Function to install observability stack
install_observability() {
    print_status "Installing observability stack..."
    
    # Install Prometheus
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace $NAMESPACE_MONITORING \
        --create-namespace \
        --set grafana.adminPassword=admin123 \
        --set prometheus.prometheusSpec.retention=30d \
        --wait --timeout 600s
    
    # Install Jaeger
    kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.49.0/jaeger-operator.yaml -n observability
    
    # Wait for Jaeger operator
    kubectl wait --for=condition=available --timeout=300s deployment/jaeger-operator -n observability
    
    # Deploy Jaeger instance
    cat <<EOF | kubectl apply -f -
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger-all-in-one
  namespace: $NAMESPACE_MONITORING
spec:
  strategy: allInOne
  allInOne:
    image: jaegertracing/all-in-one:1.49
    options:
      memory:
        max-traces: 100000
  ui:
    options:
      dependencies:
        menuEnabled: true
  storage:
    type: memory
    options:
      memory:
        max-traces: 100000
EOF
    
    print_status "Observability stack installed successfully!"
}

# Function to install logging stack
install_logging() {
    print_status "Installing EFK logging stack..."
    
    # Install Elasticsearch
    helm repo add elastic https://helm.elastic.co
    helm repo update
    
    # Elasticsearch
    helm upgrade --install elasticsearch elastic/elasticsearch \
        --namespace $NAMESPACE_LOGGING \
        --create-namespace \
        --set replicas=1 \
        --set minimumMasterNodes=1 \
        --set resources.requests.memory=1Gi \
        --set resources.limits.memory=2Gi \
        --wait --timeout 600s
    
    # Kibana
    helm upgrade --install kibana elastic/kibana \
        --namespace $NAMESPACE_LOGGING \
        --set service.type=LoadBalancer \
        --wait --timeout 600s
    
    # Fluent Bit
    helm repo add fluent https://fluent.github.io/helm-charts
    helm upgrade --install fluent-bit fluent/fluent-bit \
        --namespace $NAMESPACE_LOGGING \
        --set config.outputs="[OUTPUT]\n    Name es\n    Match *\n    Host elasticsearch-master\n    Port 9200\n    Index fluent-bit\n    Type _doc" \
        --wait --timeout 300s
    
    print_status "EFK logging stack installed successfully!"
}

# Function to install security tools
install_security() {
    print_status "Installing security tools..."
    
    # Install HashiCorp Vault
    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm repo update
    
    helm upgrade --install vault hashicorp/vault \
        --namespace $NAMESPACE_SECURITY \
        --create-namespace \
        --set server.dev.enabled=true \
        --set server.dev.devRootToken="root" \
        --wait --timeout 300s
    
    # Install Trivy Operator
    kubectl apply -f https://raw.githubusercontent.com/aquasecurity/trivy-operator/v0.16.4/deploy/static/trivy-operator.yaml
    
    print_status "Security tools installed successfully!"
}

# Function to configure monitoring dashboards
configure_monitoring() {
    print_status "Configuring monitoring dashboards..."
    
    # Wait for Grafana to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus-grafana -n $NAMESPACE_MONITORING
    
    # Apply ML-specific dashboard
    kubectl apply -f monitoring/grafana/ml-performance-dashboard.json
    
    print_status "Monitoring dashboards configured successfully!"
}

# Function to create sample ML pipeline
create_sample_pipeline() {
    print_status "Creating sample ML pipeline..."
    
    # Apply pipeline configurations
    kubectl apply -f pipelines/ml-pipeline-config.yaml
    
    # Create Jenkins job
    if command -v jenkins-cli.jar >/dev/null 2>&1; then
        java -jar jenkins-cli.jar -s http://jenkins.jenkins.svc.cluster.local:8080 -auth admin:admin123 create-job sample-ml-pipeline < pipelines/sample-job.xml
    fi
    
    print_status "Sample ML pipeline created successfully!"
}

# Function to validate installation
validate_installation() {
    print_status "Validating installation..."
    
    # Check all pods are running
    print_status "Checking Jenkins pods..."
    kubectl get pods -n $NAMESPACE_JENKINS
    
    print_status "Checking monitoring pods..."
    kubectl get pods -n $NAMESPACE_MONITORING
    
    print_status "Checking logging pods..."
    kubectl get pods -n $NAMESPACE_LOGGING
    
    print_status "Checking security pods..."
    kubectl get pods -n $NAMESPACE_SECURITY
    
    # Check services
    print_status "Checking services..."
    kubectl get svc -A | grep -E "(jenkins|grafana|kibana|vault)"
    
    print_status "Installation validation completed!"
}

# Function to display access information
display_access_info() {
    print_status "Installation completed successfully! 🎉"
    echo ""
    echo "========================================================================================"
    echo "                              ACCESS INFORMATION"
    echo "========================================================================================"
    echo ""
    
    # Jenkins
    JENKINS_IP=$(kubectl get svc jenkins -n $NAMESPACE_JENKINS -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "localhost")
    JENKINS_PORT=$(kubectl get svc jenkins -n $NAMESPACE_JENKINS -o jsonpath='{.spec.ports[0].port}')
    echo "🚀 Jenkins:"
    echo "   URL: http://$JENKINS_IP:$JENKINS_PORT"
    echo "   Username: admin"
    echo "   Password: admin123"
    echo ""
    
    # Grafana
    GRAFANA_IP=$(kubectl get svc prometheus-grafana -n $NAMESPACE_MONITORING -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "localhost")
    GRAFANA_PORT=$(kubectl get svc prometheus-grafana -n $NAMESPACE_MONITORING -o jsonpath='{.spec.ports[0].port}')
    echo "📊 Grafana:"
    echo "   URL: http://$GRAFANA_IP:$GRAFANA_PORT"
    echo "   Username: admin"
    echo "   Password: admin123"
    echo ""
    
    # Kibana
    KIBANA_IP=$(kubectl get svc kibana-kibana -n $NAMESPACE_LOGGING -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "localhost")
    KIBANA_PORT=$(kubectl get svc kibana-kibana -n $NAMESPACE_LOGGING -o jsonpath='{.spec.ports[0].port}')
    echo "📝 Kibana:"
    echo "   URL: http://$KIBANA_IP:$KIBANA_PORT"
    echo ""
    
    # Vault
    VAULT_IP=$(kubectl get svc vault -n $NAMESPACE_SECURITY -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "localhost")
    VAULT_PORT=$(kubectl get svc vault -n $NAMESPACE_SECURITY -o jsonpath='{.spec.ports[0].port}')
    echo "🔒 Vault:"
    echo "   URL: http://$VAULT_IP:$VAULT_PORT"
    echo "   Root Token: root"
    echo ""
    
    echo "========================================================================================"
    echo ""
    echo "📚 Next Steps:"
    echo "   1. Access Jenkins and create your first ML pipeline"
    echo "   2. Check Grafana dashboards for system metrics"
    echo "   3. View logs in Kibana"
    echo "   4. Configure secrets in Vault"
    echo ""
    echo "📖 Documentation: https://github.com/nguie2/jenkins-ml-pipeline/docs"
    echo "🆘 Support: nguierochjunior@gmail.com"
    echo ""
    echo "Happy MLOps! 🤖"
}

# Function to cleanup on failure
cleanup_on_failure() {
    print_error "Installation failed. Cleaning up..."
    
    # Remove Helm releases
    helm uninstall jenkins -n $NAMESPACE_JENKINS 2>/dev/null || true
    helm uninstall prometheus -n $NAMESPACE_MONITORING 2>/dev/null || true
    helm uninstall elasticsearch -n $NAMESPACE_LOGGING 2>/dev/null || true
    helm uninstall kibana -n $NAMESPACE_LOGGING 2>/dev/null || true
    helm uninstall vault -n $NAMESPACE_SECURITY 2>/dev/null || true
    
    # Remove namespaces
    kubectl delete namespace $NAMESPACE_JENKINS 2>/dev/null || true
    kubectl delete namespace $NAMESPACE_MONITORING 2>/dev/null || true
    kubectl delete namespace $NAMESPACE_LOGGING 2>/dev/null || true
    kubectl delete namespace $NAMESPACE_SECURITY 2>/dev/null || true
    
    # Remove cluster if created
    if [ "$SKIP_CLUSTER_CREATION" = false ]; then
        if command -v kind >/dev/null 2>&1; then
            kind delete cluster --name $CLUSTER_NAME 2>/dev/null || true
        elif command -v minikube >/dev/null 2>&1; then
            minikube delete --profile $CLUSTER_NAME 2>/dev/null || true
        fi
    fi
    
    print_error "Cleanup completed"
}

# Main execution function
main() {
    # Set trap for cleanup on failure
    trap cleanup_on_failure ERR
    
    print_header
    
    # Parse arguments
    parse_arguments "$@"
    
    print_status "Starting Jenkins ML Pipeline setup..."
    print_status "Environment: $ENVIRONMENT"
    print_status "Cluster: $CLUSTER_NAME"
    print_status "GPU Support: $ENABLE_GPU"
    
    # Execute setup steps
    check_prerequisites
    create_cluster
    create_namespaces
    deploy_infrastructure
    install_jenkins
    install_observability
    install_logging
    install_security
    configure_monitoring
    create_sample_pipeline
    validate_installation
    display_access_info
    
    print_status "Setup completed successfully! 🎉"
}

# Run main function with all arguments
main "$@" 