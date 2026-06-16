# MINIX Image Contract

The GCP runner expects a prepared MINIX disk image. This document defines the image contract so the validation is reproducible.

## Required

- Bootable MINIX 3 disk image compatible with QEMU on x86.
- Source tree available at `/usr/src`.
- Test suite available at `/usr/tests/minix-posix`.
- A root or privileged shell reachable through the serial console.
- Build command works from `/usr/src`:

```sh
make build
```

- Focused test command works after reboot:

```sh
cd /usr/tests/minix-posix
./run -t 95
```

## Local Preparation

The image can be prepared with VirtualBox before it is uploaded to Google Cloud.
Use `infra/local-virtualbox-runner/scripts/create-minix-vm.ps1` to create an
install VM from a MINIX ISO, then use
`infra/local-virtualbox-runner/scripts/export-minix-image.ps1` to convert the
installed VDI to the raw `minix.img` consumed by the QEMU runners.

## Preferred Guest Helper

The most reliable automation path is to include this helper in the image:

```sh
/root/minix-runner/apply-build-test.sh PATCH_MEDIA_DEVICE
```

Expected behavior:

1. Mount or read the patch media device provided by QEMU.
2. Extract or locate the patch files.
3. Apply patches in `/usr/src`.
4. Run `make build`.
5. Reboot if required.
6. Run `cd /usr/tests/minix-posix && ./run -t 95`.
7. Return a non-zero exit code if build or test fails.

## Serial Console

The runner can drive MINIX through QEMU serial output. The image should expose login or shell prompts consistently. These values are configurable through environment variables:

- `MINIX_USER`
- `MINIX_PASSWORD`
- `MINIX_LOGIN_PROMPT`
- `MINIX_PASSWORD_PROMPT`
- `MINIX_SHELL_PROMPT`

## Patch Input

The runner downloads a patch bundle from Cloud Storage. Recommended format:

```text
minix-patches.tar.gz
  0001-pm-implement-semaphore-syscalls.patch
  0002-libc-add-MINIX-semaphore-wrappers.patch
  0003-tests-cover-PM-semaphores.patch
  0004-docs-describe-PM-semaphore-project.patch
  0005-docs-plan-Google-Cloud-MINIX-runner.patch
```

The runner converts this archive into an ISO and attaches it to QEMU as the
patch media device. The image-specific helper is responsible for mounting that
device using the correct MINIX device path.

## Validation Evidence

The final portfolio page should not mark the project as validated until the runner captures:

- `make build` exit code
- `./run -t 95` exit code
- serial log
- build log
- test log
- commit SHA and upstream base SHA
