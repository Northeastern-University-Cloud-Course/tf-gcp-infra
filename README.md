# tf-gcp-infra

## Setting up Infrastructure with Terraform

This guide will walk you through the process of setting up infrastructure on Google Cloud Platform (GCP) using Terraform. We'll create a Virtual Private Cloud (VPC) network with two subnetworks and a route for internet traffic to a web application subnet.

## Prerequisites

Before you begin, make sure you have the following prerequisites installed and configured:

1. **Terraform**: Install Terraform by following the instructions [here](https://learn.hashicorp.com/tutorials/terraform/install-cli).
2. **Google Cloud Platform Account**: Create a GCP account if you don't have one already, and set up a project. Ensure you have the necessary permissions to create resources.
3. **Service Account Key**: Create a service account key with the required permissions for Terraform to manage resources in your GCP project. Download the JSON key file and keep it secure.

## Steps

Follow these steps to set up the infrastructure using Terraform:

### 1. Clone the Repository

Clone this repository to your local machine:

```bash
git clone <repository-url>
cd <repository-name>
```

### 2. Set up Variables

Create a `variables.tf` file to specify values for the required variables. You can use the following template:

```hcl
service_key_path = "/path/to/your/service-account-key.json"
project_name     = "your-project-name"
```

### 3. Initialize Terraform

Initialize Terraform in the project directory:

```bash
terraform init
```

### 4. Review and apply changes

Review the Terraform plan to ensure it matches your expectations:

```bash
terraform plan
```

### 5. Create Infrastructure

if everything looks good, apply the changes to create the infrastructure:

```bash
terraform apply
```