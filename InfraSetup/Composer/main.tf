# main.tf

locals {
  project = "playpen-1ddb2b"
  region = "europe-west2"
}

# Configure the Google provider
provider "google" {
  project     = local.project
  region      = "europe-central2"
  credentials = "playpen-1ddb2b-c9584fd6ea6f.json"

}

# Enable the Cloud Composer API
resource "google_project_service" "composer_api" {
  provider           = google
  project            = local.project
  service            = "composer.googleapis.com"
  disable_on_destroy = false
}

# Create a custom service account
resource "google_service_account" "composer_service_account" {
  account_id   = "composer-compute"
  display_name = "Custom Composer Service Account"
  project      = local.project
}


# Assign roles to the service account
resource "google_project_iam_member" "composer_user" {
  project = local.project  # Replace with your project ID
  role    = "roles/composer.user"
  member  = "serviceAccount:${google_service_account.composer_service_account.email}"
}

resource "google_project_iam_member" "composer_worker" {
  project = local.project
  role    = "roles/composer.worker"
  member  = "serviceAccount:${google_service_account.composer_service_account.email}"
}

resource "google_project_iam_member" "storage_object_user" {
  project = local.project
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.composer_service_account.email}"
}

resource "google_project_iam_member" "storage_object_viewer" {
  project = local.project
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.composer_service_account.email}"
}


# Create the Cloud Composer environment
resource "google_composer_environment" "composer_environment" {
  name   = "comp3"
  region = "europe-central2"
  config {
    software_config {
      image_version = "composer-3-airflow-2.7.3-build.6"
    }

    workloads_config {
      scheduler {
        cpu        = 0.5
        memory_gb  = 2
        storage_gb = 1
        count      = 1
      }
      web_server {
        cpu        = 0.5
        memory_gb  = 2
        storage_gb = 1
      }
      worker {
        cpu        = 0.5
        memory_gb  = 2
        storage_gb = 10
        min_count  = 1
        max_count  = 3
      }
    }
    node_config {
      network         = "projects/playpen-1ddb2b/global/networks/eu-comp1"
      subnetwork      = "projects/playpen-1ddb2b/regions/europe-central2/subnetworks/eu-comp1"
      service_account = google_service_account.composer_service_account.email

    }
  }
}

# Create Bucket and required forlder for Cloudbuild of Docker Image
resource "google_storage_bucket" "cloudbuild" {
  name     = "${local.project}_cloudbuild"
  location = local.region
}

resource "google_storage_bucket_object" "source_folder" {
  name    = "source/"  # Note the trailing slash—it makes it a folder
  content = " "  # Content is ignored but should be non-empty
  bucket  = google_storage_bucket.cloudbuild.name
}


# Enable Artifact API
resource "google_project_service" "enable_artifact_api" {
  project = local.project
  service = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}


# Create Artifactory Repository to Store Docker Images
resource "google_artifact_registry_repository" "cloud_run" {
  project = local.project
  location = local.region
  repository_id = "cloud-run-source-deploy"
  format = "DOCKER"  # You can choose other formats like "APT", "MAVEN", etc.
}
