# Local Validation: MINIX PM Semaphores

This directory captures a local, reproducible validation run for the
`portfolio-pm-semaphores` branch on a Windows host using VirtualBox, a Debian
runner VM, and QEMU.

## Feature Scope

The `portfolio-pm-semaphores` branch adds a MINIX-specific counting semaphore
implementation backed by the Process Manager.

At a high level, the branch does the following:

- adds PM call numbers for create, down, up, and destroy
- adds the public header `minix/semaphore.h`
- adds libc wrappers for the semaphore calls
- adds PM-side semaphore state and waiter handling
- uses delayed PM replies to block `down` callers until wake-up
- wakes blocked callers in FIFO order
- returns `EIDRM` when a semaphore is destroyed while callers are blocked
- returns `EINTR` when a blocked wait is interrupted by a signal
- adds `test95` to exercise lifecycle, blocking, wake-up, destroy, and signal
  interruption behavior

## Validated Run

- run id: `20260617T024946Z-from-scratch`
- branch: `portfolio-pm-semaphores`
- raw branch commit: `9d19e472d3d2703146925b780a85ce1785172895`
- validated Linux-runner commit: `54d786540190e0f1da71fd648636d83d9f18a23a`
- runner size: `6 vCPU / 8192 MB`
- build jobs: `6`
- final result: `passed`

Focused runtime proof from the rebuilt MINIX image:

```text
minix# cd /usr/tests/minix-posix && ./run -t 95
Test 95 ok
TEST95_OK
```

## What The Local Validation Actually Did

The passing local run followed this sequence:

1. create a raw `git bundle` for the semaphore branch on the Windows host
2. boot the Debian runner VM under VirtualBox
3. clone the raw bundle inside the Linux runner
4. apply the host-compatibility and packaging fixes needed for a modern Linux
   build host
5. run `build.sh tools`
6. run `build.sh distribution`
7. generate the release tarballs from the built `DESTDIR`
8. build a bootable MINIX image with `releasetools/x86_hdimage.sh`
9. boot the rebuilt image under QEMU in the Linux runner
10. log in on the serial console and run `./run -t 95`

Measured timing from the validated run:

- `build.sh tools`: `2026-06-17 02:50:18 UTC` -> `03:05:05 UTC`
- `build.sh distribution`: `2026-06-17 03:05:05 UTC` -> `03:34:33 UTC`
- focused runtime test completed at about `03:36 UTC`

## Committed Evidence

- `20260617T024946Z-from-scratch.result.json`
- `20260617T024946Z-from-scratch.test95.log`
- `0001-build-fix-validation-path-for-semaphore-portfolio.patch`

The evidence files show:

- the exact branch and validated commit IDs
- zero exit codes for clone, patch, tools, distribution, packaging, image
  build, and focused test
- the exact `Test 95 ok` output from the rebuilt MINIX image

## What Had To Be Added In This Rerun

Two pipeline fixes were required in the local validation wrapper:

1. create `releasedir/i386/binary/sets` before running `maketars`
2. create the validated bundle from the branch ref
   `refs/heads/portfolio-pm-semaphores` instead of passing only the commit SHA

These were validation-pipeline fixes, not new semaphore feature changes.

## Local-Only Artifacts

The full runner workspace also has larger local-only artifacts such as:

- the validated bundle
- the serial log export
- full build logs
- the local VirtualBox runner scripts

Those files are intentionally not committed here because they are either large
binary artifacts or workstation-specific execution scaffolding.

## Re-run Path

The validated re-run path uses the local VirtualBox runner scripts that rebuild
the raw branch bundle, re-run the Linux host build, boot the rebuilt image, and
execute `./run -t 95`.

The exact workstation-specific script path is intentionally not committed here.

## Outcome

This local validation proves that the semaphore branch is not only present at
source level, but also:

- rebuilds successfully on the Linux host path used in this project
- produces a bootable MINIX image
- boots correctly after the rebuild
- passes the focused semaphore regression test inside the rebuilt system
