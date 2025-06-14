# Jenkins ML Pipeline - Terraform Configuration for Jenkins
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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
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
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"
}

variable "namespace" {
  description = "Kubernetes namespace for Jenkins"
  type        = string
  default     = "jenkins"
}

variable "enable_gpu" {
  description = "Enable GPU support for ML workloads"
  type        = bool
  default     = false
}

variable "jenkins_admin_password" {
  description = "Jenkins admin password"
  type        = string
  default     = "admin123"
  sensitive   = true
}

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "standard"
}

variable "jenkins_cpu_request" {
  description = "CPU request for Jenkins controller"
  type        = string
  default     = "500m"
}

variable "jenkins_memory_request" {
  description = "Memory request for Jenkins controller"
  type        = string
  default     = "1Gi"
}

variable "jenkins_cpu_limit" {
  description = "CPU limit for Jenkins controller"
  type        = string
  default     = "2"
}

variable "jenkins_memory_limit" {
  description = "Memory limit for Jenkins controller"
  type        = string
  default     = "4Gi"
}

variable "agent_cpu_request" {
  description = "CPU request for Jenkins agents"
  type        = string
  default     = "200m"
}

variable "agent_memory_request" {
  description = "Memory request for Jenkins agents"
  type        = string
  default     = "512Mi"
}

variable "agent_cpu_limit" {
  description = "CPU limit for Jenkins agents"
  type        = string
  default     = "1"
}

variable "agent_memory_limit" {
  description = "Memory limit for Jenkins agents"
  type        = string
  default     = "2Gi"
}

# Data sources
data "kubernetes_namespace" "jenkins" {
  metadata {
    name = var.namespace
  }
}

# Random password for Jenkins if not provided
resource "random_password" "jenkins_admin" {
  count   = var.jenkins_admin_password == "admin123" ? 1 : 0
  length  = 16
  special = true
}

# Local values
locals {
  jenkins_admin_password = var.jenkins_admin_password != "admin123" ? var.jenkins_admin_password : random_password.jenkins_admin[0].result
  
  labels = {
    app         = "jenkins-ml-pipeline"
    component   = "jenkins"
    environment = var.environment
    managed-by  = "terraform"
  }
  
  jenkins_plugins = [
    "kubernetes:4046.v45084ce53f7b",
    "workflow-aggregator:596.v8c21c963d92d",
    "git:5.0.0",
    "configuration-as-code:1670.v564dc8b_982d0",
    "blueocean:1.25.9",
    "pipeline-stage-view:2.25",
    "docker-workflow:563.vd5d2e5c4007f",
    "prometheus:2.0.10",
    "kubernetes-cli:1.12.1",
    "pipeline-utility-steps:2.15.1",
    "http_request:1.16",
    "build-timestamp:1.0.3",
    "timestamper:1.21",
    "ws-cleanup:0.44",
    "ant:475.vf34069fef73c",
    "gradle:2.8.2",
    "maven-integration:3.19",
    "python:1.3",
    "terraform:1.0.10",
    "opentelemetry:2.8.0",
    "datadog:5.4.1",
    "junit:1171.va_b_080c29cf6d",
    "jacoco:3.3.2.1",
    "htmlpublisher:1.31",
    "email-ext:2.96",
    "build-user-vars-plugin:1.8",
    "parameterized-trigger:2.45",
    "conditional-buildstep:1.4.2",
    "matrix-project:771.v574584b_39e60",
    "ssh-agent:333.v878b_53c89511",
    "credentials:1271.v54b_1c877c6f4",
    "credentials-binding:523.vd859a_4b_122e6",
    "vault:3.20.1"
  ]
}

# Service Account for Jenkins
resource "kubernetes_service_account" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = var.namespace
    labels    = local.labels
  }
}

