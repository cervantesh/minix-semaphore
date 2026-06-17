# Local VirtualBox Runner

This runner is the local rehearsal path for the MINIX PM semaphore validation.
It uses VirtualBox on the host and a Linux runner VM managed by Vagrant. The
Linux runner then boots the prepared MINIX image through QEMU.

```text
Windows host
  -> VirtualBox + Vagrant
     -> Debian runner
        -> QEMU
           -> MINIX
```

This is the final validation path kept for the portfolio version of the
project.

## Host Requirements

- VirtualBox
- Vagrant
- PowerShell 7 or Windows PowerShell
- A prepared MINIX disk image with `/usr/src`, `/usr/tests/minix-posix`, and a
  working `/root/minix-runner/apply-build-test.sh` helper inside the guest

## Prepare A MINIX VM In VirtualBox

Download a MINIX ISO and create a local install VM:

```powershell
cd infra/local-virtualbox-runner
.\scripts\create-minix-vm.ps1 `
  -IsoPath C:\path\to\minix.iso `
  -DiskPath C:\vm-images\minix-sem-image.vdi
```

Install MINIX in the VirtualBox console. Inside MINIX, add:

```text
/root/minix-runner/apply-build-test.sh
```

The helper must accept the patch media device path as its first argument, apply
the patch series in `/usr/src`, run `make build`, reboot if needed, and run
`cd /usr/tests/minix-posix && ./run -t 95`.

After the VM is powered off, export the disk to a raw image:

```powershell
.\scripts\export-minix-image.ps1 `
  -SourceVdi C:\vm-images\minix-sem-image.vdi `
  -OutputImage ..\..\.artifacts\minix.img
```

## Build The Patch Bundle

From this runner directory:

```powershell
.\scripts\create-patch-bundle.ps1
```

This writes:

```text
../../.artifacts/minix-patches.tar.gz
```

## Run Locally Through VirtualBox

Start the Linux runner VM:

```powershell
vagrant up --provider virtualbox
```

Run the validation:

```powershell
vagrant ssh -c "sudo /vagrant/infra/local-virtualbox-runner/scripts/run-local-validation.sh"
```

Expected inputs:

```text
../../.artifacts/minix.img
../../.artifacts/minix-patches.tar.gz
```

Expected outputs:

```text
../../.artifacts/virtualbox-runs/RUN_ID/
  build.log
  result.json
  serial.log
  test95.log
```

## Notes

- The Vagrant VM requests nested hardware virtualization in VirtualBox. If the
  host cannot expose it, set `LOCAL_RUNNER_NESTED=off` before `vagrant up`.
- The local runner falls back to QEMU TCG if `/dev/kvm` is unavailable. That is
  slower, but useful for boot and helper debugging.
- Do not mark the portfolio project as fully validated until `result.json`
  shows `status: "passed"` with build and test exit codes equal to `0`.
- No Google Cloud or Terraform deployment is required for this repository
  anymore; the local validation artifacts are the final demonstration path.
