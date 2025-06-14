# Multi-Cloud Deployment Guide

**Author**: Nguie Angoue Jean Roch Junior  
**Email**: nguierochjunior@gmail.com

This guide provides comprehensive instructions for deploying the Jenkins ML Pipeline across AWS, Azure, and Google Cloud Platform.

## 🌐 **Overview**

Our Jenkins ML Pipeline supports deployment across all major cloud providers with native integration of their managed services:

- **AWS EKS** - Elastic Kubernetes Service with S3, ECR, and IAM
- **Azure AKS** - Azure Kubernetes Service with Blob Storage, ACR, and Key Vault
- **Google GKE** - Google Kubernetes Engine with Cloud Storage, Artifact Registry, and Secret Manager

## 🏗️ **Architecture Comparison**

| Component | AWS | Azure | GCP |
|-----------|-----|-------|-----|
| **Kubernetes** | EKS | AKS | GKE |
| **Container Registry** | ECR | ACR | Artifact Registry |
| **Object Storage** | S3 | Blob Storage | Cloud Storage |
| **Secrets Management** | AWS Secrets Manager | Key Vault | Secret Manager |
| **Monitoring** | CloudWatch | Azure Monitor | Cloud Monitoring |
| **Load Balancer** | ALB/NLB | Azure Load Balancer | Cloud Load Balancing |
| **DNS** | Route 53 | Azure DNS | Cloud DNS |
| **Identity** | IAM | Azure AD | Cloud IAM |

## 🚀 **Quick Start**

### **One-Command Deployment**

```bash
# AWS deployment
./scripts/multi-cloud-setup.sh --cloud aws --aws-region us-west-2 --enable-gpu

# Azure deployment  
./scripts/multi-cloud-setup.sh --cloud azure --azure-location "West US 2" --environment production

# GCP deployment
./scripts/multi-cloud-setup.sh --cloud gcp --gcp-project my-project-123 --gcp-region us-central1
```

## 📋 **Prerequisites by Cloud Provider**

### **AWS Prerequisites**

```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region, Output format

# Verify authentication
aws sts get-caller-identity
```

**Required AWS Permissions:**
- EC2 full access
- EKS full access
- IAM full access
- S3 full access
- ECR full access
- VPC full access

### **Azure Prerequisites**

```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login to Azure
az login

# Set subscription (if multiple)
az account set --subscription "your-subscription-id"

# Verify authentication
az account show
```

**Required Azure Permissions:**
- Contributor role on subscription
- User Access Administrator (for RBAC)

### **GCP Prerequisites**

```bash
# Install Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Initialize and authenticate
gcloud init
gcloud auth login

# Set project
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable storage.googleapis.com
```

**Required GCP Permissions:**
- Project Editor role
- Kubernetes Engine Admin
- Compute Admin
- Storage Admin

## 🔧 **Detailed Deployment Instructions**

### **AWS EKS Deployment**

#### **1. Infrastructure Setup**

```bash
cd terraform/aws

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
project_id = "your-aws-account-id"
cluster_name = "jenkins-ml-pipeline"
region = "us-west-2"
environment = "production"
enable_gpu = true
node_instance_types = ["t3.large", "t3.xlarge"]
gpu_instance_types = ["p3.2xlarge"]
min_nodes = 2
max_nodes = 10
desired_nodes = 3
EOF

# Deploy infrastructure
terraform init
terraform plan
terraform apply
```

#### **2. Configure kubectl**

```bash
aws eks update-kubeconfig --region us-west-2 --name jenkins-ml-pipeline
kubectl cluster-info
```

#### **3. AWS-Specific Features**

- **S3 Integration**: Automatic buckets for ML data and models
- **ECR Integration**: Private container registry
- **IAM Roles**: Workload-specific permissions
- **EBS CSI**: Persistent storage for Jenkins
- **ALB Ingress**: Application Load Balancer integration

### **Azure AKS Deployment**

#### **1. Infrastructure Setup**

```bash
cd terraform/azure

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
cluster_name = "jenkins-ml-pipeline"
location = "West US 2"
environment = "production"
enable_gpu = true
node_vm_size = "Standard_D4s_v3"
gpu_vm_size = "Standard_NC6s_v3"
min_nodes = 2
max_nodes = 10
initial_nodes = 3
EOF

# Deploy infrastructure
terraform init
terraform plan
terraform apply
```

#### **2. Configure kubectl**

```bash
az aks get-credentials --resource-group jenkins-ml-pipeline-rg --name jenkins-ml-pipeline
kubectl cluster-info
```

#### **3. Azure-Specific Features**

- **Azure Blob Storage**: Scalable object storage
- **Azure Container Registry**: Managed container registry
- **Azure Key Vault**: Secrets and certificate management
- **Azure Monitor**: Integrated monitoring and logging
- **Azure Policy**: Governance and compliance

