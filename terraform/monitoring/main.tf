# Monitoring Infrastructure
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

# Prometheus Stack
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  version    = "51.2.0"

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          retention = "30d"
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "standard"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "50Gi"
                  }
                }
              }
            }
          }
          additionalScrapeConfigs = [
            {
              job_name = "jenkins"
              static_configs = [
                {
                  targets = ["jenkins.jenkins.svc.cluster.local:8080"]
                }
              ]
            },
            {
              job_name = "ml-models"
              kubernetes_sd_configs = [
                {
                  role = "pod"
                  namespaces = {
                    names = ["default", "jenkins"]
                  }
                }
              ]
              relabel_configs = [
                {
                  source_labels = ["__meta_kubernetes_pod_label_app"]
                  action        = "keep"
                  regex         = "ml-model"
                }
              ]
            }
          ]
        }
      }
      grafana = {
        adminPassword = "admin123"
        persistence = {
          enabled = true
          size    = "10Gi"
        }
        dashboardProviders = {
          "dashboardproviders.yaml" = {
            apiVersion = 1
            providers = [
              {
                name            = "default"
                orgId           = 1
                folder          = ""
                type            = "file"
                disableDeletion = false
                editable        = true
                options = {
                  path = "/var/lib/grafana/dashboards/default"
                }
              }
            ]
          }
        }
        dashboards = {
          default = {
            "ml-performance" = {
              file = "dashboards/ml-performance-dashboard.json"
            }
          }
        }
      }
      alertmanager = {
        alertmanagerSpec = {
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "standard"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "10Gi"
                  }
                }
              }
            }
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

# Elasticsearch
resource "helm_release" "elasticsearch" {
  name       = "elasticsearch"
  repository = "https://helm.elastic.co"
  chart      = "elasticsearch"
  namespace  = "logging"
  version    = "8.5.1"

  values = [
    yamlencode({
      replicas = 3
      minimumMasterNodes = 2
      
      esConfig = {
        "elasticsearch.yml" = <<-EOF
          cluster.name: "jenkins-ml-logs"
          network.host: 0.0.0.0
          discovery.seed_hosts: "elasticsearch-master-headless"
          cluster.initial_master_nodes: "elasticsearch-master-0,elasticsearch-master-1,elasticsearch-master-2"
          xpack.security.enabled: false
          xpack.monitoring.collection.enabled: true
        EOF
      }

      volumeClaimTemplate = {
        accessModes = ["ReadWriteOnce"]
        storageClassName = "standard"
        resources = {
          requests = {
            storage = "30Gi"
          }
        }
      }

      resources = {
        requests = {
          cpu    = "1000m"
          memory = "2Gi"
        }
        limits = {
          cpu    = "2000m"
          memory = "4Gi"
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.logging]
}

# Kibana
resource "helm_release" "kibana" {
  name       = "kibana"
  repository = "https://helm.elastic.co"
  chart      = "kibana"
  namespace  = "logging"
  version    = "8.5.1"

  values = [
    yamlencode({
      elasticsearchHosts = "http://elasticsearch-master:9200"
      
      kibanaConfig = {
        "kibana.yml" = <<-EOF
          server.host: 0.0.0.0
          elasticsearch.hosts: ["http://elasticsearch-master:9200"]
          monitoring.ui.container.elasticsearch.enabled: true
        EOF
      }

      service = {
        type = "ClusterIP"
        port = 5601
      }

      resources = {
        requests = {
          cpu    = "500m"
          memory = "1Gi"
        }
        limits = {
          cpu    = "1000m"
          memory = "2Gi"
        }
      }
    })
  ]

  depends_on = [helm_release.elasticsearch]
}

# Fluent Bit
resource "helm_release" "fluent_bit" {
  name       = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  namespace  = "logging"
  version    = "0.21.7"

  values = [
    yamlencode({
      config = {
        service = <<-EOF
          [SERVICE]
              Daemon Off
              Flush 1
              Log_Level info
              Parsers_File parsers.conf
              Parsers_File custom_parsers.conf
              HTTP_Server On
              HTTP_Listen 0.0.0.0
              HTTP_Port 2020
              Health_Check On
        EOF

        inputs = <<-EOF
          [INPUT]
              Name tail
              Path /var/log/containers/*.log
              multiline.parser docker, cri
              Tag kube.*
              Mem_Buf_Limit 50MB
              Skip_Long_Lines On

          [INPUT]
              Name systemd
              Tag host.*
              Systemd_Filter _SYSTEMD_UNIT=kubelet.service
              Read_From_Tail On
        EOF

        filters = <<-EOF
          [FILTER]
              Name kubernetes
              Match kube.*
              Kube_URL https://kubernetes.default.svc:443
              Kube_CA_File /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
              Kube_Token_File /var/run/secrets/kubernetes.io/serviceaccount/token
              Kube_Tag_Prefix kube.var.log.containers.
              Merge_Log On
              Keep_Log Off
              K8S-Logging.Parser On
              K8S-Logging.Exclude Off

          [FILTER]
              Name parser
              Match kube.*jenkins*
              Key_Name log
              Parser jenkins
              Reserve_Data On
        EOF

        outputs = <<-EOF
          [OUTPUT]
              Name es
              Match kube.*
              Host elasticsearch-master
              Port 9200
              Logstash_Format On
              Logstash_Prefix jenkins-ml
              Retry_Limit 3
              Type _doc
              Replace_Dots On
              Suppress_Type_Name On
        EOF

        customParsers = <<-EOF
          [PARSER]
              Name jenkins
              Format regex
              Regex ^(?<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}) \[(?<thread>.*?)\] (?<level>\w+)\s+(?<logger>.*?) - (?<message>.*)$
              Time_Key timestamp
              Time_Format %Y-%m-%d %H:%M:%S.%L
        EOF
      }

      tolerations = [
        {
          key      = "node-role.kubernetes.io/master"
          operator = "Exists"
          effect   = "NoSchedule"
        }
      ]
    })
  ]

  depends_on = [helm_release.elasticsearch]
}

# Jaeger
resource "helm_release" "jaeger" {
  name       = "jaeger"
  repository = "https://jaegertracing.github.io/helm-charts"
  chart      = "jaeger"
  namespace  = "monitoring"
  version    = "0.71.11"

  values = [
    yamlencode({
      provisionDataStore = {
        cassandra = false
        elasticsearch = true
      }
      
      storage = {
        type = "elasticsearch"
        elasticsearch = {
          host = "elasticsearch-master.logging.svc.cluster.local"
          port = 9200
          scheme = "http"
        }
      }

      agent = {
        enabled = true
      }

      collector = {
        enabled = true
        service = {
          type = "ClusterIP"
        }
      }

      query = {
        enabled = true
        service = {
          type = "ClusterIP"
          port = 16686
        }
      }
    })
  ]

  depends_on = [helm_release.elasticsearch]
}

# Outputs
output "prometheus_service" {
  description = "Prometheus service endpoint"
  value       = "prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090"
}

output "grafana_service" {
  description = "Grafana service endpoint"
  value       = "prometheus-grafana.monitoring.svc.cluster.local:80"
}

output "elasticsearch_service" {
  description = "Elasticsearch service endpoint"
  value       = "elasticsearch-master.logging.svc.cluster.local:9200"
}

output "kibana_service" {
  description = "Kibana service endpoint"
  value       = "kibana-kibana.logging.svc.cluster.local:5601"
}

output "jaeger_service" {
  description = "Jaeger service endpoint"
  value       = "jaeger-query.monitoring.svc.cluster.local:16686"
} 