locals {
  runner_name       = "${var.name_prefix}-runner"
  status_name       = "${var.name_prefix}-status"
  runner_script     = "runner/run-minix-validation.sh"
  startup_script    = "runner/startup-runner.sh"
  latest_result_key = "runs/latest/result.json"
}

resource "random_id" "suffix" {
  byte_length = 3
}

resource "google_project_service" "services" {
  for_each = toset([
    "compute.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
    "storage.googleapis.com",
  ])

  service            = each.key
  disable_on_destroy = false
}

resource "google_compute_network" "runner" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.services]
}

resource "google_compute_subnetwork" "runner" {
  name          = "${var.name_prefix}-subnet"
  ip_cidr_range = "10.20.0.0/24"
  network       = google_compute_network.runner.id
  region        = var.region
}

resource "google_compute_router" "runner" {
  name    = "${var.name_prefix}-router"
  network = google_compute_network.runner.id
  region  = var.region
}

resource "google_compute_router_nat" "runner" {
  name                               = "${var.name_prefix}-nat"
  router                             = google_compute_router.runner.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.runner.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_firewall" "iap_ssh" {
  count = var.enable_iap_ssh ? 1 : 0

  name    = "${var.name_prefix}-allow-iap-ssh"
  network = google_compute_network.runner.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.runner_source_ranges
  target_tags   = ["${var.name_prefix}-runner"]
}

resource "google_storage_bucket" "artifacts" {
  name                        = var.artifact_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.services]
}

resource "google_storage_bucket_object" "runner_script" {
  name   = local.runner_script
  bucket = google_storage_bucket.artifacts.name
  source = "${path.module}/../scripts/run-minix-validation.sh"
}

resource "google_storage_bucket_object" "startup_script" {
  name   = local.startup_script
  bucket = google_storage_bucket.artifacts.name
  content = templatefile("${path.module}/startup-runner.sh.tftpl", {
    artifact_bucket  = google_storage_bucket.artifacts.name
    runner_script    = local.runner_script
    minix_image_uri  = var.minix_image_uri
    patch_bundle_uri = var.patch_bundle_uri
  })
}

resource "google_service_account" "runner" {
  account_id   = "${var.name_prefix}-runner-${random_id.suffix.hex}"
  display_name = "MINIX validation runner"
}

resource "google_storage_bucket_iam_member" "runner_object_admin" {
  bucket = google_storage_bucket.artifacts.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.runner.email}"
}

resource "google_project_iam_member" "runner_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.runner.email}"
}

resource "google_compute_instance" "runner" {
  name         = local.runner_name
  machine_type = var.runner_machine_type
  zone         = var.zone

  min_cpu_platform = "Intel Haswell"

  advanced_machine_features {
    enable_nested_virtualization = true
  }

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-12"
      size  = var.runner_boot_disk_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.runner.id
  }

  service_account {
    email = google_service_account.runner.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  metadata = {
    startup-script-url = "gs://${google_storage_bucket.artifacts.name}/${google_storage_bucket_object.startup_script.name}"
    enable-oslogin     = "TRUE"
  }

  tags = ["${var.name_prefix}-runner"]

  depends_on = [
    google_compute_router_nat.runner,
    google_storage_bucket_iam_member.runner_object_admin,
    google_project_iam_member.runner_log_writer,
  ]
}

resource "google_service_account" "status" {
  count = var.status_image == "" ? 0 : 1

  account_id   = "${var.name_prefix}-status-${random_id.suffix.hex}"
  display_name = "MINIX status app"
}

resource "google_storage_bucket_iam_member" "status_viewer" {
  count = var.status_image == "" ? 0 : 1

  bucket = google_storage_bucket.artifacts.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.status[0].email}"
}

resource "google_cloud_run_v2_service" "status" {
  count = var.status_image == "" ? 0 : 1

  name     = local.status_name
  location = var.region

  template {
    service_account = google_service_account.status[0].email

    containers {
      image = var.status_image

      env {
        name  = "RESULT_BUCKET"
        value = google_storage_bucket.artifacts.name
      }

      env {
        name  = "RESULT_OBJECT"
        value = local.latest_result_key
      }
    }
  }

  depends_on = [
    google_project_service.services,
    google_storage_bucket_iam_member.status_viewer,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "public_status" {
  count = var.status_image != "" && var.public_status_app ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.status[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
