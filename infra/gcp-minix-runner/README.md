# GCP MINIX Runner

This scaffold provisions a Google Cloud runner for validating the MINIX PM semaphore branch in a real MINIX VM.

The intended public artifact is a read-only status page showing:

- commit SHA
- upstream base SHA
- build result
- `test95` result
- links to build, test, and serial logs

## Components

- `terraform/`: VPC, private Compute Engine runner, Cloud Storage artifacts bucket, optional Cloud Run service wiring.
- `scripts/`: runner-side validation script.
- `status-app/`: small Cloud Run app that reads the latest `result.json` from Cloud Storage.
- `MINIX_IMAGE_CONTRACT.md`: requirements for the MINIX disk image used by QEMU.

## Why Compute Engine

MINIX validation needs a real VM because the patch changes PM, libc, and the installed test suite. Google Cloud supports nested virtualization on Compute Engine by setting `enableNestedVirtualization` for the VM. The runner uses Linux KVM through QEMU.

Google Cloud references:

- Compute Engine nested virtualization: https://docs.cloud.google.com/compute/docs/instances/nested-virtualization/overview
- Enable nested virtualization: https://docs.cloud.google.com/compute/docs/instances/nested-virtualization/enabling

## Quick Start

Create a Terraform variables file:

```sh
cd infra/gcp-minix-runner/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit:

- `project_id`
- `region`
- `zone`
- `artifact_bucket_name`
- `minix_image_uri`
- `patch_bundle_uri`

Apply:

```sh
terraform init
terraform apply
```

The runner installs QEMU tooling on startup. If `minix_image_uri` and `patch_bundle_uri` are provided, it attempts a validation run and uploads logs to Cloud Storage.

## Patch Bundle

From the repository root, generate patches:

```sh
git format-patch upstream/master..portfolio-pm-semaphores -o /tmp/minix-patches
tar -czf minix-patches.tar.gz -C /tmp/minix-patches .
gcloud storage cp minix-patches.tar.gz gs://BUCKET/inputs/minix-patches.tar.gz
```

## Runner Output

Artifacts are uploaded under:

```text
gs://BUCKET/runs/RUN_ID/
```

Expected files:

- `build.log`
- `test95.log`
- `serial.log`
- `runner.log`
- `result.json`

`runs/latest/result.json` is overwritten after each run so the status app can show the newest result.

## Status App

Deploy from `status-app/`:

```sh
gcloud run deploy minix-runner-status \
  --source ../status-app \
  --region REGION \
  --set-env-vars RESULT_BUCKET=BUCKET,RESULT_OBJECT=runs/latest/result.json
```

For the first version, keep Cloud Run read-only. Do not expose VM control actions from the public page.

## Current Limitation

The Terraform and runner scaffold are ready, but the automation still needs a MINIX disk image that satisfies `MINIX_IMAGE_CONTRACT.md`. Without that image, the runner can provision and install dependencies, but it cannot honestly claim `make build` or `./run -t 95` passed.