# Cluster Role for Jenkins
resource "kubernetes_cluster_role" "jenkins" {
  metadata {
    name   = "jenkins-ml-pipeline"
    labels = local.labels
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/exec", "pods/log", "services", "endpoints", "persistentvolumeclaims", "events", "configmaps", "secrets", "nodes"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["deployments", "replicasets", "ingresses"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["argoproj.io"]
    resources  = ["rollouts", "experiments", "analysistemplates", "analysisruns"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses", "networkpolicies"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

# Cluster Role Binding for Jenkins
resource "kubernetes_cluster_role_binding" "jenkins" {
  metadata {
    name   = "jenkins-ml-pipeline"
    labels = local.labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.jenkins.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.jenkins.metadata[0].name
    namespace = var.namespace
  }
}

# Secret for Jenkins admin credentials
resource "kubernetes_secret" "jenkins_admin" {
  metadata {
    name      = "jenkins-admin-credentials"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    jenkins-admin-user     = "admin"
    jenkins-admin-password = local.jenkins_admin_password
  }

  type = "Opaque"
}

# ConfigMap for Jenkins Configuration as Code
resource "kubernetes_config_map" "jenkins_casc" {
  metadata {
    name      = "jenkins-casc-config"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    "jenkins.yaml" = yamlencode({
      jenkins = {
        systemMessage = "Jenkins ML Pipeline - Managed by Terraform"
        numExecutors  = 0
        mode          = "EXCLUSIVE"
        
        securityRealm = {
          local = {
            allowsSignup = false
            users = [{
              id       = "admin"
              password = "$${jenkins-admin-password}"
            }]
          }
        }
        
        authorizationStrategy = {
          loggedInUsersCanDoAnything = {
            allowAnonymousRead = false
          }
        }
        
        clouds = [{
          kubernetes = {
            name           = "kubernetes"
            serverUrl      = ""
            namespace      = var.namespace
            jenkinsUrl     = "http://jenkins.${var.namespace}.svc.cluster.local:8080"
            jenkinsTunnel  = "jenkins-agent.${var.namespace}.svc.cluster.local:50000"
            containerCap   = 10
            maxRequestsPerHost = 32
            
            templates = [{
              name      = "ml-pipeline-agent"
              namespace = var.namespace
              label     = "ml-pipeline"
              nodeUsageMode = "EXCLUSIVE"
              
              containers = [{
                name  = "jnlp"
                image = "jenkins/inbound-agent:latest"
                args  = "$${computer.jnlpmac} $${computer.name}"
                
                resourceRequestCpu    = var.agent_cpu_request
                resourceRequestMemory = var.agent_memory_request
                resourceLimitCpu      = var.agent_cpu_limit
                resourceLimitMemory   = var.agent_memory_limit
              }]
              
              volumes = [{
                hostPathVolume = {
                  hostPath = "/var/run/docker.sock"
                  mountPath = "/var/run/docker.sock"
                }
              }]
              
              yaml = yamlencode({
                spec = merge(
                  {
                    serviceAccountName = "jenkins"
                    securityContext = {
                      runAsUser  = 1000
                      runAsGroup = 1000
                      fsGroup    = 1000
                    }
                  },
                  var.enable_gpu ? {
                    nodeSelector = {
                      "accelerator" = "nvidia-tesla-k80"
                    }
                    tolerations = [{
                      key      = "nvidia.com/gpu"
                      operator = "Exists"
                      effect   = "NoSchedule"
                    }]
                  } : {}
                )
              })
            }]
          }
        }]
        
        globalNodeProperties = [{
          envVars = {
            env = [
              {
                key   = "ENVIRONMENT"
                value = var.environment
              },
              {
                key   = "CLUSTER_NAME"
                value = var.cluster_name
              }
            ]
          }
        }]
      }
      
      unclassified = {
        prometheus = {
          path         = "/prometheus"
          defaultNamespace = "jenkins"
          useAuthenticatedEndpoint = false
        }
        
        openTelemetry = {
          endpoint                    = "http://jaeger-collector.monitoring.svc.cluster.local:14250"
          serviceName                = "jenkins-ml-pipeline"
          serviceNamespace           = var.namespace
          serviceVersion             = "1.0.0"
          ignoredSteps               = ["dir", "echo", "isUnix", "pwd", "properties"]
          configurationProperties    = "otel.traces.exporter=jaeger"
          exportOtelConfigurationAsEnvironmentVariables = true
        }
      }
    })
  }
}

# Helm Release for Jenkins
resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = "4.8.3"
  namespace  = var.namespace
  
  values = [
    yamlencode({
      controller = {
        componentName = "jenkins-controller"
        image         = "jenkins/jenkins"
        tag           = "2.426.1-lts"
        
        adminUser         = "admin"
        adminPassword     = local.jenkins_admin_password
        adminSecret       = true
        existingSecret    = kubernetes_secret.jenkins_admin.metadata[0].name
        
        serviceType = "LoadBalancer"
        servicePort = 8080
        targetPort  = 8080
        
        healthProbes          = true
        healthProbesLivenessTimeout  = 5
        healthProbesReadinessTimeout = 5
        healthProbeLivenessPeriodSeconds = 10
        healthProbeReadinessPeriodSeconds = 10
        healthProbeLivenessFailureThreshold = 5
        healthProbeReadinessFailureThreshold = 3
        healthProbesLivenessInitialDelay = 90
        healthProbesReadinessInitialDelay = 60
        
        resources = {
          requests = {
            cpu    = var.jenkins_cpu_request
            memory = var.jenkins_memory_request
          }
          limits = {
            cpu    = var.jenkins_cpu_limit
            memory = var.jenkins_memory_limit
          }
        }
        
        # JVM options for better performance
        javaOpts = "-Xmx2g -Djenkins.install.runSetupWizard=false -Djava.awt.headless=true"
        
        installPlugins = local.jenkins_plugins
        
        # Configuration as Code
        JCasC = {
          defaultConfig    = false
          configScripts    = {
            "jenkins-casc-config" = kubernetes_config_map.jenkins_casc.data["jenkins.yaml"]
          }
          securityRealm = "|"
          authorizationStrategy = "|"
        }
        
        serviceAccount = {
          create = false
          name   = kubernetes_service_account.jenkins.metadata[0].name
        }
        
        podSecurityContextOverride = {
          runAsUser     = 1000
          runAsGroup    = 1000
          runAsNonRoot  = true
          fsGroup       = 1000
        }
        
        containerSecurityContext = {
          runAsUser                = 1000
          runAsGroup               = 1000
          runAsNonRoot             = true
          readOnlyRootFilesystem   = false
          allowPrivilegeEscalation = false
          capabilities = {
            drop = ["ALL"]
          }
        }
        
        # Enable prometheus metrics
        prometheus = {
          enabled = true
          serviceMonitorAdditionalLabels = {
            app = "jenkins-ml-pipeline"
          }
        }
        
        # Additional environment variables
        containerEnv = [
          {
            name  = "ENVIRONMENT"
            value = var.environment
          },
          {
            name  = "CLUSTER_NAME"
            value = var.cluster_name
          }
        ]
      }
      
      agent = {
        enabled = true
        defaultsProviderTemplate = "ml-pipeline-agent"
        
        resources = {
          requests = {
            cpu    = var.agent_cpu_request
            memory = var.agent_memory_request
          }
          limits = {
            cpu    = var.agent_cpu_limit
            memory = var.agent_memory_limit
          }
        }
        
        podName = "ml-pipeline-agent"
        customJenkinsLabels = ["ml-pipeline"]
        
        # Enable GPU support if requested
        podTemplates = var.enable_gpu ? {
          gpu-agent = {
            name      = "gpu-agent"
            label     = "gpu"
            nodeSelector = {
              "accelerator" = "nvidia-tesla-k80"
            }
            tolerations = [{
              key      = "nvidia.com/gpu"
              operator = "Exists"
              effect   = "NoSchedule"
            }]
            containers = {
              jnlp = {
                image = "jenkins/inbound-agent:latest"
                resources = {
                  limits = {
                    "nvidia.com/gpu" = "1"
                  }
                }
              }
            }
          }
        } : {}
        
        volumes = [
          {
            type = "hostPath"
            hostPath = "/var/run/docker.sock"
            mountPath = "/var/run/docker.sock"
          }
        ]
      }
      
      persistence = {
        enabled      = true
        existingClaim = ""
        storageClass = var.storage_class
        accessMode   = "ReadWriteOnce"
        size         = "20Gi"
        
        volumes = []
        mounts  = []
      }
      
      serviceMonitor = {
        enabled = true
        labels = {
          app = "jenkins-ml-pipeline"
        }
      }
      
      # Network policies for security
      networkPolicy = {
        enabled = true
        internalAgents = {
          allowed = true
          namespaceLabels = {
            name = var.namespace
          }
        }
        externalAgents = {
          ipCIDR = "0.0.0.0/0"
        }
      }
      
      rbac = {
        create = false
      }
      
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.jenkins.metadata[0].name
      }
    })
  ]
  
  depends_on = [
    kubernetes_service_account.jenkins,
    kubernetes_cluster_role_binding.jenkins,
    kubernetes_config_map.jenkins_casc,
    kubernetes_secret.jenkins_admin
  ]
}

# Outputs
output "jenkins_url" {
  description = "Jenkins URL"
  value       = "http://${helm_release.jenkins.name}.${var.namespace}.svc.cluster.local:8080"
}

output "jenkins_admin_password" {
  description = "Jenkins admin password"
  value       = local.jenkins_admin_password
  sensitive   = true
}

output "jenkins_service_account" {
  description = "Jenkins service account name"
  value       = kubernetes_service_account.jenkins.metadata[0].name
}

output "jenkins_namespace" {
  description = "Jenkins namespace"
  value       = var.namespace
} 