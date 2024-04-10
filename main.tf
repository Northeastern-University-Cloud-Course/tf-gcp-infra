provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project
}

terraform {
  required_providers {
    google-beta = {
      source = "hashicorp/google-beta"
      version = "5.24.0"
    }
  }
}

provider "google-beta" {
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
  name            = var.webapp_route.name
  dest_range      = var.webapp_route.dest_range
  network         = google_compute_network.vpc.id
  next_hop_gateway = var.webapp_route.next_hop_gateway
  priority        = var.webapp_route.priority
  tags            = var.webapp_route.tags
}



resource "google_compute_region_instance_template" "vm_template" {
  disk {
    auto_delete = var.boot_disk.auto_delete
    device_name = var.boot_disk.device_name

    disk_encryption_key {
      kms_key_self_link = google_kms_crypto_key.vm_key.id
    }
    source_image = var.initialize_params.image
    disk_size_gb = var.initialize_params.size
    type  = var.initialize_params.type
    mode = var.boot_disk.mode
  }

  metadata = {
    db_user     = google_sql_user.users.name
    db_password = random_password.password.result
    db_host     = google_sql_database_instance.main.first_ip_address 
  }
  metadata_startup_script = "${file("startup-script.sh")}"

  can_ip_forward      = var.vm_instance.can_ip_forward
  labels = {
    goog-ec-src = var.vm_instance.label
  }
  machine_type = var.vm_instance.machine_type
  name         = var.vm_instance.name

  network_interface {
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
    email  = google_service_account.vm_default.email
    scopes = var.service_account.scopes
  }
  shielded_instance_config {
    enable_integrity_monitoring = var.shielded_instance_config.enable_integrity_monitoring
    enable_secure_boot          = var.shielded_instance_config.enable_secure_boot
    enable_vtpm                 = var.shielded_instance_config.enable_vtpm
  }
  tags = var.vm_instance.tags
  region = var.region
}

resource "google_compute_health_check" "default" {
  name               = var.health_check.name
  check_interval_sec = var.health_check.check_interval_sec
  timeout_sec        = var.health_check.timeout_sec
  healthy_threshold  = var.health_check.healthy_threshold
  unhealthy_threshold = var.health_check.unhealthy_threshold

  http_health_check {
    port = var.health_check.port
    request_path = var.health_check.request_path
  }
}

resource "google_compute_region_autoscaler" "default" {
  name   = var.autoscaler.name
  region = var.region
  target = google_compute_region_instance_group_manager.default.id

  depends_on = [ 
    google_compute_region_instance_group_manager.default
   ]

  autoscaling_policy {
    max_replicas    = var.autoscaler.max
    min_replicas    = var.autoscaler.min
    cooldown_period = var.autoscaler.cooldown
    cpu_utilization {
      target = var.autoscaler.target
    }
  }
}

resource "google_compute_region_instance_group_manager" "default" {
  name = var.group_manager.name
  base_instance_name = var.group_manager.base_name
  region = var.region

  version {
    name              = var.group_manager.version
    instance_template = google_compute_region_instance_template.vm_template.self_link
  }
 
  named_port {
    name = var.group_manager.port_name
    port = var.group_manager.port
  }
  auto_healing_policies {
    health_check      = google_compute_health_check.default.id
    initial_delay_sec = var.group_manager.delay
  }

}


resource "google_compute_managed_ssl_certificate" "default" {
  name    = var.ssl.name
  managed {
    domains = var.ssl.domain
  }
}

resource "google_compute_backend_service" "default" {
  name        = var.backend.name
  port_name   = var.backend.port_name
  protocol    = var.backend.protocol
  timeout_sec = var.backend.timeout

  backend {
    group = google_compute_region_instance_group_manager.default.instance_group
  }

  health_checks = [google_compute_health_check.default.id]
}

resource "google_compute_url_map" "default" {
  name        = var.url
  default_service = google_compute_backend_service.default.id
}

resource "google_compute_target_https_proxy" "default" {
  name             = var.https
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
}

resource "google_compute_global_forwarding_rule" "https" {
  name       = var.forwarding_rule.name
  target     = google_compute_target_https_proxy.default.id
  port_range = var.forwarding_rule.port
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
  source_ranges = [google_compute_global_forwarding_rule.https.ip_address, "35.191.0.0/16", "130.211.0.0/22"]
}

resource "google_compute_global_address" "default" {
  provider     = google
  project      = var.project
  name         = var.global_address.name
  address_type = var.global_address.address_type
  purpose      = var.global_address.purpose
  prefix_length = var.global_address.prefix_length
  network      = google_compute_network.vpc.self_link
}


resource "google_service_networking_connection" "my_service_connection" {
  network = google_compute_network.vpc.id
  service = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.default.name]
}


resource "google_sql_database_instance" "main" {
  name             = var.db_inst.name
  database_version = var.db_inst.database_version
  region           = var.db_inst.region
  deletion_protection = false
  encryption_key_name = google_kms_crypto_key.cloudsql_key.id
  depends_on = [ google_service_networking_connection.my_service_connection ]

  settings {
    
    tier = var.db_sett.tier
    availability_type = var.db_sett.availability_type
    disk_autoresize  = var.db_sett.disk_autoresize
    disk_type        = var.db_sett.disk_type
    disk_size        = var.db_sett.disk_size
    
    backup_configuration {
      enabled = true
      binary_log_enabled = true
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.self_link
    }

    
    # service_account = 
  }
}

resource "google_sql_database" "database" {
  name     = var.database
  instance = google_sql_database_instance.main.name
}

