
output control_plane_public_ip {
    value = exoscale_compute.control_plane.ip_address
}

output provisioning_private_key {
    value = exoscale_ssh_keypair.provisioning_key.private_key
}