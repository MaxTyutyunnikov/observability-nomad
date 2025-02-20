job "prometheus" {
  datacenters = ["dc1"]
  type        = "service"

  group "prometheus" {
    count = 1

    network {
      dns {
        servers = ["172.17.0.1", "1.0.0.1", "8.8.4.4"]
      }
      port "http" {
        static = 9091
      }
    }

    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }

    task "prometheus" {
      driver = "docker"

      template {
        data        = <<EOTC
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: minio-job
    metrics_path: /minio/v2/metrics/cluster
    scheme: http
    static_configs:
    - targets: ['minio.service.consul:9000']
  - job_name: 'self'
    consul_sd_configs:
      - server: 'consul.service.consul:8500'
        token: '6c8cd232-104d-0622-9899-64acd85119a7'
    relabel_configs:
      - source_labels: [__meta_consul_service]
        regex: '.*-sidecar-proxy'
        action: drop
      - source_labels: [__meta_consul_service_metadata_external_source]
        target_label: 'source'
        regex: (.*)
        replacement: '$1'
      - source_labels: [__meta_consul_service_id]
        regex: '_nomad-task-([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})-.*'
        target_label:  'task_id'
        replacement: '$1'
      - source_labels: [__meta_consul_tags]
        regex: '.*,prometheus,.*'
        action: keep
      - source_labels: [__meta_consul_tags]
        regex: '.*,(app|monitoring|demo),.*'
        target_label:  'group'
        replacement:   '$1'
      - source_labels: [__meta_consul_service]
        target_label: 'job'
      - source_labels: [__meta_consul_node]
        regex:         '(.*)'
        target_label:  'instance'
      - source_labels: [__meta_consul_tags]
        regex: '.*,metrics_path=([^,?]*)[?,].*'
        target_label:  '__metrics_path__'
        replacement: '$1'
      - source_labels: [__meta_consul_tags]
        regex: '.*,metrics_path=([^,?]*)\?format=([^,]*),.*'
        target_label:  '__param_format'
        replacement: '$2'
      - source_labels: [__meta_consul_tags]
        regex:         '.*,source=([^,]*),.*'
        target_label:  'source'
        replacement:   '$1'
EOTC
        destination = "/local/prometheus.yml"
      }
      config {
        image = "prom/prometheus:v2.29.0"
        ports = ["http"]
        args = [
          "--config.file=/local/prometheus.yml",
          "--web.enable-admin-api",
          "--web.listen-address=:9091",
          "--enable-feature=remote-write-receiver",
        ]
      }

      resources {
        cpu    = 200
        memory = 170
      }

      service {
        name = "prometheus"
        port = "http"
        tags = ["monitoring", "prometheus"]

        check {
          name     = "Prometheus HTTP"
          type     = "http"
          path     = "/targets"
          interval = "5s"
          timeout  = "2s"

          check_restart {
            limit           = 2
            grace           = "60s"
            ignore_warnings = false
          }
        }
      }
    }
  }
}
