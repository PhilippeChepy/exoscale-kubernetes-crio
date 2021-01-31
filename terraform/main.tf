provider exoscale {
  key     = var.api_key
  secret  = var.api_secret

  timeout = 120
}

resource exoscale_ssh_keypair provisioning_key {
  name = var.name
}

resource exoscale_network private_network {
  name = var.name
  display_text = format("private network for %s", var.name)
  zone = var.zone

  start_ip = var.private_net_start_ip
  end_ip = var.private_net_end_ip
  netmask = var.private_net_netmask
}

// control plane security-group
resource exoscale_security_group control_plane_firewall {
  name = format("%s-control-plane", var.name)
  description = format("security group for %s", var.name)
}

resource exoscale_security_group_rules control_plane_firewall_ingress {
  security_group_id = exoscale_security_group.control_plane_firewall.id

  // allow incoming 'ssh'
  ingress {
    protocol  = "TCP"
    ports = [22]
    cidr_list = ["0.0.0.0/0", "::/0"]
  }

  // allow 'ssh', 'http', 'https', and 'hkp'
  egress {
    protocol  = "TCP"
    ports = [22, 80, 443, 11371]
    cidr_list = ["0.0.0.0/0", "::/0"]
  }

  // allow 'dns'
  egress {
    protocol  = "UDP"
    ports = [53]
    cidr_list = ["0.0.0.0/0", "::/0"]
  }
}

// control-plane agent
data template_cloudinit_config control_plane_cloud_init {
  gzip = false
  base64_encode = false

  part {
    filename = "init.cfg"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/templates/control-plane/cloud-init.yaml", {
      kubeadm_configuration = templatefile("${path.module}/templates/control-plane/etc/kubernetes/kubeadmcfg.yaml", {
        pod_subnet = "10.244.0.0/16"
        service_subnet = "10.245.0.0/16"
        dns_domain = "cluster.internal"
        control_plane_private_ip_address = var.control_plane_ip_address
      })
      autoscaler_manifests = templatefile("${path.module}/templates/control-plane/tmp/exoscale-cluster-autoscaler.yaml", {
        exoscale_api_endpoint = base64encode("https://api.exoscale.com/v1")
        exoscale_api_key = base64encode(var.api_key)
        exoscale_api_secret = base64encode(var.api_secret)
      })
    })
  }
}

resource exoscale_compute control_plane {
  zone = var.zone
  template_id = var.control_plane_template_id
  size = var.control_plane_size
  disk_size = var.control_plane_disk_size
  display_name = format("%s-control-plane", var.name)

  key_pair = exoscale_ssh_keypair.provisioning_key.name

  user_data = data.template_cloudinit_config.control_plane_cloud_init.rendered

  affinity_group_ids = []
  security_group_ids = [exoscale_security_group.control_plane_firewall.id]
}

resource exoscale_nic control_plane {
  compute_id = exoscale_compute.control_plane.id
  network_id = exoscale_network.private_network.id
  ip_address = var.control_plane_ip_address
}

// nodes security group
resource exoscale_security_group nodes_firewall {
  name = format("%s-nodes", var.name)
  description = format("security group for %s", var.name)
}

resource exoscale_security_group_rules nodes_firewall_rules {
  security_group_id = exoscale_security_group.nodes_firewall.id

  // allow incoming connections to TCP 'NodePort' services
  ingress {
    protocol  = "TCP"
    ports = ["30000-32767"]
    cidr_list = ["0.0.0.0/0", "::/0"]
  }

  // allow incoming connections to UDP 'NodePort' services
  ingress {
    protocol  = "UDP"
    ports = ["30000-32767"]
    cidr_list = ["0.0.0.0/0", "::/0"]
  }

  // allow 'ssh', 'http', 'https', and 'hkp'
  egress {
    protocol  = "TCP"
    ports = [22, 80, 443, 11371]
    cidr_list = ["0.0.0.0/0", "::/0"]
  }

  // allow 'dns'
  egress {
    protocol  = "UDP"
    ports = [53]
    cidr_list = ["0.0.0.0/0", "::/0"]
  }
}

resource "exoscale_affinity" "nodes_affinity" {
  name = format("%s-nodes", var.name)
  description = format("anti affinity for %s", var.name)
  type = "host anti-affinity"
}

// nodes agents
data template_cloudinit_config nodes_cloud_init {
  gzip = false
  base64_encode = false

  part {
    filename = "init.cfg"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/templates/nodes/cloud-init.yaml", {
      private_key = exoscale_ssh_keypair.provisioning_key.private_key
      control_plane_private_ip_address = var.control_plane_ip_address
    })
  }
}

resource exoscale_instance_pool nodes {
  zone = var.zone
  name = var.name
  
  template_id = var.node_template_id
  
  size = 1
  service_offering = var.node_service_offering
  
  disk_size = var.node_disk_size
  
  description = format("node pool for %s", var.name)
  user_data = data.template_cloudinit_config.nodes_cloud_init.rendered
  key_pair = exoscale_ssh_keypair.provisioning_key.name

  affinity_group_ids = [exoscale_affinity.nodes_affinity.id]
  security_group_ids = [exoscale_security_group.nodes_firewall.id]
  network_ids = [exoscale_network.private_network.id]

  timeouts {
    delete = "10m"
  }
}
