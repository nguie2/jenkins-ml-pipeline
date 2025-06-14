# Kubernetes Cluster Infrastructure
# Author: Nguie Angoue Jean Roch Junior
# Email: nguierochjunior@gmail.com

terraform {
  required_version = ">= 1.5"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

# Variables
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "jenkins-ml-pipeline"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "enable_gpu" {
  description = "Enable GPU support"
  type        = bool
  default     = false
}

# Configure providers
provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# Create namespaces
resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins"
    labels = {
      app         = "jenkins-ml-pipeline"
      environment = var.environment
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      app         = "jenkins-ml-pipeline"
      environment = var.environment
    }
  }
}

resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
    labels = {
      app         = "jenkins-ml-pipeline"
      environment = var.environment
    }
  }
}

resource "kubernetes_namespace" "security" {
  metadata {
    name = "security"
    labels = {
      app         = "jenkins-ml-pipeline"
      environment = var.environment
    }
  }
}

# Output the cluster info
output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = var.cluster_name
}

output "namespaces" {
  description = "Created namespaces"
  value = {
    jenkins    = kubernetes_namespace.jenkins.metadata[0].name
    monitoring = kubernetes_namespace.monitoring.metadata[0].name
    logging    = kubernetes_namespace.logging.metadata[0].name
    security   = kubernetes_namespace.security.metadata[0].name
  }
} 