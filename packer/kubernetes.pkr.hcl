variable "api_key" {
}

variable "api_secret" {
}

variable "zone" {
}

source "exoscale" "base" {
    api_key = var.api_key
    api_secret = var.api_secret
    instance_template = "Linux Ubuntu 20.04 LTS 64-bit"
    instance_disk_size = 10
    template_zone = var.zone
    template_name = "Kubernetes 1.20 - Linux Ubuntu 20.04 LTS 64-bit"
    template_username = "ubuntu"
    ssh_username = "ubuntu"
}

build {
    sources = ["source.exoscale.base"]

    provisioner "file" {
        source = "/root/kubernetes/etc/default/kubelet"
        destination = "/tmp/etc_default_kubelet"
    }

    provisioner "file" {
        source = "/root/kubernetes/etc/modprobe.d/kubernetes-blacklist.conf"
        destination = "/tmp/etc_modprobe.d_kubernetes-blacklist.conf"
    }

    provisioner "file" {
        source = "/root/kubernetes/etc/modules-load.d/cri-o.conf"
        destination = "/tmp/etc_modules-load.d_cri-o.conf"
    }

    provisioner "file" {
        source = "/root/kubernetes/etc/netplan/eth1.yaml"
        destination = "/tmp/etc_netplan_eth1.yaml"
    }

    provisioner "file" {
        source = "/root/kubernetes/etc/networkd-dispatcher/routable.d/50-ifup-hooks"
        destination = "/tmp/etc_networkd-dispatcher_routable.d_50-ifup-hooks"
    }

    provisioner "file" {
        source = "/root/kubernetes/etc/sysctl.d/99-kubernetes-cri.conf"
        destination = "/tmp/etc_sysctl.d_99-kubernetes-cri.conf"
    }

    provisioner "file" {
        source = "/root/kubernetes/usr/local/bin/exo-set-worker-node"
        destination = "/tmp/usr_local_bin_exo-set-worker-node"
    }

    # update system and install required components for Kubernetes
    provisioner "shell" {
        environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
        inline = [
            # fix most warnings from apt during image preparation
            "echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections",

            # run unattended upgrade and wait for it completion
            "sudo systemd-run --property='After=apt-daily.service apt-daily-upgrade.service' --wait /bin/true",

            # update system
            "sudo apt-get update",
            "sudo apt-get upgrade -y",
            "sudo apt-get install -y dialog apt-utils curl gnupg2 software-properties-common apt-transport-https ca-certificates",

            # Network configuration
            "sudo mv /tmp/etc_netplan_eth1.yaml /etc/netplan/eth1.yaml",
            "sudo mv /tmp/etc_networkd-dispatcher_routable.d_50-ifup-hooks /etc/networkd-dispatcher/routable.d/50-ifup-hooks",
            "sudo chown root:root /etc/networkd-dispatcher/routable.d/50-ifup-hooks",
            "sudo chmod 0700 /etc/networkd-dispatcher/routable.d/50-ifup-hooks",

            # Helper script
            "sudo mv /tmp/usr_local_bin_exo-set-worker-node /usr/local/bin/exo-set-worker-node",
            "sudo chown root:root /usr/local/bin/exo-set-worker-node",
            "sudo chmod 0700 /usr/local/bin/exo-set-worker-node",

            # custom Kubernetes CRI & network configuration
            "sudo mv /tmp/etc_sysctl.d_99-kubernetes-cri.conf /etc/sysctl.d/99-kubernetes-cri.conf",
            "sudo mv /tmp/etc_modules-load.d_cri-o.conf /etc/modules-load.d/cri-o.conf",
            "sudo mv /tmp/etc_default_kubelet /etc/default/cri-o.conf",
            "sudo mv /tmp/etc_modprobe.d_kubernetes-blacklist.conf /etc/modprobe.d/kubernetes-blacklist.conf",

            # install CRI-O (as a replacement for Docker)
            "curl -s https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_20.04/Release.key | sudo apt-key add -",
            "curl -s https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/1.19/xUbuntu_20.04/Release.key | sudo apt-key add -",
            "sudo apt-add-repository \"deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_20.04 /\"",
            "sudo apt-add-repository \"deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/1.19/xUbuntu_20.04/ /\"",

            "sudo apt-get update",
            "sudo apt-get install -y cri-o cri-o-runc cri-tools cri-o-runc runc",
            
            "sudo systemctl daemon-reload",
            "sudo systemctl start crio",
            "sudo systemctl enable crio",

            # install Kubernetes and Kubeadm components
            "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -",
            "sudo apt-add-repository \"deb https://apt.kubernetes.io/ kubernetes-xenial main\"",

            "sudo apt-get update",
            "sudo apt-get install -y kubectl=1.20.0-00 kubeadm=1.20.0-00 kubelet=1.20.0-00",

            # preload Kubernetes container images
            "sudo kubeadm config images pull",

            # removed because of conflicts with (late) calico installation
            "sudo rm /etc/cni/net.d/100-crio-bridge.conf"
        ]
    }
}