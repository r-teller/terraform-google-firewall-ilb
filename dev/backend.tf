provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

terraform {
  required_providers {
    google      = "~> 3.78.0"
    google-beta = "~> 3.78.0"
  }

  # The storage bucket needs to be created before it can be used here in the backend, when creating the bucket via terraform comment
  # out the below section first and do terraform init and terraform apply and then once the bucket is created you can uncomment
  # and rerun terraform init and it will move the state file from the local folder to the GCS bucket
  # Note: bucket below has to be manually created before terraform init
  # backend "gcs" {
  #   bucket = "[bucket-name]"
  #   prefix = "envs/[env]/[project]/[region]"
  # }
}