resource "random_password" "password" {
  length           = var.password.length
  special          = var.password.special
  override_special = var.password.override_special
}

resource "google_sql_user" "users" {
  name     = var.users
  instance = google_sql_database_instance.main.name
  password = random_password.password.result
}


resource "google_dns_record_set" "my_record" {
  name    = var.dns.name
  type    = var.dns.type
  ttl     = var.dns.ttl
  managed_zone = var.dns.managed_zone
  rrdatas = [google_compute_global_forwarding_rule.https.ip_address]
}

resource "google_service_account" "vm_default"{
  account_id = var.serv_acc.account_id
  display_name = var.serv_acc.display_name
}
resource "google_project_iam_binding" "iam_binding_admin"{
  project = var.project
  role = var.role_logging

  members = [ 
    "serviceAccount:${google_service_account.vm_default.email}"
   ]
}
resource "google_project_iam_binding" "iam_binding_metric"{
  project = var.project
  role = var.role_metrics

  members = [ 
    "serviceAccount:${google_service_account.vm_default.email}"
  ]
}

# Create a Pub/Sub Topic
resource "google_pubsub_topic" "topic" {
  name = "verify_email"
}

# Create a Pub/Sub Subscription
resource "google_pubsub_subscription" "subscription" {
  name  = "sub"
  topic = google_pubsub_topic.topic.name

  ack_deadline_seconds = 20
}

resource "google_storage_bucket" "source_code_bucket" {
  name     = "source-code-cloud-bucket-547"
  location = var.region
  encryption {
    default_kms_key_name = google_kms_crypto_key.storage_key.id
  }
}

resource "google_storage_bucket_object" "source_code_object" {
  name   = "source-code-bucket-object"
  bucket = google_storage_bucket.source_code_bucket.name
  source = "/Users/sandeshreddy/Downloads/cloud_func.zip"
}

resource "google_vpc_access_connector" "vpc_connector" {
  name          = "my-vpc-connector"
  project       = var.project
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.1.0.0/28"
}

# Create the Cloud Function
resource "google_cloudfunctions_function" "example_function" {
  name                  = "PubSubFunction"
  description           = "My Cloud Function"
  runtime               = "java17"
  region                = var.region
  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.source_code_bucket.name
  source_archive_object = google_storage_bucket_object.source_code_object.name
  entry_point           = "gcfv2pubsub.PubSubFunction"
  
  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.topic.name
  }
  vpc_connector = google_vpc_access_connector.vpc_connector.id

  environment_variables = {
    DB_USER            = google_sql_user.users.name
    DB_PASSWORD        = random_password.password.result
    DB_NAME            = google_sql_database.database.name
    DB_HOST            = google_sql_database_instance.main.first_ip_address
    MAILGUN_API_KEY    = var.mailgun_api_key
    MAILGUN_DOMAIN     = var.mailgun_domain
  }

  service_account_email = google_service_account.vm_default.email
}

# IAM policy for Cloud Functions
resource "google_project_iam_member" "cloud_function_iam" {
  project = var.project
  role    = "roles/cloudfunctions.developer"
  member  = "serviceAccount:${google_service_account.vm_default.email}"
}

# IAM policy for Pub/Sub Subscription
resource "google_pubsub_subscription_iam_binding" "subscription_iam" {
  subscription = google_pubsub_subscription.subscription.name
  role         = "roles/pubsub.subscriber"

  members = [
    "serviceAccount:${google_service_account.vm_default.email}",
  ]
}

# IAM policy for Cloud Pub/Sub Topic
resource "google_pubsub_topic_iam_binding" "topic_iam" {
  topic = google_pubsub_topic.topic.name
  role  = "roles/pubsub.publisher"

  members = [
    "serviceAccount:${google_service_account.vm_default.email}",
  ]
}

resource "google_project_service_identity" "sql_sa" {
  provider = google-beta
  project = var.project
  service = "sqladmin.googleapis.com"
}

data "google_project" "project" {}


resource "google_kms_crypto_key_iam_binding" "kms_vm_binding" {
  crypto_key_id = google_kms_crypto_key.vm_key.id
  role          = "roles/owner"

  members = [
    "serviceAccount:service-${data.google_project.project.number}@compute-system.iam.gserviceaccount.com"
  ]
}

resource "google_kms_crypto_key_iam_binding" "kms_storage_binding" {
  crypto_key_id = google_kms_crypto_key.storage_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${data.google_storage_project_service_account.storage_account.email_address}"
  ]
}

resource "google_kms_key_ring_iam_binding" "ring_rule" {
  key_ring_id = google_kms_key_ring.key_ring.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${google_service_account.vm_default.email}"
  ]
}

resource "google_kms_crypto_key_iam_binding" "kms_sql_binding" {
  crypto_key_id = google_kms_crypto_key.cloudsql_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${google_project_service_identity.sql_sa.email}"
  ]
}

data "google_storage_project_service_account" "storage_account" {}

resource "google_kms_key_ring" "key_ring" {
  name     = "cloud-dev2-key-ring"
  location = var.region 
}

resource "google_kms_crypto_key" "vm_key" {
  name            = "vm-key"
  key_ring        = google_kms_key_ring.key_ring.id
  rotation_period = "2592000s" 

  
}

resource "google_kms_crypto_key" "cloudsql_key" {
  name            = "cloudsql-key"
  key_ring        = google_kms_key_ring.key_ring.id
  rotation_period = "2592000s" 

  
}

resource "google_kms_crypto_key" "storage_key" {
  name            = "storage-key"
  key_ring        = google_kms_key_ring.key_ring.id
  rotation_period = "2592000s" 

  
}