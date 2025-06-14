#!/bin/bash

# Multi-Cloud Jenkins ML Pipeline Setup Script
# Author: Nguie Angoue Jean Roch Junior
# Email: nguierochjunior@gmail.com
# Description: Deploy Jenkins ML Pipeline to AWS EKS, Azure AKS, or Google GKE

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="jenkins-ml-pipeline"
ENVIRONMENT="development"
ENABLE_GPU=false
CLOUD_PROVIDER=""

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
███╗   ███╗██╗   ██╗██╗  ████████╗██╗      ██████╗██╗      ██████╗ ██╗   ██╗██████╗ 
████╗ ████║██║   ██║██║  ╚══██╔══╝██║     ██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗
██╔████╔██║██║   ██║██║     ██║   ██║     ██║     ██║     ██║   ██║██║   ██║██║  ██║
██║╚██╔╝██║██║   ██║██║     ██║   ██║     ██║     ██║     ██║   ██║██║   ██║██║  ██║
██║ ╚═╝ ██║╚██████╔╝███████╗██║   ██║     ╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝
╚═╝     ╚═╝ ╚═════╝ ╚══════╝╚═╝   ╚═╝      ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝ 
                                                                                      
Multi-Cloud Jenkins ML Pipeline Setup
${NC}"
}

# Function to show help
show_help() {
    echo "Usage: $0 --cloud PROVIDER [OPTIONS]"
    echo ""
    echo "Required:"
    echo "  --cloud PROVIDER         Cloud provider (aws|azure|gcp)"
    echo ""
    echo "Options:"
    echo "  --cluster-name NAME      Set cluster name [default: jenkins-ml-pipeline]"
    echo "  --environment ENV        Set environment (development|staging|production) [default: development]"
    echo "  --enable-gpu            Enable GPU support for ML workloads"
    echo "  --help                  Show this help message"
    echo ""
    echo "AWS specific options:"
    echo "  --aws-region REGION     AWS region [default: us-west-2]"
    echo "  --aws-profile PROFILE   AWS CLI profile [default: default]"
    echo ""
    echo "Azure specific options:"
    echo "  --azure-location LOC    Azure location [default: West US 2]"
    echo "  --azure-subscription ID Azure subscription ID"
    echo ""
    echo "GCP specific options:"
    echo "  --gcp-project PROJECT   GCP project ID (required for GCP)"
    echo "  --gcp-region REGION     GCP region [default: us-central1]"
    echo ""
    echo "Examples:"
    echo "  $0 --cloud aws --aws-region us-east-1 --enable-gpu"
    echo "  $0 --cloud azure --azure-location 'East US' --environment production"
    echo "  $0 --cloud gcp --gcp-project my-project-123 --gcp-region europe-west1"
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cloud)
                CLOUD_PROVIDER="$2"
                shift 2
                ;;
            --cluster-name)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --enable-gpu)
                ENABLE_GPU=true
                shift
                ;;
            --aws-region)
                AWS_REGION="$2"
                shift 2
                ;;
            --aws-profile)
                AWS_PROFILE="$2"
                shift 2
                ;;
            --azure-location)
                AZURE_LOCATION="$2"
                shift 2
                ;;
            --azure-subscription)
                AZURE_SUBSCRIPTION="$2"
                shift 2
                ;;
            --gcp-project)
                GCP_PROJECT="$2"
                shift 2
                ;;
            --gcp-region)
                GCP_REGION="$2"
                shift 2
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
    
    # Validate required parameters
    if [[ -z "$CLOUD_PROVIDER" ]]; then
        print_error "Cloud provider is required. Use --cloud aws|azure|gcp"
        show_help
        exit 1
    fi
    
    if [[ "$CLOUD_PROVIDER" != "aws" && "$CLOUD_PROVIDER" != "azure" && "$CLOUD_PROVIDER" != "gcp" ]]; then
        print_error "Invalid cloud provider. Must be aws, azure, or gcp"
        exit 1
    fi
    
    # Set defaults
    AWS_REGION=${AWS_REGION:-"us-west-2"}
    AWS_PROFILE=${AWS_PROFILE:-"default"}
    AZURE_LOCATION=${AZURE_LOCATION:-"West US 2"}
    GCP_REGION=${GCP_REGION:-"us-central1"}
    
    # Validate GCP project
    if [[ "$CLOUD_PROVIDER" == "gcp" && -z "${GCP_PROJECT:-}" ]]; then
        print_error "GCP project ID is required when using GCP. Use --gcp-project PROJECT_ID"
        exit 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites for $CLOUD_PROVIDER..."
    
    # Common tools
    local tools=("terraform" "kubectl" "helm")
    
    # Cloud-specific tools
    case $CLOUD_PROVIDER in
        aws)
            tools+=("aws")
            ;;
        azure)
            tools+=("az")
            ;;
        gcp)
            tools+=("gcloud")
            ;;
    esac
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            print_error "$tool is not installed or not in PATH"
            print_status "Please install $tool and try again"
            exit 1
        fi
    done
    
    print_status "All prerequisites are installed"
}

