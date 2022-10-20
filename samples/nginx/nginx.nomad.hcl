job "nginx" {
  datacenters = ["dc1"]
  # Runs on all nomad clients
  type = "system"

  group "nginx" {
    count = 1

    network {
      dns {
        servers = ["172.17.0.1", "8.8.8.8", "8.8.4.4"]
      }
      port "http" {
        static = 8888
        to = 80
      }
    }

    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }

    task "nginx" {
      driver = "docker"

      env {
        HOSTNAME = "${attr.unique.hostname}"
      }

      config {
        image = "nginx:demo"
        ports = ["http"]
        args = []
        volumes = [
          "/tmp/nginx-logs:/var/log/nginx",
          "/tmp/samples/nginx/conf/conf.d:/etc/nginx/conf.d",
          "/tmp/samples/nginx/html:/usr/share/nginx/html"
        ]
      }

      resources {
        cpu    = 100
        memory = 100
      }

      service {
        name = "nginx"
        port = "http"
        tags = ["www"]

        check {
          name     = "Nginx HTTP"
          type     = "http"
          path     = "/demo/"
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
