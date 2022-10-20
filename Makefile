.PHONY: fmt install

HCLFMT := $(shell command -v hclfmt 2> /dev/null)

fmt:
ifndef HCLFMT
	GO111MODULE=on go get github.com/hashicorp/hcl/v2/cmd/hclfmt
endif
	find jobs/*.nomad.hcl -maxdepth 0 | xargs -L 1 hclfmt -w


install:
	find jobs/*.nomad.hcl -maxdepth 0 | xargs -L 1 nomad job run

bootstrap:
	http_proxy=http://192.168.1.56:8118 https_proxy=http://192.168.1.56:8118 vagrant plugin install vagrant-proxyconf || :
	http_proxy=http://192.168.1.56:8118 https_proxy=http://192.168.1.56:8118 vagrant plugin install vagrant-disksize || :
	http_proxy=http://192.168.1.56:8118 https_proxy=http://192.168.1.56:8118 vagrant box add --provider=virtualbox bento/ubuntu-18.04 || :
	http_proxy=http://192.168.1.56:8118 https_proxy=http://192.168.1.56:8118 vagrant box add --provider=virtualbox bento/ubuntu-20.04 || :

up_proxy:
	VAGRANT_EXPERIMENTAL="disks" http_proxy=http://192.168.1.56:8118 https_proxy=http://192.168.1.56:8118 VAGRANT_HTTP_PROXY=http://192.168.1.56:8118 VAGRANT_HTTPS_PROXY=http://192.168.1.56:8118 VAGRANT_NO_PROXY=127.0.0.1 vagrant up

up:
	VAGRANT_EXPERIMENTAL="disks" vagrant up

down:
	vagrant destroy -f

test:
	http_proxy=http://192.168.1.56:8118 https_proxy=http://192.168.1.56:8118 wget https://releases.hashicorp.com/nomad/1.3.2/nomad_1.3.2_linux_amd64.zip

halt:
	vagrant halt

provision:
	VAGRANT_EXPERIMENTAL="disks" http_proxy=http://192.168.1.56:8118 https_proxy=http://192.168.1.56:8118 VAGRANT_HTTP_PROXY=http://192.168.1.56:8118 VAGRANT_HTTPS_PROXY=http://192.168.1.56:8118 VAGRANT_NO_PROXY=127.0.0.1 vagrant provision
