variable "credentials_file" {
  description = "Path to the GCP credentials file"
}

variable "project" {
  description = "The GCP project ID"
}

variable "region" {
  description = "The region where to create the resources"
}

variable "zone" {
  description = "The zone where to create the resources"
}

variable "routing_mode" {
  description = "The routing where to create the resources"
}

variable "vpc_name" {
  description = "Name of the VPC"
}
variable "firewall_rules" {
  type = object({
    name = string
    description = string
    target_tags = list(string)
    source = list(string)
  })
}

variable "firewall_rules_allow" {
  type = object({
    protocol = string
    ports = list(string)
  })
}

variable "subnets" {
  description = "A list of subnets to be created"
  type = list(object({
    subnet_name   = string
    ip_cidr_range = string
    subnet_region = string
  }))
}


variable "boot_disk" {
  type = object({
    auto_delete = bool
    device_name = string
    mode = string
  })
}
variable "initialize_params" {
  type = object({
    image = string
    size = number
    type = string
  })
}
variable "vm_instance" {
  type = object({
    can_ip_forward = bool
    deletion_protection = bool
    enable_display = bool

    label = string

    machine_type = string
    name = string

    tags = list(string)
    zone = string
  })
}

variable "network_interface" {
  type = object({
    network_tier = string
    queue_count = number
    stack_type = string
    subnetwork = string
  })
}
variable "scheduling" {
  type = object({
    automatic_restart   = bool
    on_host_maintenance = string
    preemptible         = bool
    provisioning_model  = string
  })
}
variable "service_account" {
  type = object({
    email = string
    scopes = list(string)
  })
}
variable "shielded_instance_config" {
  type = object({
    enable_integrity_monitoring = bool
    enable_secure_boot          = bool
    enable_vtpm                 = bool
  })
}