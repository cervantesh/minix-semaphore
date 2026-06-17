# MINIX 3 PM-Backed Counting Semaphores

## Summary

This project revisits a 2016 operating-systems experiment that attempted to add semaphores to MINIX 3. The original work registered Process Manager call numbers, but it relied on signal-based process control and did not include a complete libc API or regression coverage.

This implementation turns the idea into an end-to-end MINIX feature: syscall numbers, message ABI, Process Manager state, delayed-reply blocking, libc wrappers, and a test-suite entry.

## What Changed

- Added four Process Manager calls: `PM_SEM_CREATE`, `PM_SEM_DOWN`, `PM_SEM_UP`, and `PM_SEM_DESTROY`.
- Added `minix/semaphore.h` with the public MINIX-specific API.
- Implemented counting semaphore state inside PM in `minix/servers/pm/sem.c`.
- Implemented blocking with MINIX's delayed-reply model: `down` returns `SUSPEND`, and PM replies only when `up`, `destroy`, or signal interruption resolves the wait.
- Added FIFO waiter queues over PM process slots.
- Added cleanup for exiting processes so stale waiters are removed.
- Integrated caught-signal interruption so a blocked `minix_sem_down()` can return `EINTR`.
- Added libc wrappers: `minix_sem_create`, `minix_sem_down`, `minix_sem_up`, and `minix_sem_destroy`.
- Added `test95` to verify lifecycle behavior, FIFO wake order, destroy wakeups with `EIDRM`, and signal interruption with `EINTR`.

## Why This Design

MINIX uses user-space servers for core operating-system services. The Process Manager already owns process lifecycle state and can block a system call by delaying its reply. Using delayed PM replies makes semaphore blocking explicit in the server, instead of trying to stop and continue user processes with signals.

This feature is intentionally MINIX-specific and educational. MINIX already has System V semaphores through the IPC server; this project demonstrates how to add a small synchronization primitive through the PM syscall path.

## Files Of Interest

- `minix/include/minix/callnr.h`
- `minix/include/minix/ipc.h`
- `minix/include/minix/semaphore.h`
- `minix/servers/pm/sem.c`
- `minix/servers/pm/table.c`
- `minix/servers/pm/signal.c`
- `minix/lib/libc/sys/minix_sem.c`
- `minix/tests/test95.c`

## Validation

The source-level checks can be done from any Git checkout, but build and runtime validation should be done inside a MINIX VM because the changed code affects PM, libc, and the installed test suite.

Build inside MINIX:

```sh
cd /usr/src
make build
```

Run the focused test:

```sh
cd /usr/tests/minix-posix
./run -t 95
```

Run related regression tests:

```sh
cd /usr/tests/minix-posix
./run -t "1 37 42 95"
```

Expected focused result:

```text
Test 95 ok
```

## Local Validation Path

The portfolio proof point for this project is the local VirtualBox-based
validation run:

1. Install MINIX in a VirtualBox VM.
2. Add the `/root/minix-runner/apply-build-test.sh` helper to the image.
3. Export the MINIX VDI as a raw `minix.img`.
4. Start the local Vagrant/VirtualBox runner in `infra/local-virtualbox-runner`.
5. Boot the exported image through QEMU inside the Linux runner.
6. Capture `result.json`, `serial.log`, `build.log`, and `test95.log` under `.artifacts/virtualbox-runs`.

The committed evidence under
`docs/local-validation/minix-pm-semaphores/` is the final portfolio artifact
for this work. A cloud runner was explored earlier, but it is intentionally out
of scope now because the local rebuild and `Test 95 ok` result already show the
concept end to end.

## Historical Note

The 2016 branch is useful as historical context. The new implementation is based on the official MINIX source mirror and avoids the old queue bug, missing public header, missing libc wrapper, missing tests, and signal-based blocking approach.
