# Google Cloud Runner For MINIX Semaphore Validation

## Goal

Automate the portfolio validation path for the MINIX PM semaphore feature on Google Cloud. The public-facing result should show a real commit SHA, build log, test log, and pass/fail status without giving visitors access to the VM.

## Architecture

- Compute Engine runner VM inside a dedicated VPC.
- Nested virtualization enabled on the runner so QEMU/KVM can boot MINIX.
- Persistent Disk or Cloud Storage object for the prepared MINIX disk image.
- Cloud Storage bucket for immutable run artifacts:
  - `build.log`
  - `test95.log`
  - `serial.log`
  - `result.json`
  - applied patch bundle
- Cloud Run status service for a small read-only dashboard.
- Optional Cloud Scheduler trigger for scheduled validation.

## Run Flow

0. Rehearse the image and helper locally with `infra/local-virtualbox-runner`.
1. Fetch or receive the `portfolio-pm-semaphores` patch bundle.
2. Start the runner VM.
3. Copy patches into the MINIX VM workspace.
4. Boot MINIX through QEMU/KVM.
5. Apply patches in `/usr/src`.
6. Run:

```sh
cd /usr/src
make build
```

7. Reboot into the rebuilt system.
8. Run:

```sh
cd /usr/tests/minix-posix
./run -t 95
```

9. Upload logs and `result.json` to Cloud Storage.
10. Stop or delete the runner VM to control cost.

## Result JSON Shape

```json
{
  "commit": "83ae4274eb29244e398c90d72433a5d8bfe22d4c",
  "base": "4db99f4012570a577414fe2a43697b2f239b699e",
  "status": "passed",
  "buildExitCode": 0,
  "testExitCode": 0,
  "test": "95",
  "startedAt": "2026-06-16T00:00:00Z",
  "finishedAt": "2026-06-16T00:00:00Z",
  "artifacts": {
    "buildLog": "gs://BUCKET/runs/RUN_ID/build.log",
    "testLog": "gs://BUCKET/runs/RUN_ID/test95.log",
    "serialLog": "gs://BUCKET/runs/RUN_ID/serial.log"
  }
}
```

## Security And Cost Notes

- Keep the runner private unless SSH is needed temporarily through Identity-Aware Proxy.
- Let Cloud Run expose only read-only artifact metadata, not VM control, for the first version.
- If a manual "run latest" button is added later, protect it with authentication and rate limiting.
- Stop the runner after each validation run.
- Keep old logs in Cloud Storage with lifecycle rules.

## Google Cloud References

- Compute Engine nested virtualization: https://docs.cloud.google.com/compute/docs/instances/nested-virtualization/overview
- Enable nested virtualization: https://docs.cloud.google.com/compute/docs/instances/nested-virtualization/enabling
- Cloud Storage static website hosting: https://docs.cloud.google.com/storage/docs/hosting-static-website
- Cloud Run source deployments: https://docs.cloud.google.com/run/docs/deploying-source-code