### **GCP GKE Deployment**

#### **1. Infrastructure Setup**

```bash
cd terraform/gcp

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
project_id = "your-gcp-project-id"
cluster_name = "jenkins-ml-pipeline"
region = "us-central1"
environment = "production"
enable_gpu = true
node_machine_type = "e2-standard-4"
gpu_machine_type = "n1-standard-4"
gpu_type = "nvidia-tesla-t4"
min_nodes = 1
max_nodes = 3
initial_nodes = 1
EOF

# Deploy infrastructure
terraform init
terraform plan
terraform apply
```

#### **2. Configure kubectl**

```bash
gcloud container clusters get-credentials jenkins-ml-pipeline --region us-central1 --project your-project-id
kubectl cluster-info
```

#### **3. GCP-Specific Features**

- **Cloud Storage**: Multi-regional object storage
- **Artifact Registry**: Next-generation container registry
- **Secret Manager**: Centralized secret management
- **Cloud Monitoring**: Comprehensive observability
- **Workload Identity**: Secure pod-to-GCP service authentication

## 🔒 **Security Considerations**

### **Network Security**

| Feature | AWS | Azure | GCP |
|---------|-----|-------|-----|
| **Private Clusters** | ✅ EKS Private Endpoint | ✅ AKS Private Cluster | ✅ GKE Private Cluster |
| **Network Policies** | ✅ Calico/Cilium | ✅ Azure Network Policy | ✅ Network Policy |
| **Firewall Rules** | ✅ Security Groups | ✅ NSG | ✅ VPC Firewall |
| **VPN/Peering** | ✅ VPC Peering | ✅ VNet Peering | ✅ VPC Peering |

### **Identity and Access**

| Feature | AWS | Azure | GCP |
|---------|-----|-------|-----|
| **Pod Identity** | ✅ IRSA | ✅ Pod Identity | ✅ Workload Identity |
| **RBAC** | ✅ Kubernetes RBAC | ✅ Azure RBAC | ✅ Cloud IAM |
| **Secrets** | ✅ AWS Secrets Manager | ✅ Key Vault | ✅ Secret Manager |
| **Encryption** | ✅ KMS | ✅ Key Vault | ✅ Cloud KMS |

## 📊 **Cost Optimization**

### **AWS Cost Optimization**

```bash
# Use Spot Instances for non-critical workloads
node_instance_types = ["t3.large", "t3.xlarge"]
spot_instances = true

# Enable cluster autoscaler
min_nodes = 1
max_nodes = 10

# Use GP3 storage for cost savings
storage_type = "gp3"
```

### **Azure Cost Optimization**

```bash
# Use B-series VMs for development
node_vm_size = "Standard_B4ms"

# Enable auto-scaling
enable_auto_scaling = true
min_count = 1
max_count = 5

# Use Standard storage tier
storage_tier = "Standard_LRS"
```

### **GCP Cost Optimization**

```bash
# Use preemptible instances
preemptible = true

# Enable node auto-provisioning
enable_autoscaling = true
min_node_count = 0
max_node_count = 3

# Use regional persistent disks
disk_type = "pd-standard"
```

## 🔄 **Multi-Cloud Strategies**

### **1. Multi-Cloud Deployment**

Deploy the same pipeline across multiple clouds for redundancy:

```bash
# Deploy to AWS
./scripts/multi-cloud-setup.sh --cloud aws --cluster-name ml-pipeline-aws

# Deploy to Azure  
./scripts/multi-cloud-setup.sh --cloud azure --cluster-name ml-pipeline-azure

# Deploy to GCP
./scripts/multi-cloud-setup.sh --cloud gcp --cluster-name ml-pipeline-gcp --gcp-project project-id
```

### **2. Hybrid Cloud Setup**

Use different clouds for different purposes:

- **AWS**: Production ML training (GPU instances)
- **Azure**: Development and testing (cost-effective)
- **GCP**: Data analytics and BigQuery integration

### **3. Cloud Migration**

Migrate between clouds using our standardized approach:

```bash
# Export from source cloud
kubectl get all --all-namespaces -o yaml > backup.yaml

# Deploy to target cloud
./scripts/multi-cloud-setup.sh --cloud target-cloud

# Import to target cloud
kubectl apply -f backup.yaml
```

## 📈 **Monitoring and Observability**

### **Cloud-Native Monitoring Integration**

Each cloud deployment automatically integrates with native monitoring:

| Metric Type | AWS | Azure | GCP |
|-------------|-----|-------|-----|
| **Cluster Metrics** | CloudWatch Container Insights | Azure Monitor | Cloud Monitoring |
| **Application Logs** | CloudWatch Logs | Log Analytics | Cloud Logging |
| **Custom Metrics** | CloudWatch Custom | Application Insights | Cloud Monitoring |
| **Alerting** | CloudWatch Alarms | Azure Alerts | Cloud Alerting |

