# Autoscalable Kubernetes cluster at Exoscale, using Packer and Terraform

![Kubernetes](.documentation/images/kubernetes-logo.svg)

## TL;DR

The purpose of this repository is to install [Kubernetes](https://kubernetes.io) 1.20 with support for cluster autoscaling.
The cloud provider used is [Exoscale](https://www.exoscale.com). However this repository can be adapted to other providers.

The container runtime is [CRI-O](https://cri-o.io).
The network is managed by [Calico](https://www.projectcalico.org). It was chosen for its ease of installation (by default), and its polyvalence. Indeed, its performance is excellent in most use-cases compared to other alternatives, while keeping a reasonable resource consumption.

Two steps are involved in the installation of the cluster:

* The creation of a system image using [Packer](https://www.packer.io) and the Exoscale plugin. This image contains the packages for Kubernetes, [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/) and CRI-O.
* The provisioning of the cluster using [Terraform](https://www.terraform.io) and the Exoscale provider (blazingly fast!)

## Explanations

This repository is explained in depth (in French) here :

* [Partie 1 : Préparation du dépôt](https://easyadmin.tech/tutoriel-comment-deployer-kubernetes-chez-exoscale-avec-packer-et-terraform-preparation-depot)
* [Partie 2 : Création d'une image de machine virtuelle](https://easyadmin.tech/tutoriel-comment-deployer-kubernetes-chez-exoscale-avec-packer-et-terraform-creation-image-machine-virtuelle)
* [Partie 3 : Création de l'infrastructure](https://easyadmin.tech/tutoriel-comment-deployer-kubernetes-chez-exoscale-avec-packer-et-terraform-creation-infrastructure)

## Installation

You must have docker installed locally in order to make the work done. Packer and Terraform are run using containers.

### First step: building the system image

```shell
# Download the Exoscale plugin for packer
make packer.deps

# Build and upload Kubernetes base system image in your Exoscale account's custom templates
# This step can take up to 10~15mn
make packer.build
```

### Update terraform variables

Next, you must create a `terraform/terraform.tfvars` file containing the template id you just built with packer (visible in the previous command output, or in the Exoscale interface).

```hcl
control_plane_template_id = "..."
node_template_id = "..."
```

### Build the final infrastructure

```shell
# Initialize terraform
make terraform.init

# Create the Kubernetes cluster
# This process usually takes 1 to 2 minutes to complete
make terraform.apply
```

## Connection to control-plane

```shell
# After provisioning your cluster
make ssh-cp
```

After connecting to the control-plane, you can play with kubectl.

# Infrastructure design

## Network

The communication between nodes is done via a managed private network (`exoscale_network` in Terraform).

All virtual machines are protected by a firewall which allows access to the necessary ports from the public network (`exoscale_security_group` and `exoscale_security_group_rules`). The default policy is to block all other connections (as in the Exoscale platform).

* The control-plane server allows inbound connections on port `22` (ssh) only.
* Workers allow incoming connections on ports `30000` to `32767` (TCP and UDP). Those ports match Kubernetes' NodePort range and allow the implementation of various `Services`.

* Outgoing connections are allowed from all virtual machines to the following ports:
TCP: `22` (SSH), `80` (HTTP), `443` (HTTPS), `11371` (HKP)
UDP: `53` (DNS)

## Virtual Machines

The Kubernetes cluster consists in a single virtual machine for the control-plane (`exoscale_compute` in Terraform). This machine hosts the Kubernetes API server along with Etcd.

Workers are implemented as an instance pool (`exoscale_instance_pool` in Terraform). This pool is configured to contain a single agent upon creation of the infrastructure. The autoscaler cluster will automatically increase the size of the instance pool as soon your workloads need it.

The control-plane server initializes its own services via a `kubeadm init` command.
New worker nodes (belonging to the instance pool) will automatically connect to the control-plane server in order to join the Kubernetes cluster (via `kubeadm`) on first boot.

The initialization of each virtual machine is controlled by cloud-init at the first instance startup.
See cloud-init [here for the control-plane](terraform/templates/control-plane/cloud-init.yaml), and [here for the workers](terraform/templates/nodes/cloud-init.yaml)

# Limitations

* Be careful when using this script in production (the cluster autoscaler has not been extensively tested in this configuration). **Use at your own risks!**

# References

* Kubernetes
  * [Website](https://kubernetes.io)
  * [Documentation](https://kubernetes.io/docs/home/)
* CRI-O
  * [Website](https://cri-o.io)
* Calico
  * [Website](https://www.projectcalico.org)
* Exoscale
  * [Website](https://www.exoscale.com)
  * [Documentation](https://community.exoscale.com)
  * [Cluster autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/exoscale)
* Packer
  * [Website](https://www.packer.io)
  * [Documentation](https://www.packer.io/docs)
  * [Creating Custom Templates Using Packer](https://www.exoscale.com/syslog/creating-custom-templates-using-packer/)
* Terraform
  * [Website](https://www.terraform.io)
  * [Documentation](https://www.terraform.io/docs/index.html)
  * [Exoscale Provider](https://registry.terraform.io/providers/exoscale/exoscale/latest/docs)

# Author

Philippe Chepy

* Github: [@PhilippeChepy](https://github.com/PhilippeChepy)
* LinkedIn: [@philippe-chepy](https://www.linkedin.com/in/philippe-chepy/)
* Website [EasyAdmin](https://easyadmin.tech)
