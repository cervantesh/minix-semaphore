# minix-semaphore

This branch is the clean implementation branch for the MINIX PM semaphore work.

## Purpose

Use this branch when the goal is to review the feature itself without portfolio
material around it. It keeps the semaphore work focused on code, packaging, and
regression coverage.

## What is in this branch

Relative to `minix-source-base`, this branch contains:

- PM call numbers and message ABI for semaphores
- public header `minix/semaphore.h`
- libc wrappers for create, down, up, and destroy
- Process Manager semaphore state and delayed-reply blocking
- signal interruption handling for blocked waiters
- packaged `test95` coverage and install-set updates

## Best files to inspect first

Public API and ABI:

- `minix/include/minix/callnr.h`
- `minix/include/minix/ipc.h`
- `minix/include/minix/semaphore.h`

User-space entry points:

- `minix/lib/libc/sys/minix_sem.c`
- `minix/lib/libc/sys/Makefile.inc`

Process Manager implementation:

- `minix/servers/pm/sem.c`
- `minix/servers/pm/signal.c`
- `minix/servers/pm/table.c`
- `minix/servers/pm/forkexit.c`
- `minix/servers/pm/mproc.h`
- `minix/servers/pm/proto.h`

Packaging and tests:

- `minix/include/minix/Makefile`
- `distrib/sets/lists/minix-comp/mi`
- `distrib/sets/lists/minix-tests/mi`
- `minix/tests/test95.c`
- `minix/tests/Makefile`
- `minix/tests/run`

## How this branch should be read

- If you want the clean code review, stay on this branch.
- If you want the validation evidence and local runner used for the portfolio,
  go to `portfolio-minix-semaphore`.
- If you want the exact PR diff against the frozen upstream-based base, use:
  https://github.com/cervantesh/minix-semaphore/pull/1