### **Unified Monitoring Dashboard**

Access monitoring across all clouds:

```bash
# Port-forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access at http://localhost:3000
# Username: admin
# Password: admin123
```

## 🚨 **Troubleshooting**

### **Common Issues**

#### **AWS Issues**

```bash
# EKS cluster not accessible
aws eks update-kubeconfig --region us-west-2 --name jenkins-ml-pipeline

# IAM permissions issues
aws sts get-caller-identity
aws iam list-attached-role-policies --role-name eksServiceRole
```

#### **Azure Issues**

```bash
# AKS cluster not accessible
az aks get-credentials --resource-group jenkins-ml-pipeline-rg --name jenkins-ml-pipeline --overwrite-existing

# Resource provider not registered
az provider register --namespace Microsoft.ContainerService
```

#### **GCP Issues**

```bash
# GKE cluster not accessible
gcloud container clusters get-credentials jenkins-ml-pipeline --region us-central1

# API not enabled
gcloud services enable container.googleapis.com
```

### **Validation Commands**

```bash
# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Check cloud-specific resources
# AWS
aws eks describe-cluster --name jenkins-ml-pipeline
aws s3 ls

# Azure
az aks show --resource-group jenkins-ml-pipeline-rg --name jenkins-ml-pipeline
az storage account list

# GCP
gcloud container clusters describe jenkins-ml-pipeline --region us-central1
gsutil ls
```

## 🔧 **Advanced Configuration**

### **Custom Networking**

#### **AWS VPC Configuration**

```hcl
# terraform/aws/vpc.tf
resource "aws_vpc" "custom" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}
```

#### **Azure VNet Configuration**

```hcl
# terraform/azure/vnet.tf
resource "azurerm_virtual_network" "custom" {
  name                = "custom-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
}
```

#### **GCP VPC Configuration**

```hcl
# terraform/gcp/vpc.tf
resource "google_compute_network" "custom" {
  name                    = "custom-vpc"
  auto_create_subnetworks = false
}
```

### **GPU Configuration**

Each cloud provider has specific GPU setup requirements:

#### **AWS GPU Setup**

```yaml
# GPU node group with NVIDIA drivers
apiVersion: v1
kind: ConfigMap
metadata:
  name: nvidia-device-plugin-daemonset
data:
  config.yaml: |
    version: v1
    flags:
      migStrategy: none
      failOnInitError: true
      nvidiaDriverRoot: /home/kubernetes/bin/nvidia
```

#### **Azure GPU Setup**

```bash
# Install NVIDIA device plugin
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.1/nvidia-device-plugin.yml
```

#### **GCP GPU Setup**

```bash
# GKE automatically installs GPU drivers
# Just need to specify GPU type in node pool
```

## 📚 **Best Practices**

### **1. Resource Naming**

Use consistent naming across clouds:

```bash
# Format: {project}-{environment}-{cloud}-{resource}
jenkins-ml-pipeline-prod-aws-cluster
jenkins-ml-pipeline-prod-azure-rg
jenkins-ml-pipeline-prod-gcp-project
```

### **2. Tagging Strategy**

Apply consistent tags/labels:

```hcl
locals {
  common_tags = {
    Project     = "jenkins-ml-pipeline"
    Environment = var.environment
    ManagedBy   = "terraform"
    Cloud       = "aws" # or "azure" or "gcp"
    Owner       = "nguie-angoue-jean-roch-junior"
  }
}
```

### **3. Security Hardening**

- Enable encryption at rest and in transit
- Use private clusters where possible
- Implement network policies
- Regular security scanning
- Principle of least privilege

### **4. Backup and Disaster Recovery**

```bash
# Regular backups
kubectl get all --all-namespaces -o yaml > backup-$(date +%Y%m%d).yaml

# Cross-cloud replication
gsutil rsync -r gs://source-bucket gs://destination-bucket
aws s3 sync s3://source-bucket s3://destination-bucket
az storage blob sync --source-container source --destination-container dest
```

## 🎯 **Next Steps**

1. **Choose your cloud provider** based on requirements
2. **Run the deployment script** with appropriate parameters
3. **Configure monitoring** and alerting
4. **Set up CI/CD pipelines** for your ML models
5. **Implement backup strategies**
6. **Scale based on usage patterns**

## 📞 **Support**

For cloud-specific issues or advanced configurations:

- **Email**: nguierochjunior@gmail.com
- **LinkedIn**: [Nguie Angoue J](https://www.linkedin.com/in/nguie-angoue-j-2b2880254/)
- **GitHub**: [@nguie2](https://github.com/nguie2)

---

**Built with ❤️ for multi-cloud MLOps**  
*Empowering teams to deploy ML models anywhere* 