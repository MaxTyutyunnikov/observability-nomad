job "minio" {
  datacenters = ["dc1"]
  type        = "service"

  group "minio" {
    count = 1

    network {
      dns {
        servers = ["172.17.0.1", "1.0.0.1", "8.8.4.4"]
      }
      port "http" {
        static = 9000
      }
      port "console" {
        static = 36033
      }
    }

    ephemeral_disk {
      migrate = true
      size    = "500"
      sticky  = true
    }

    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }

    task "wait-for-minio" {
      lifecycle {
        hook = "poststart"
        sidecar = false
      }

      driver = "exec"
      config {
        command = "sh"
        args = ["-c", "/usr/bin/mc-cli --config-dir /mc-conf config host add local http://minio.service.consul:9000 AKIAIOSFODNN7EXAMPLE wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY; /usr/bin/mc-cli --config-dir /mc-conf mb local/tempo-bucket"]
      }
    }

    task "minio" {
      driver = "docker"

      config {
        image = "minio/minio"
        ports = ["http", "console"]
        volumes = [
          "local/export:/export",
        ]

        args = [
          "server",
          "--address",
          "0.0.0.0:9000",
          "--console-address",
          "0.0.0.0:36033",
          "/export",
        ]
      }

      resources {
        cpu    = 200
        memory = 200
      }

      env {
        MINIO_ROOT_USER = "AKIAIOSFODNN7EXAMPLE"
        MINIO_ROOT_PASSWORD = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
      }

      service {
        name = "minio"
        tags = ["s3", "minio", "traefik.enable=true", "traefik.frontend.rule=Host:minio.10.244.234.64.sslip.io"]

        port = "console"

        check {
          name     = "Minio HTTP"
          type     = "http"
          path     = "/login"
          interval = "10s"
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
