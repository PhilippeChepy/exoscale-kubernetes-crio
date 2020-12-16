variable "api_key" {
}

variable "api_secret" {
}

variable "zone" {
}

variable "name" {
  default = "kubernetes"
}

variable "private_net_start_ip" {
  default = "10.0.0.10"
}

variable "private_net_end_ip" {
  default = "10.0.0.253"
}

variable "private_net_netmask" {
  default = "255.255.255.0"
}

variable  "control_plane_ip_address" {
  default = "10.0.0.1"
}

variable "control_plane_template_id" {
}

variable "control_plane_size" {
    default = "Medium"
}

variable "control_plane_disk_size" {
    default = "25"
}

variable "node_template_id" {
}

variable "node_service_offering" {
    default = "medium"
}

variable "node_disk_size" {
    default = "25"
}
