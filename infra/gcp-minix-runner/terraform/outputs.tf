output "runner_name" {
  value = google_compute_instance.runner.name
}

output "runner_zone" {
  value = google_compute_instance.runner.zone
}

output "artifact_bucket" {
  value = google_storage_bucket.artifacts.name
}

output "runner_service_account" {
  value = google_service_account.runner.email
}

output "status_url" {
  value = var.status_image == "" ? null : google_cloud_run_v2_service.status[0].uri
}

output "iap_ssh_command" {
  value = "gcloud compute ssh ${google_compute_instance.runner.name} --zone ${var.zone} --tunnel-through-iap"
}
