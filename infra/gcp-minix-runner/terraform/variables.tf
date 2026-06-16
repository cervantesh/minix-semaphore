variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Google Cloud region for regional resources."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Google Cloud zone for the runner VM."
  type        = string
  default     = "us-central1-a"
}

variable "name_prefix" {
  description = "Resource name prefix."
  type        = string
  default     = "minix-sem"
}

variable "artifact_bucket_name" {
  description = "Globally unique Cloud Storage bucket for run artifacts."
  type        = string
}

variable "minix_image_uri" {
  description = "Cloud Storage URI for the prepared MINIX disk image, for example gs://bucket/images/minix.img."
  type        = string
  default     = ""
}

variable "patch_bundle_uri" {
  description = "Cloud Storage URI for the patch bundle tarball."
  type        = string
  default     = ""
}

variable "runner_machine_type" {
  description = "Compute Engine machine type. Do not use E2, AMD, Arm, memory-optimized, or H4D for nested virtualization."
  type        = string
  default     = "n2-standard-4"
}

variable "runner_boot_disk_gb" {
  description = "Runner boot disk size."
  type        = number
  default     = 80
}

variable "runner_source_ranges" {
  description = "CIDR ranges allowed to SSH through IAP. Leave default for IAP TCP forwarding."
  type        = list(string)
  default     = ["35.235.240.0/20"]
}

variable "enable_iap_ssh" {
  description = "Whether to allow SSH from IAP TCP forwarding."
  type        = bool
  default     = true
}

variable "status_image" {
  description = "Optional container image for the Cloud Run status app. If empty, Terraform does not create the Cloud Run service."
  type        = string
  default     = ""
}

variable "public_status_app" {
  description = "Whether to allow unauthenticated access to the Cloud Run status app."
  type        = bool
  default     = false
}
