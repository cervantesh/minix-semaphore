# Local Validation: MINIX PM Semaphores

This directory captures a local, reproducible validation run for the
`portfolio-pm-semaphores` branch on a Windows host using VirtualBox, a Debian
runner VM, and QEMU.

## Summary

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

## Validated Local Run

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

What this local run did:

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

Measured timing:

- `build.sh tools`: `2026-06-17 02:50:18 UTC` -> `03:05:05 UTC`
- `build.sh distribution`: `2026-06-17 03:05:05 UTC` -> `03:34:33 UTC`
- focused runtime test completed at about `03:36 UTC`

## Committed Evidence

- [structured result](./20260617T024946Z-from-scratch.result.json)
- [focused runtime log](./20260617T024946Z-from-scratch.test95.log)
- [validation patch](./0001-build-fix-validation-path-for-semaphore-portfolio.patch)

The evidence files show:

- the exact branch and validated commit IDs
- zero exit codes for clone, patch, tools, distribution, packaging, image
  build, and focused test
- the exact `Test 95 ok` output from the rebuilt MINIX image

Direct proof points inside the committed evidence:

- `status: "passed"` in [structured result](./20260617T024946Z-from-scratch.result.json)
- `testExitCode: 0` in [structured result](./20260617T024946Z-from-scratch.result.json)
- `Test 95 ok` in [focused runtime log](./20260617T024946Z-from-scratch.test95.log)

## Consolidated Learnings

Feature-level learnings:

- the PM delayed-reply model is the right fit for blocking semaphore waits in
  this project
- the semaphore implementation needed coverage at the libc, PM, and regression
  test levels to count as end-to-end work
- `test95` is the focused proof point for create/down/up/destroy plus
  interruption behavior

Build and packaging learnings:

- the correct host strategy is the official Linux-side `build.sh` path, not a
  guest-native MINIX rebuild
- the semaphore branch cannot be materialized directly on this Windows host, so
  the portable handoff is a raw `git bundle` cloned inside Linux
- the validated host-compatibility and packaging fixes are:
  - `external/bsd/llvm/dist/llvm/include/llvm/IR/ValueMap.h`
  - `tools/binutils/Makefile`
  - `minix/include/minix/Makefile`
  - `distrib/sets/lists/minix-comp/mi`
  - `distrib/sets/lists/minix-tests/mi`
- the packaging wrapper also needed two local fixes:
  - create `releasedir/i386/binary/sets` before `maketars`
  - create the validated bundle from `refs/heads/portfolio-pm-semaphores`
    instead of a bare commit SHA

Execution learnings:

- on this workstation, the expensive step is rebuilding the LLVM-enabled host
  toolchain, not booting the final MINIX image
- the validated runner size for this path was `6 vCPU / 8192 MB`
- once the host build completed, packaging, image build, and the focused guest
  test were straightforward

Automation learnings:

- the right artifact set for a portfolio proof is:
  - a structured `result.json`
  - the focused runtime log
  - the validation patch
- the next useful automation step is to publish those artifacts from one stable
  workflow instead of keeping larger local runner outputs outside the repo

## Outcome

This local validation proves that the semaphore branch is not only present at
source level, but also:

- rebuilds successfully on the Linux host path used in this project
- produces a bootable MINIX image
- boots correctly after the rebuild
- passes the focused semaphore regression test inside the rebuilt system
