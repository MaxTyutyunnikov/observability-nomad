# -*- mode: ruby -*-
# vi: set ft=ruby :

$script = <<SCRIPT
echo "Installing Docker..."

export DEBIAN_FRONTEND=noninteractive

export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

sudo locale-gen en_US.UTF-8
sudo dpkg-reconfigure  -f noninteractive locales  --force --default-priority

sudo apt-get update

sudo apt-get remove -y docker docker-engine docker.io

echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections

sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common < /dev/null

sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg |  sudo apt-key add -

sudo apt-key fingerprint 0EBFCD88

sudo add-apt-repository -y \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) \
      stable"

sudo apt-get update
sudo apt-get install -y docker-ce ntp </dev/null

# Restart docker to make sure we get the latest version of the daemon if there is an upgrade
sudo systemctl daemon-reload
sudo service docker restart
# Make sure we can actually use docker as the vagrant user
sudo usermod -aG docker vagrant
sudo docker --version

# Packages required for nomad & consul
sudo apt-get install unzip curl vim -y </dev/null

echo "Installing Nomad..."
NOMAD_VERSION=1.3.2
cd /tmp/
env
echo https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip
if ! curl --fail -sSL https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip -o nomad.zip 2>/tmp/nomad.log; then
  cat /tmp/nomad.log
  echo "Failed to download Nomad $NOMAD_VERSION"
  exit 1
fi
if ! unzip -o -q nomad.zip; then
  echo "Failed to extract Nomad $NOMAD_VERSION"
  exit 1
fi
sudo install nomad /usr/bin/nomad
sudo mkdir -p /etc/nomad.d
sudo chmod a+w /etc/nomad.d

echo "Installing CNI plugins..."
CNI_VERSION=1.0.1
echo https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/cni-plugins-linux-amd64-v${CNI_VERSION}.tgz
if ! curl --fail -sL -o cni-plugins.tgz https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/cni-plugins-linux-amd64-v${CNI_VERSION}.tgz 2>/dev/null; then
  echo "Failed to download CNI plugins $CNI_VERSION"
  exit 1
fi
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz

echo "Installing Consul..."
CONSUL_VERSION=1.12.3
echo https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip

if ! curl --fail -sSL https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip > consul.zip 2>/dev/null; then
  echo "Failed to download Consul $CONSUL_VERSION"
  exit 1
fi

if ! unzip -o -q /tmp/consul.zip; then
  echo "Failed to extract Consul $CONSUL_VERSION"
  exit 1
fi

sudo install consul /usr/bin/consul

# Consul service systemd startup script
(
cat <<-EOF
[Unit]
Description=consul agent
Requires=network-online.target
After=network-online.target

[Service]
Restart=on-failure
ExecStart=/opt/bin/consul agent -dev -client=0.0.0.0 -config-dir=/etc/consul.d
ExecReload=/bin/kill -HUP $MAINPID
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target

EOF
) | sudo tee /etc/systemd/system/consul.service

# Enable and start Consul systemd service
sudo systemctl enable consul.service
sudo systemctl start consul

for bin in cfssl cfssl-certinfo cfssljson
do
  echo "Installing $bin..."
  curl -sSL https://pkg.cfssl.org/R1.2/${bin}_linux-amd64 > /tmp/${bin}
  sudo install /tmp/${bin} /usr/local/bin/${bin} || :
done

nomad -autocomplete-install
sudo mkdir -p /opt/nomad/data/
sudo mkdir -p /etc/nomad/

# Nomad configuration
(
cat <<-EOF
data_dir  = "/opt/nomad/data/"
bind_addr = "0.0.0.0"
plugin "docker" {
  config {
    volumes {
      enabled = true
    }
  }
}
telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
  prometheus_metrics         = true
}
EOF
) | sudo tee /etc/nomad/config.hcl

# Nomad service systemd startup script
(
cat <<-EOF
[Unit]
Description=nomad dev agent
Requires=network-online.target
After=network-online.target

[Service]
  Environment=PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Restart=on-failure
ExecStart=/usr/bin/nomad agent -dev-connect -config=/etc/nomad/config.hcl
ExecReload=/bin/kill -HUP $MAINPID
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target

EOF
) | sudo tee /etc/systemd/system/nomad.service

# Enable and start Nomad systemd service
sudo systemctl enable nomad.service
sudo systemctl start nomad

echo "Setting up iptable to forward dns request to consul..."
sudo iptables -t nat -A PREROUTING -p udp -m udp --dport 53 -j REDIRECT --to-ports 8600
sudo iptables -t nat -A PREROUTING -p tcp -m tcp --dport 53 -j REDIRECT --to-ports 8600
sudo iptables -t nat -A OUTPUT -d localhost -p udp -m udp --dport 53 -j REDIRECT --to-ports 8600
sudo iptables -t nat -A OUTPUT -d localhost -p tcp -m tcp --dport 53 -j REDIRECT --to-ports 8600
sudo iptables -t nat -A OUTPUT -d 127.0.0.1 -p udp -m udp --dport 53 -j REDIRECT --to-ports 8600
sudo iptables -t nat -A OUTPUT -d 127.0.0.1 -p tcp -m tcp --dport 53 -j REDIRECT --to-ports 8600
sudo iptables -t nat -A OUTPUT -d 1.0.0.1 -p udp -m udp --dport 53 -j REDIRECT --to-ports 8600
sudo iptables -t nat -A OUTPUT -d 1.0.0.1 -p tcp -m tcp --dport 53 -j REDIRECT --to-ports 8600

