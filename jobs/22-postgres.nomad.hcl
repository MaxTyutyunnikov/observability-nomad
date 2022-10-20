#To Configure vault
# vault secrets enable database
# vault write database/config/postgresql  plugin_name=postgresql-database-plugin   connection_url="postgresql://{{username}}:{{password}}@postgres.service.consul:5432/postgres?sslmode=disable"   allowed_roles="*"     username="root"     password="rootpassword"
# vault write database/roles/readonly db_name=postgresql     creation_statements=@readonly.sql     default_ttl=1h max_ttl=24h

job "postgres-server" {
  datacenters = ["dc1"]
  type = "service"

  group "postgres-server" {
    count = 1

    network {
      dns {
        servers = ["172.17.0.1", "1.0.0.1", "8.8.4.4"]
      }
      port "http" {
        static = 5432
      }
    }

    restart {
      attempts = 10
      interval = "5m"
      delay = "25s"
      mode = "delay"
    }

    task "postgres-server" {
      driver = "docker"

      config {
        image = "postgres:12.12-alpine"
####        network_mode = "host"
        ports = ["http"]
      }
      env {
          POSTGRES_USER="grafana"
          POSTGRES_PASSWORD="rootpassword"
          POSTGRES_DB="grafana_data"
      }

      logs {
        max_files     = 5
        max_file_size = 15
      }

      resources {
        cpu = 100
        memory = 200
      }
      service {
        name = "postgres-server"
        tags = ["postgres"]
        port = "http"

        check {
          name     = "alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }

  }

  update {
    max_parallel = 1
    min_healthy_time = "5s"
    healthy_deadline = "3m"
    auto_revert = false
    canary = 0
  }
}
