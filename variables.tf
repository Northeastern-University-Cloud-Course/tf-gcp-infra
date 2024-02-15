variable "credentials_file" {
  description = "Path to the GCP credentials file"
}

variable "project" {
  description = "The GCP project ID"
}

variable "region" {
  description = "The region where to create the resources"
}

variable "vpc_name" {
  description = "Name of the VPC"
}

variable "subnets" {
  description = "A list of subnets to be created"
  type = list(object({
    subnet_name   = string
    ip_cidr_range = string
    subnet_region = string
  }))
}