echo "Pulling Docker images"

if [ -n "$DOCKERHUBID" ] && [ -n "$DOCKERHUBPASSWD" ]; then
  echo "Login to Docker Hub as $DOCKERHUBID"
  if ! echo "$DOCKERHUBPASSWD" | sudo docker login --username "$DOCKERHUBID" --password-stdin; then
    echo 'Error login to Docker Hub'
    exit 2
  fi
fi

find /vagrant/jobs -maxdepth 1 -type f -name '*.nomad.hcl' | xargs grep -E 'image\s*=\s*' | awk '{print $NF}' | sed -e 's/"//g' -e 's/:demo//' | while read j; do
  echo "Pulling $j Docker image"
  if ! sudo docker pull $j >/dev/null; then
    echo "Exiting"
    exit 1
  fi
  if ! echo "$j" | grep -q ':'; then
    sudo docker tag "$j":latest "$j":demo
  fi
done
if [ $? -ne 0 ]; then
  exit 1
fi

if [ -n "$DOCKERHUBID" ] && [ -n "$DOCKERHUBPASSWD" ]; then
  echo "Logout from Docker Hub as $DOCKERHUBID"
  if ! sudo docker logout; then
    echo 'Error logging out from Docker Hub'
  fi
fi

echo "Installing Grafana stack..."

until nomad status
do
  echo "Waiting for Nomad to be ready...."
  sleep 3
done

sudo curl -s https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o /usr/bin/mc-cli
sudo chmod +x /usr/bin/mc-cli

####/usr/bin/mc-cli config host add minio http://127.0.0.1:9000 "AKIAIOSFODNN7EXAMPLE" "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
####/usr/bin/mc-cli mb minio/tempo-bucket

# Handle all Nomad job files one at a time
# Use the naming of Nomad job files to determine scheduling order of services
find /vagrant/jobs -maxdepth 1 -type f -name '*.nomad.hcl' | sort | while read j; do
  # Job can be successfully planed (enough resources left)
  svc=$(basename $j | sed -e 's/\.nomad\.hcl//' -e 's/^[0-9][0-9]-//')
  if nomad plan $j | grep -Eq 'All tasks successfully allocated'; then
    echo "Scheduling $svc"
    nomad run $j
  else
    echo "Error can not schedule $svc"
  fi
done

SCRIPT


Vagrant.configure(2) do |config|
  config.vm.box = "bento/ubuntu-20.04" # 18.04 LTS
  config.vm.hostname = "ubuntu-nomad"
  config.vm.disk :disk, size: "8GB", primary: true
  config.vm.box_check_update = false
  config.disksize.size = '8GB'

  config.vm.provision "shell", inline: $script, env: {"DOCKERHUBID"=>ENV['DOCKERHUBID'], "DOCKERHUBPASSWD"=>ENV['DOCKERHUBPASSWD']}, privileged: false

  # Expose the nomad api and ui to the host
  config.vm.network "forwarded_port", guest: 4646, host: 4646
  # consul
  config.vm.network "forwarded_port", guest: 8500, host: 8500
  # minio
  config.vm.network "forwarded_port", guest: 9000, host: 9000
  config.vm.network "forwarded_port", guest: 36033, host: 36033
  # grafana
  config.vm.network "forwarded_port", guest: 3000, host: 3000
  # prometheus
  config.vm.network "forwarded_port", guest: 9090, host: 9090
  # loki
  config.vm.network "forwarded_port", guest: 3100, host: 3100
  # promtail
  config.vm.network "forwarded_port", guest: 3200, host: 3200
  # tns app
  config.vm.network "forwarded_port", guest: 8001, host: 8001
  # Nginx
  config.vm.network "forwarded_port", guest: 8888, host: 8888
  # cAdvisor
  config.vm.network "forwarded_port", guest: 8080, host: 8080
  # Netdata
  config.vm.network "forwarded_port", guest: 19999, host: 19999

  # Increase memory for Parallels Desktop
  config.vm.provider "parallels" do |p, o|
    p.memory = "4096"
  end

  # Increase memory for Virtualbox
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "4096"
  end

  # Increase memory for VMware
  ["vmware_fusion", "vmware_workstation"].each do |p|
    config.vm.provider p do |v|
      v.vmx["memsize"] = "4096"
    end
  end

  # Set the timezone the same as the host so that metrics & logs ingested have the right timestamp.
  require 'time'
  offset = ((Time.zone_offset(Time.now.zone) / 60) / 60)
  timezone_suffix = offset >= 0 ? "-#{offset.to_s}" : "+#{offset.to_s}"
  timezone = 'Etc/GMT' + timezone_suffix
  config.vm.provision :shell, :inline => "sudo rm /etc/localtime && sudo ln -s /usr/share/zoneinfo/" + timezone + " /etc/localtime", run: "always"
end
