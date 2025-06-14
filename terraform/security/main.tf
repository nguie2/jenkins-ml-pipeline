# Security Infrastructure
# Author: Nguie Angoue Jean Roch Junior
# Email: nguierochjunior@gmail.com

terraform {
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

# HashiCorp Vault
resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  namespace  = "security"
  version    = "0.25.0"

  values = [
    yamlencode({
      server = {
        dev = {
          enabled = true
          devRootToken = "root"
        }
        
        standalone = {
          enabled = false
        }
        
        ha = {
          enabled = true
          replicas = 3
          
          config = <<-EOF
            ui = true
            
            listener "tcp" {
              tls_disable = 1
              address = "[::]:8200"
              cluster_address = "[::]:8201"
            }
            
            storage "consul" {
              path = "vault"
              address = "HOST_IP:8500"
            }
            
            service_registration "kubernetes" {}
          EOF
        }
        
        resources = {
          requests = {
            memory = "256Mi"
            cpu    = "250m"
          }
          limits = {
            memory = "512Mi"
            cpu    = "500m"
          }
        }
        
        ingress = {
          enabled = false
        }
        
        service = {
          enabled = true
          type = "ClusterIP"
          port = 8200
        }
        
        dataStorage = {
          enabled = true
          size = "10Gi"
          storageClass = "standard"
        }
        
        auditStorage = {
          enabled = true
          size = "5Gi"
          storageClass = "standard"
        }
      }
      
      ui = {
        enabled = true
        serviceType = "ClusterIP"
      }
      
      injector = {
        enabled = true
        
        resources = {
          requests = {
            memory = "256Mi"
            cpu    = "250m"
          }
          limits = {
            memory = "512Mi"
            cpu    = "500m"
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.security]
}

# Trivy Operator for vulnerability scanning
resource "helm_release" "trivy_operator" {
  name       = "trivy-operator"
  repository = "https://aquasecurity.github.io/helm-charts/"
  chart      = "trivy-operator"
  namespace  = "security"
  version    = "0.16.4"

  values = [
    yamlencode({
      serviceMonitor = {
        enabled = true
      }
      
      trivy = {
        ignoreUnfixed = true
        timeout = "5m0s"
        
        resources = {
          requests = {
            cpu    = "100m"
            memory = "100M"
          }
          limits = {
            cpu    = "500m"
            memory = "500M"
          }
        }
      }
      
      operator = {
        scanJobTimeout = "5m"
        
        vulnerabilityScannerEnabled = true
        configAuditScannerEnabled = true
        rbacAssessmentScannerEnabled = true
        infraAssessmentScannerEnabled = true
        
        resources = {
          requests = {
            cpu    = "100m"
            memory = "100M"
          }
          limits = {
            cpu    = "500m"
            memory = "500M"
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.security]
}

# Network Policies for security
resource "kubernetes_network_policy" "jenkins_network_policy" {
  metadata {
    name      = "jenkins-network-policy"
    namespace = "jenkins"
  }

  spec {
    pod_selector {
      match_labels = {
        app = "jenkins"
      }
    }

    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "jenkins"
          }
        }
      }
      
      from {
        namespace_selector {
          match_labels = {
            name = "monitoring"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "8080"
      }
      
      ports {
        protocol = "TCP"
        port     = "50000"
      }
    }

    egress {
      to {}
      
      ports {
        protocol = "TCP"
        port     = "443"
      }
      
      ports {
        protocol = "TCP"
        port     = "80"
      }
      
      ports {
        protocol = "TCP"
        port     = "53"
      }
      
      ports {
        protocol = "UDP"
        port     = "53"
      }
    }
  }
}

# Pod Security Policy
resource "kubernetes_pod_security_policy" "jenkins_psp" {
  metadata {
    name = "jenkins-psp"
  }

  spec {
    privileged                 = false
    allow_privilege_escalation = false
    
    required_drop_capabilities = [
      "ALL"
    ]
    
    volumes = [
      "configMap",
      "emptyDir",
      "projected",
      "secret",
      "downwardAPI",
      "persistentVolumeClaim"
    ]
    
    run_as_user {
      rule = "MustRunAsNonRoot"
    }
    
    se_linux {
      rule = "RunAsAny"
    }
    
    fs_group {
      rule = "RunAsAny"
    }
  }
}

# RBAC for Jenkins with minimal permissions
resource "kubernetes_role" "jenkins_role" {
  metadata {
    namespace = "jenkins"
    name      = "jenkins-role"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/exec", "pods/log", "persistentvolumeclaims"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
  
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "jenkins_role_binding" {
  metadata {
    name      = "jenkins-role-binding"
    namespace = "jenkins"
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.jenkins_role.metadata[0].name
  }
  
  subject {
    kind      = "ServiceAccount"
    name      = "jenkins"
    namespace = "jenkins"
  }
}

# Secret for ML model registry credentials
resource "kubernetes_secret" "ml_registry_secret" {
  metadata {
    name      = "ml-registry-secret"
    namespace = "jenkins"
  }

  data = {
    username = base64encode("admin")
    password = base64encode("changeme123")
    registry_url = base64encode("nexus.jenkins.svc.cluster.local:8081")
  }

  type = "Opaque"
}

# ConfigMap for security scanning configuration
resource "kubernetes_config_map" "security_config" {
  metadata {
    name      = "security-config"
    namespace = "jenkins"
  }

  data = {
    "trivy-config.yaml" = <<-EOF
      vulnerability:
        type: "os,library"
        scanners: ["vuln", "secret"]
        severity: "UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL"
      
      secret:
        config: |
          rules:
            - id: aws-access-key-id
              category: AWS
              title: AWS Access Key ID
              regex: '(?i)aws.{0,20}?(?-i)['\''\"\\s]{0,20}?[0-9a-zA-Z]{20}'
              keywords:
                - aws_access_key_id
                - aws-access-key-id
                - aws_access_key
                - aws-access-key
    EOF
    
    "sbom-config.yaml" = <<-EOF
      format: "spdx-json"
      output: "/tmp/sbom.json"
      catalogers:
        - "python-pip"
        - "go-module"
        - "java-jar"
        - "javascript-npm"
    EOF
  }
}

# Outputs
output "vault_service" {
  description = "Vault service endpoint"
  value       = "vault.security.svc.cluster.local:8200"
}

output "vault_ui_port_forward" {
  description = "Command to access Vault UI"
  value       = "kubectl port-forward -n security svc/vault 8200:8200"
}

output "trivy_operator_status" {
  description = "Trivy operator deployment status"
  value       = "kubectl get pods -n security -l app.kubernetes.io/name=trivy-operator"
} 