# Function to authenticate with cloud provider
authenticate_cloud() {
    print_status "Authenticating with $CLOUD_PROVIDER..."
    
    case $CLOUD_PROVIDER in
        aws)
            export AWS_PROFILE="$AWS_PROFILE"
            if ! aws sts get-caller-identity &> /dev/null; then
                print_error "AWS authentication failed. Please run 'aws configure' or set up your credentials"
                exit 1
            fi
            print_status "AWS authentication successful"
            ;;
        azure)
            if [[ -n "${AZURE_SUBSCRIPTION:-}" ]]; then
                az account set --subscription "$AZURE_SUBSCRIPTION"
            fi
            if ! az account show &> /dev/null; then
                print_error "Azure authentication failed. Please run 'az login'"
                exit 1
            fi
            print_status "Azure authentication successful"
            ;;
        gcp)
            if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 &> /dev/null; then
                print_error "GCP authentication failed. Please run 'gcloud auth login'"
                exit 1
            fi
            gcloud config set project "$GCP_PROJECT"
            print_status "GCP authentication successful"
            ;;
    esac
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure to $CLOUD_PROVIDER..."
    
    local terraform_dir="terraform/$CLOUD_PROVIDER"
    
    if [[ ! -d "$terraform_dir" ]]; then
        print_error "Terraform configuration not found for $CLOUD_PROVIDER"
        exit 1
    fi
    
    cd "$terraform_dir"
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Create terraform.tfvars file
    create_terraform_vars
    
    # Plan deployment
    print_status "Planning infrastructure deployment..."
    terraform plan -var-file="terraform.tfvars"
    
    # Apply deployment
    print_status "Applying infrastructure deployment..."
    terraform apply -auto-approve -var-file="terraform.tfvars"
    
    # Get outputs
    get_terraform_outputs
    
    cd ../..
}

# Function to create terraform.tfvars file
create_terraform_vars() {
    print_status "Creating Terraform variables file..."
    
    cat > terraform.tfvars <<EOF
cluster_name = "$CLUSTER_NAME"
environment = "$ENVIRONMENT"
enable_gpu = $ENABLE_GPU
EOF

    case $CLOUD_PROVIDER in
        aws)
            cat >> terraform.tfvars <<EOF
region = "$AWS_REGION"
EOF
            ;;
        azure)
            cat >> terraform.tfvars <<EOF
location = "$AZURE_LOCATION"
EOF
            ;;
        gcp)
            cat >> terraform.tfvars <<EOF
project_id = "$GCP_PROJECT"
region = "$GCP_REGION"
EOF
            ;;
    esac
    
    print_status "Terraform variables file created"
}

# Function to get Terraform outputs
get_terraform_outputs() {
    print_status "Getting cluster information..."
    
    case $CLOUD_PROVIDER in
        aws)
            CLUSTER_ENDPOINT=$(terraform output -raw cluster_endpoint)
            KUBECTL_CONFIG_CMD=$(terraform output -raw kubectl_config)
            ;;
        azure)
            CLUSTER_ENDPOINT=$(terraform output -raw cluster_endpoint)
            KUBECTL_CONFIG_CMD=$(terraform output -raw kubectl_config)
            ;;
        gcp)
            CLUSTER_ENDPOINT=$(terraform output -raw cluster_endpoint)
            KUBECTL_CONFIG_CMD=$(terraform output -raw kubectl_config)
            ;;
    esac
    
    print_status "Cluster endpoint: $CLUSTER_ENDPOINT"
}

# Function to configure kubectl
configure_kubectl() {
    print_status "Configuring kubectl..."
    
    eval "$KUBECTL_CONFIG_CMD"
    
    # Verify connection
    if kubectl cluster-info &> /dev/null; then
        print_status "kubectl configured successfully"
    else
        print_error "Failed to configure kubectl"
        exit 1
    fi
}

# Function to deploy Jenkins ML Pipeline
deploy_jenkins_pipeline() {
    print_status "Deploying Jenkins ML Pipeline..."
    
    # Deploy core infrastructure
    deploy_core_infrastructure
    
    # Deploy Jenkins
    deploy_jenkins
    
    # Deploy monitoring stack
    deploy_monitoring
    
    # Deploy security components
    deploy_security
    
    # Validate deployment
    validate_deployment
}

# Function to deploy core infrastructure
deploy_core_infrastructure() {
    print_status "Deploying core Kubernetes infrastructure..."
    
    cd terraform/kubernetes
    terraform init
    terraform apply -auto-approve \
        -var="cluster_name=$CLUSTER_NAME" \
        -var="environment=$ENVIRONMENT" \
        -var="enable_gpu=$ENABLE_GPU"
    cd ../..
}

