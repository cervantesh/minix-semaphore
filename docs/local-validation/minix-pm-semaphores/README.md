# Local Validation: MINIX PM Semaphores

This directory captures a local, reproducible validation run for the
`portfolio-pm-semaphores` branch on a Windows host using VirtualBox, a Debian
runner VM, and QEMU.

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

## Committed Evidence

- `20260617T024946Z-from-scratch.result.json`
- `20260617T024946Z-from-scratch.test95.log`
- `0001-build-fix-validation-path-for-semaphore-portfolio.patch`

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
