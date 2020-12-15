# Packer
PACKER_IMAGE = hashicorp/packer:1.6.5

PACKER = docker run -it --rm \
	-v $(PWD)/packer/:/root \
	--workdir /root \
	$(PACKER_IMAGE)



# Build settings
ZONE ?= "ch-gva-2"

.PHONY: packer.build
packer.build: check-env
	$(PACKER) build -var api_key="$(EXOSCALE_API_KEY)" -var api_secret="$(EXOSCALE_API_SECRET)" -var zone=$(ZONE) kubernetes.pkr.hcl

.PHONY: packer.deps
packer.deps:
	mkdir -p $(PWD)/packer/.packer.d/plugins && wget -qO - https://github.com/exoscale/packer-builder-exoscale/releases/download/v0.2.2/packer-builder-exoscale_0.2.2_linux_amd64.tar.gz | tar -xvzf - -C $(PWD)/packer/.packer.d/plugins packer-builder-exoscale


.PHONY: check-env
check-env:
ifndef EXOSCALE_API_KEY
	$(error EXOSCALE_API_KEY environment variable must be set)
endif
ifndef EXOSCALE_API_SECRET
	$(error EXOSCALE_API_SECRET environment variable must be set)
endif