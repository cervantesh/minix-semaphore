#!/usr/bin/env bash
set -euo pipefail

MINIX_IMAGE="${MINIX_IMAGE:-/vagrant/.artifacts/minix.img}"
PATCH_BUNDLE="${PATCH_BUNDLE:-/vagrant/.artifacts/minix-patches.tar.gz}"
OUTPUT_ROOT="${OUTPUT_ROOT:-/vagrant/.artifacts/virtualbox-runs}"
COMMIT_SHA_FILE="${COMMIT_SHA_FILE:-/vagrant/.artifacts/commit-sha}"
BASE_SHA_FILE="${BASE_SHA_FILE:-/vagrant/.artifacts/base-sha}"
BASE_SHA="${BASE_SHA:-4db99f4012570a577414fe2a43697b2f239b699e}"
COMMIT_SHA="${COMMIT_SHA:-unknown}"
MINIX_MEMORY_MB="${MINIX_MEMORY_MB:-1024}"
MINIX_DISK_FORMAT="${MINIX_DISK_FORMAT:-raw}"
MINIX_USER="${MINIX_USER:-root}"
MINIX_PASSWORD="${MINIX_PASSWORD:-}"
MINIX_LOGIN_PROMPT="${MINIX_LOGIN_PROMPT:-login:}"
MINIX_PASSWORD_PROMPT="${MINIX_PASSWORD_PROMPT:-Password:}"
MINIX_SHELL_PROMPT="${MINIX_SHELL_PROMPT:-# }"
MINIX_GUEST_HELPER="${MINIX_GUEST_HELPER:-/root/minix-runner/apply-build-test.sh}"

if [[ "${COMMIT_SHA}" == "unknown" ]] && command -v git >/dev/null 2>&1; then
  COMMIT_SHA="$(git -C /vagrant rev-parse --short=12 portfolio-pm-semaphores 2>/dev/null || echo unknown)"
fi

if [[ "${COMMIT_SHA}" == "unknown" && -f "$COMMIT_SHA_FILE" ]]; then
  COMMIT_SHA="$(head -c 40 "$COMMIT_SHA_FILE")"
fi

if [[ -f "$BASE_SHA_FILE" ]]; then
  BASE_SHA="$(head -c 40 "$BASE_SHA_FILE")"
fi

RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-${COMMIT_SHA:0:12}}"
WORK_DIR="/tmp/minix-local-runner/$RUN_ID"
LOG_DIR="$OUTPUT_ROOT/$RUN_ID"
INPUT_DIR="$WORK_DIR/input"
mkdir -p "$LOG_DIR" "$INPUT_DIR"

RUNNER_LOG="$LOG_DIR/runner.log"
SERIAL_LOG="$LOG_DIR/serial.log"
BUILD_LOG="$LOG_DIR/build.log"
TEST_LOG="$LOG_DIR/test95.log"
RESULT_JSON="$LOG_DIR/result.json"

exec > >(tee -a "$RUNNER_LOG") 2>&1

started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
status="failed"
build_exit=1
test_exit=1

finish() {
  finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq -n \
    --arg commit "$COMMIT_SHA" \
    --arg base "$BASE_SHA" \
    --arg status "$status" \
    --arg test "95" \
    --arg startedAt "$started_at" \
    --arg finishedAt "$finished_at" \
    --arg runId "$RUN_ID" \
    --arg buildLog "$BUILD_LOG" \
    --arg testLog "$TEST_LOG" \
    --arg serialLog "$SERIAL_LOG" \
    --argjson buildExitCode "$build_exit" \
    --argjson testExitCode "$test_exit" \
    '{
      commit: $commit,
      base: $base,
      status: $status,
      buildExitCode: $buildExitCode,
      testExitCode: $testExitCode,
      test: $test,
      runId: $runId,
      startedAt: $startedAt,
      finishedAt: $finishedAt,
      artifacts: {
        buildLog: $buildLog,
        testLog: $testLog,
        serialLog: $serialLog
      }
    }' > "$RESULT_JSON"

  touch "$BUILD_LOG" "$TEST_LOG" "$SERIAL_LOG"
  echo "Result written to $RESULT_JSON"
}
trap finish EXIT

