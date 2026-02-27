# EL-Modras Infrastructure
# Terraform configuration for Google Cloud deployment

terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  
  # Uncomment to use Cloud Storage for state
  # backend "gcs" {
  #   bucket = "el-modras-terraform-state"
  #   prefix = "terraform/state"
  # }
}

# Variables
variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "Google Cloud region"
  type        = string
  default     = "us-central1"
}

variable "gemini_api_key" {
  description = "Gemini API Key"
  type        = string
  sensitive   = true
}

# Provider configuration
provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
    "firestore.googleapis.com",
    "aiplatform.googleapis.com",
    "storage.googleapis.com"
  ])
  
  project = var.project_id
  service = each.value
  
  disable_on_destroy = false
}

# Secret Manager - Gemini API Key
resource "google_secret_manager_secret" "gemini_api_key" {
  secret_id = "gemini-api-key"
  project   = var.project_id
  
  replication {
    auto {}
  }
  
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "gemini_api_key" {
  secret      = google_secret_manager_secret.gemini_api_key.id
  secret_data = var.gemini_api_key
}

# Cloud Storage bucket for assets
resource "google_storage_bucket" "assets" {
  name          = "${var.project_id}-assets"
  location      = var.region
  force_destroy = false
  
  uniform_bucket_level_access = true
  
  depends_on = [google_project_service.apis]
}

# Firestore database
resource "google_firestore_database" "main" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"
  
  depends_on = [google_project_service.apis]
}

# Cloud Run service
resource "google_cloud_run_v2_service" "backend" {
  name     = "el-modras-backend"
  location = var.region
  
  template {
    containers {
      image = "gcr.io/${var.project_id}/el-modras-backend:latest"
      
      resources {
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
      }
      
      env {
        name  = "ENVIRONMENT"
        value = "production"
      }
      
      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      
      env {
        name = "GEMINI_API_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.gemini_api_key.secret_id
            version = "latest"
          }
        }
      }
      
      ports {
        container_port = 8080
      }
    }
    
    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
    
    timeout = "300s"
  }
  
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
  
  depends_on = [
    google_project_service.apis,
    google_secret_manager_secret_version.gemini_api_key
  ]
}

# IAM - Allow unauthenticated access to Cloud Run
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.backend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# IAM - Allow Cloud Run to access Secret Manager
resource "google_secret_manager_secret_iam_member" "cloud_run" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.gemini_api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

# Data source for project info
data "google_project" "project" {
  project_id = var.project_id
}

# Outputs
output "backend_url" {
  description = "Cloud Run service URL"
  value       = google_cloud_run_v2_service.backend.uri
}

output "storage_bucket" {
  description = "Cloud Storage bucket name"
  value       = google_storage_bucket.assets.name
}

output "project_id" {
  description = "Google Cloud Project ID"
  value       = var.project_id
}
