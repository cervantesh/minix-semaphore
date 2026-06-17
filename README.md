# minix-semaphore

This default branch is intentionally minimal.

## Why master only keeps this README

The full MINIX source mirror is large enough that the semaphore work disappears
in the noise. For portfolio review, the first thing a visitor should see is the
project itself, the clean implementation diff, and the local validation proof.

So the default branch is now just the landing document. The source and evidence
still exist, but they live on dedicated branches where their purpose is clearer.

## Where the actual material lives

- GitHub Pages overview: https://cervantesh.github.io/minix-semaphore/
- minix-source-base: frozen upstream-based snapshot kept only as the review
  base for the semaphore diff
- minix-semaphore: clean PM-backed semaphore implementation
- portfolio-minix-semaphore: local validation evidence and the VirtualBox
  runner used to produce it

## Review and evidence

- Feature PR: https://github.com/cervantesh/minix-semaphore/pull/1
- Validation README: https://github.com/cervantesh/minix-semaphore/blob/portfolio-minix-semaphore/docs/local-validation/minix-pm-semaphores/README.md
- Structured result: https://github.com/cervantesh/minix-semaphore/blob/portfolio-minix-semaphore/docs/local-validation/minix-pm-semaphores/20260617T024946Z-from-scratch.result.json
- Focused test log (Test 95 ok): https://github.com/cervantesh/minix-semaphore/blob/portfolio-minix-semaphore/docs/local-validation/minix-pm-semaphores/20260617T024946Z-from-scratch.test95.log