# Function to deploy Jenkins
deploy_jenkins() {
    print_status "Deploying Jenkins..."
    
    cd terraform/jenkins
    terraform init
    terraform apply -auto-approve \
        -var="cluster_name=$CLUSTER_NAME" \
        -var="environment=$ENVIRONMENT" \
        -var="enable_gpu=$ENABLE_GPU"
    cd ../..
}

# Function to deploy monitoring stack
deploy_monitoring() {
    print_status "Deploying monitoring stack..."
    
    cd terraform/monitoring
    terraform init
    terraform apply -auto-approve
    cd ../..
}

# Function to deploy security components
deploy_security() {
    print_status "Deploying security components..."
    
    cd terraform/security
    terraform init
    terraform apply -auto-approve
    cd ../..
}

# Function to validate deployment
validate_deployment() {
    print_status "Validating deployment..."
    
    if [[ -f "scripts/validate-deployment.sh" ]]; then
        ./scripts/validate-deployment.sh
    else
        print_warning "Validation script not found, skipping validation"
    fi
}

# Function to display access information
display_access_info() {
    print_status "Deployment completed successfully! 🎉"
    echo
    echo -e "${PURPLE}=== ACCESS INFORMATION ===${NC}"
    echo
    echo "Cloud Provider: $CLOUD_PROVIDER"
    echo "Cluster Name: $CLUSTER_NAME"
    echo "Environment: $ENVIRONMENT"
    echo "GPU Enabled: $ENABLE_GPU"
    echo
    echo -e "${BLUE}Cluster Endpoint:${NC} $CLUSTER_ENDPOINT"
    echo
    echo -e "${BLUE}To access services, use kubectl port-forward:${NC}"
    echo
    echo "Jenkins:"
    echo "  kubectl port-forward -n jenkins svc/jenkins 8080:8080"
    echo "  Access: http://localhost:8080 (admin/admin123)"
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
    echo "Vault:"
    echo "  kubectl port-forward -n security svc/vault 8200:8200"
    echo "  Access: http://localhost:8200"
    echo
    
    case $CLOUD_PROVIDER in
        aws)
            echo -e "${BLUE}AWS-specific resources:${NC}"
            echo "  S3 Buckets: Check AWS Console for ML data and models buckets"
            echo "  ECR Repository: $(cd terraform/aws && terraform output -raw ecr_repository_url)"
            ;;
        azure)
            echo -e "${BLUE}Azure-specific resources:${NC}"
            echo "  Storage Account: $(cd terraform/azure && terraform output -raw storage_account_name)"
            echo "  Container Registry: $(cd terraform/azure && terraform output -raw acr_login_server)"
            echo "  Key Vault: $(cd terraform/azure && terraform output -raw key_vault_uri)"
            ;;
        gcp)
            echo -e "${BLUE}GCP-specific resources:${NC}"
            echo "  Storage Buckets: $(cd terraform/gcp && terraform output -raw ml_data_bucket), $(cd terraform/gcp && terraform output -raw ml_models_bucket)"
            echo "  Artifact Registry: $(cd terraform/gcp && terraform output -raw artifact_registry_url)"
            ;;
    esac
    
    echo
    echo -e "${GREEN}Next steps:${NC}"
    echo "1. Access Jenkins and configure your first ML pipeline"
    echo "2. Upload your ML models and datasets to cloud storage"
    echo "3. Configure monitoring dashboards in Grafana"
    echo "4. Set up alerts and notifications"
    echo
    echo -e "${YELLOW}Documentation:${NC} See README.md for detailed usage instructions"
}

# Function to cleanup on failure
cleanup_on_failure() {
    print_error "Setup failed. Cleaning up resources..."
    
    # Add cleanup logic here if needed
    # For now, we'll just show the error
    print_error "Please check the logs above for error details"
    print_status "You may need to manually clean up any partially created resources"
}

# Main function
main() {
    # Set trap for cleanup on failure
    trap cleanup_on_failure ERR
    
    print_header
    
    # Parse arguments
    parse_arguments "$@"
    
    print_status "Starting multi-cloud Jenkins ML Pipeline setup..."
    print_status "Cloud Provider: $CLOUD_PROVIDER"
    print_status "Cluster Name: $CLUSTER_NAME"
    print_status "Environment: $ENVIRONMENT"
    print_status "GPU Support: $ENABLE_GPU"
    
    # Execute setup steps
    check_prerequisites
    authenticate_cloud
    deploy_infrastructure
    configure_kubectl
    deploy_jenkins_pipeline
    display_access_info
    
    print_status "Multi-cloud setup completed successfully! 🚀"
}

# Run main function with all arguments
main "$@" 