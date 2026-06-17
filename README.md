# portfolio-minix-semaphore

This branch is the portfolio proof branch for the MINIX PM semaphore project.

## Purpose

Use this branch when the goal is to inspect the evidence that the feature was
rebuilt and exercised locally, plus the local runner that was used to produce
that proof.

This branch is not the cleanest place to review the semaphore code itself.
For the implementation-only view, use `minix-semaphore`.

## What is in this branch

This branch includes:

- the semaphore implementation itself
- portfolio-facing project notes
- committed local validation evidence
- the local VirtualBox/Vagrant/QEMU runner used for the rerun

It intentionally does not keep the abandoned Google Cloud or Terraform path.
The final proof for the portfolio is the local rebuild and the focused
`Test 95 ok` result.

## Best files to inspect first

Portfolio overview:

- `docs/portfolio/minix-pm-semaphores.md`

Validation evidence:

- `docs/local-validation/minix-pm-semaphores/README.md`
- `docs/local-validation/minix-pm-semaphores/20260617T024946Z-from-scratch.result.json`
- `docs/local-validation/minix-pm-semaphores/20260617T024946Z-from-scratch.test95.log`
- `docs/local-validation/minix-pm-semaphores/0001-build-fix-validation-path-for-semaphore-portfolio.patch`

Local runner:

- `infra/local-virtualbox-runner/README.md`
- `infra/local-virtualbox-runner/Vagrantfile`
- `infra/local-virtualbox-runner/scripts/run-local-validation.sh`
- `infra/local-virtualbox-runner/scripts/create-minix-vm.ps1`
- `infra/local-virtualbox-runner/scripts/export-minix-image.ps1`
- `infra/local-virtualbox-runner/scripts/create-patch-bundle.ps1`

## How this branch should be read

- Start with `docs/portfolio/minix-pm-semaphores.md` for the high-level story.
- Then read the local validation README and the committed result files.
- Use the local runner directory only if you want to understand or replay the
  validation path.
- If you want the minimal implementation diff, switch to `minix-semaphore`.