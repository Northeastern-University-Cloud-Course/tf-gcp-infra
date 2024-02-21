provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project
}

resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
  delete_default_routes_on_create  true
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "subnets" {
  for_each      = { for subnet in var.subnets : subnet.subnet_name => subnet }
  name          = each.value.subnet_name
  ip_cidr_range = each.value.ip_cidr_range
  region        = each.value.subnet_region
  network       = google_compute_network.vpc.id
}

resource "google_compute_route" "webapp_route" {
  name            = "webapp-route"
  dest_range      = "0.0.0.0/0"
  network         = google_compute_network.vpc.id
  next_hop_gateway = "default-internet-gateway"
  priority        = 1000
  tags            = ["webapp"]
}
