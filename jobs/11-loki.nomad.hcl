job "loki" {
  datacenters = ["dc1"]
  type        = "service"

  group "loki" {
    count = 1

    network {
      dns {
        servers = ["172.17.0.1", "1.0.0.1", "8.8.4.4"]
      }
      port "http" {
        static = 3100
      }
    }

    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }

    task "loki" {
      driver = "docker"

      env {
        JAEGER_AGENT_HOST    = "tempo.service.consul"
        JAEGER_TAGS          = "cluster=nomad"
        JAEGER_SAMPLER_TYPE  = "probabilistic"
        JAEGER_SAMPLER_PARAM = "1"
      }

      config {
        image = "grafana/loki:latest"
        ports = ["http"]
        args = [
          "-config.file",
          "/local/etc/loki/local-config.yaml",
        ]
      }

      resources {
        cpu    = 1000
        memory = 170
      }

      artifact {
        source      = "https://raw.githubusercontent.com/alfkonee/observability-nomad/main/config/loki-local-config.yaml"
        mode        = "file"
        destination = "/local/etc/loki/local-config.yaml"
      }

      service {
        name = "loki"
        port = "http"
        tags = ["monitoring", "prometheus"]

        check {
          name     = "Loki HTTP"
          type     = "http"
          path     = "/ready"
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
