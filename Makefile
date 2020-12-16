# Packer
PACKER_IMAGE = hashicorp/packer:1.6.5

PACKER = docker run -it --rm \
	-v $(PWD)/packer/:/root \
	--workdir /root \
	$(PACKER_IMAGE)


# Terraform
TERRAFORM_IMAGE = hashicorp/terraform:0.13.5

TERRAFORM = docker run -it --rm \
	-v $(PWD)/terraform/:/root \
	--workdir /root \
	$(TERRAFORM_IMAGE)

# Build settings
ZONE ?= "ch-dk-2"

.PHONY: packer.build
packer.build: check-env
	$(PACKER) build -var api_key="$(EXOSCALE_API_KEY)" -var api_secret="$(EXOSCALE_API_SECRET)" -var zone=$(ZONE) kubernetes.pkr.hcl

.PHONY: packer.deps
packer.deps:
	mkdir -p $(PWD)/packer/.packer.d/plugins && wget -qO - https://github.com/exoscale/packer-builder-exoscale/releases/download/v0.2.2/packer-builder-exoscale_0.2.2_linux_amd64.tar.gz | tar -xvzf - -C $(PWD)/packer/.packer.d/plugins packer-builder-exoscale

.PHONY: terraform.init
terraform.init: check-env
	$(TERRAFORM) init -var api_key="$(EXOSCALE_API_KEY)" -var api_secret="$(EXOSCALE_API_SECRET)" -var zone=$(ZONE)

.PHONY: terraform.apply
terraform.apply: check-env
	$(TERRAFORM) apply -var api_key="$(EXOSCALE_API_KEY)" -var api_secret="$(EXOSCALE_API_SECRET)" -var zone=$(ZONE)

.PHONY: terraform.destroy
terraform.destroy: check-env
	$(TERRAFORM) destroy -var api_key="$(EXOSCALE_API_KEY)" -var api_secret="$(EXOSCALE_API_SECRET)" -var zone=$(ZONE)

.PHONY: check-env
check-env:
ifndef EXOSCALE_API_KEY
	$(error EXOSCALE_API_KEY environment variable must be set)
endif
ifndef EXOSCALE_API_SECRET
	$(error EXOSCALE_API_SECRET environment variable must be set)
endif