if [[ ! -f "$MINIX_IMAGE" ]]; then
  echo "Missing MINIX image: $MINIX_IMAGE"
  build_exit=2
  test_exit=2
  exit 2
fi

if [[ ! -f "$PATCH_BUNDLE" ]]; then
  echo "Missing patch bundle: $PATCH_BUNDLE"
  build_exit=2
  test_exit=2
  exit 2
fi

echo "Using MINIX image: $MINIX_IMAGE"
echo "Using patch bundle: $PATCH_BUNDLE"

echo "Creating patch ISO..."
mkdir -p "$INPUT_DIR/iso/patches"
tar -xzf "$PATCH_BUNDLE" -C "$INPUT_DIR/iso/patches"
genisoimage -quiet -o "$INPUT_DIR/minix-runner.iso" "$INPUT_DIR/iso"

if [[ "${QEMU_ACCEL:-auto}" == "auto" ]]; then
  if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    QEMU_ACCEL_ARGS="-enable-kvm"
  else
    QEMU_ACCEL_ARGS="-accel tcg"
  fi
else
  QEMU_ACCEL_ARGS="$QEMU_ACCEL"
fi
export QEMU_ACCEL_ARGS

echo "Using QEMU acceleration args: $QEMU_ACCEL_ARGS"

EXPECT_SCRIPT="$WORK_DIR/drive-minix.exp"
cat > "$EXPECT_SCRIPT" <<'EXPECT_EOF'
set timeout 1800
set image [lindex $argv 0]
set iso [lindex $argv 1]
set serial_log [lindex $argv 2]
set build_log [lindex $argv 3]
set test_log [lindex $argv 4]
set memory_mb $env(MINIX_MEMORY_MB)
set disk_format $env(MINIX_DISK_FORMAT)
set user $env(MINIX_USER)
set password $env(MINIX_PASSWORD)
set login_prompt $env(MINIX_LOGIN_PROMPT)
set password_prompt $env(MINIX_PASSWORD_PROMPT)
set shell_prompt $env(MINIX_SHELL_PROMPT)
set guest_helper $env(MINIX_GUEST_HELPER)
set qemu_accel_args [split $env(QEMU_ACCEL_ARGS)]

log_file -a $serial_log
spawn qemu-system-i386 {*}$qemu_accel_args -m $memory_mb \
  -drive file=$image,format=$disk_format,if=ide \
  -cdrom $iso \
  -serial stdio \
  -display none \
  -no-reboot

expect {
  -re $login_prompt {
    send "$user\r"
    exp_continue
  }
  -re $password_prompt {
    if {$password ne ""} {
      send "$password\r"
    } else {
      send "\r"
    }
    exp_continue
  }
  -re $shell_prompt {
    send "echo MINIX_RUNNER_READY\r"
  }
  timeout {
    exit 10
  }
}

expect {
  -re "MINIX_RUNNER_READY" {}
  timeout { exit 11 }
}

send "if test -x $guest_helper; then $guest_helper /dev/c0d1 > /tmp/minix-runner-build-test.log 2>&1; echo RUNNER_STATUS:\$?; else echo RUNNER_STATUS:127; fi\r"
expect {
  -re "RUNNER_STATUS:0" {
    set fh [open $build_log w]
    puts $fh "Guest helper completed successfully. See serial log for full output."
    close $fh
    set th [open $test_log w]
    puts $th "Guest helper completed test95 successfully. See serial log for full output."
    close $th
    exit 0
  }
  -re "RUNNER_STATUS:127" {
    set fh [open $build_log w]
    puts $fh "Guest helper $guest_helper was not found or executable."
    close $fh
    exit 127
  }
  -re "RUNNER_STATUS:([0-9]+)" {
    exit $expect_out(1,string)
  }
  timeout {
    exit 12
  }
}
EXPECT_EOF

set +e
expect "$EXPECT_SCRIPT" "$MINIX_IMAGE" "$INPUT_DIR/minix-runner.iso" "$SERIAL_LOG" "$BUILD_LOG" "$TEST_LOG"
guest_exit=$?
set -e

if [[ "$guest_exit" -eq 0 ]]; then
  build_exit=0
  test_exit=0
  status="passed"
else
  build_exit="$guest_exit"
  test_exit="$guest_exit"
  status="failed"
fi

exit "$guest_exit"
