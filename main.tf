provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project
}

resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
  delete_default_routes_on_create = true
  routing_mode            = var.routing_mode
}

resource "google_compute_subnetwork" "subnets" {
  for_each      = { for subnet in var.subnets : subnet.subnet_name => subnet }
  name          = each.value.subnet_name
  ip_cidr_range = each.value.ip_cidr_range
  region        = each.value.subnet_region
  network       = google_compute_network.vpc.id
  private_ip_google_access = true
}

resource "google_compute_route" "webapp_route" {
  name            = "webapp-route"
  dest_range      = "0.0.0.0/0"
  network         = google_compute_network.vpc.id
  next_hop_gateway = "default-internet-gateway"
  priority        = 1000
  tags            = ["webapp"]
}

resource "google_compute_instance" "vm_instance" {
  boot_disk {
    auto_delete = var.boot_disk.auto_delete
    device_name = var.boot_disk.device_name

    initialize_params {
      image = var.initialize_params.image
      size  = var.initialize_params.size
      type  = var.initialize_params.type
    }

    mode = var.boot_disk.mode
  }

  metadata = {
    db_user     = google_sql_user.users.name
    db_password = random_password.password.result
    db_host     = google_sql_database_instance.main.first_ip_address 
  }
  metadata_startup_script = "${file("startup-script.sh")}"

  can_ip_forward      = var.vm_instance.can_ip_forward
  deletion_protection = var.vm_instance.deletion_protection
  enable_display      = var.vm_instance.enable_display

  labels = {
    goog-ec-src = var.vm_instance.label
  }

  machine_type = var.vm_instance.machine_type
  name         = var.vm_instance.name

  network_interface {
    access_config {
      network_tier = var.network_interface.network_tier
    }

    queue_count = var.network_interface.queue_count
    stack_type  = var.network_interface.stack_type
    subnetwork  = var.network_interface.subnetwork
  }

  scheduling {
    automatic_restart   = var.scheduling.automatic_restart
    on_host_maintenance = var.scheduling.on_host_maintenance
    preemptible         = var.scheduling.preemptible
    provisioning_model  = var.scheduling.provisioning_model
  }

  service_account {
    email  = var.service_account.email
    scopes = var.service_account.scopes
  }

  shielded_instance_config {
    enable_integrity_monitoring = var.shielded_instance_config.enable_integrity_monitoring
    enable_secure_boot          = var.shielded_instance_config.enable_secure_boot
    enable_vtpm                 = var.shielded_instance_config.enable_vtpm
  }

  tags = var.vm_instance.tags
  zone = var.vm_instance.zone
}
resource "google_compute_firewall" "rules" {
  project     = var.project
  name        = var.firewall_rules.name
  network     = var.vpc_name
  description = var.firewall_rules.description

  allow {
    protocol  = var.firewall_rules_allow.protocol
    ports     = var.firewall_rules_allow.ports
  }
  target_tags = var.firewall_rules.target_tags
  source_ranges = var.firewall_rules.source
}

resource "google_compute_global_address" "default" {
  provider     = google
  project      = var.project
  name         = "global-psconnect-ip2"
  address_type = "INTERNAL"
  purpose      = "VPC_PEERING"
  prefix_length = 16
  network      = google_compute_network.vpc.self_link
}

# resource "google_compute_network_peering" "peering" {
#   name         = "my-network-peering"
#   network      = google_compute_network.vpc.self_link
#   peer_network = "https://www.googleapis.com/compute/v1/projects/${var.project}/global/networks/${var.vpc_name}"
# }

resource "google_service_networking_connection" "my_service_connection" {
  network = google_compute_network.vpc.id
  service = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.default.name]
}



resource "google_sql_database_instance" "main" {
  name             = "main-instance"
  database_version = "MYSQL_5_7"
  region           = "us-west1"
  deletion_protection = false
  
  depends_on = [ google_service_networking_connection.my_service_connection ]

  settings {
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    tier = "db-f1-micro"
    availability_type = "REGIONAL"
    disk_autoresize  = true
    disk_type        = "pd-ssd"
    disk_size        = 100
    

    # database_flags {
    #   name  = "log_bin_trust_function_creators"
    #   value = "on"
    # }

    backup_configuration {
      enabled = true
      binary_log_enabled = true
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.self_link
    }

  
  }

}

resource "google_sql_database" "database" {
  name     = "webapp"
  instance = google_sql_database_instance.main.name
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_sql_user" "users" {
  name     = "webapp"
  instance = google_sql_database_instance.main.name
  password = random_password.password.result
}