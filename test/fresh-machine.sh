#!/bin/bash
# Provision a fresh macOS VM from this repository, then run the playbook again to surface non-idempotent tasks.
set -euo pipefail
export PATH="/opt/homebrew/bin:$PATH"

: "${TART_IMAGE:=ghcr.io/cirruslabs/macos-tahoe-vanilla:latest}"
: "${VM_NAME:=my-macos-setup-test}"
: "${VM_CPU:=4}"
: "${VM_MEMORY_MB:=8192}"
: "${VM_DISK_GB:=80}"
: "${VM_USER:=admin}"
: "${VM_PASSWORD:=admin}"
: "${SKIP_TAGS:=appstore}"
: "${STRICT_IDEMPOTENCY:=0}"
: "${KEEP_VM:=0}"

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
work_dir="$(mktemp -d)"
ssh_key="${work_dir}/id_ed25519"
ssh_opts=(-i "$ssh_key" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ServerAliveInterval=30 -o ServerAliveCountMax=4)
run_pid=""
vm_ip=""

log() { printf '\n==> %s\n' "$*"; }

cleanup() {
  if [ "$KEEP_VM" = "1" ]; then
    log "Keeping VM ${VM_NAME}; connect with: ssh ${VM_USER}@$(tart ip "$VM_NAME" 2>/dev/null || echo '<ip>')"
    return
  fi
  if [ -n "$run_pid" ]; then
    tart stop "$VM_NAME" 2>/dev/null || kill "$run_pid" 2>/dev/null || true
    wait "$run_pid" 2>/dev/null || true
  fi
  tart delete "$VM_NAME" 2>/dev/null || true
  rm -rf "$work_dir"
}
trap cleanup EXIT

vm_ssh() { ssh "${ssh_opts[@]}" "${VM_USER}@${vm_ip}" "$@"; }

wait_for_ssh() {
  local _
  for _ in $(seq 1 60); do
    nc -z -G 2 "$vm_ip" 22 2>/dev/null && return 0
    sleep 5
  done
  echo "SSH on ${vm_ip} did not come up" >&2
  return 1
}

install_ssh_key() {
  ssh-keygen -q -t ed25519 -N '' -f "$ssh_key"
  expect <<EXPECT
set timeout 120
spawn ssh-copy-id -i "$ssh_key" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${VM_USER}@${vm_ip}"
expect -re {[Pp]assword:}
send "${VM_PASSWORD}\r"
expect eof
EXPECT
}

provision() {
  vm_ssh "cd my-macos-setup && ANSIBLE_FORCE_COLOR=${ANSIBLE_FORCE_COLOR:-0} ./build.sh -e become_password=${VM_PASSWORD} --skip-tags ${SKIP_TAGS}"
}

log "Creating VM ${VM_NAME} from ${TART_IMAGE}"
tart delete "$VM_NAME" 2>/dev/null || true
tart clone "$TART_IMAGE" "$VM_NAME"
tart set "$VM_NAME" --cpu "$VM_CPU" --memory "$VM_MEMORY_MB" --disk-size "$VM_DISK_GB"

log "Booting"
taskpolicy -b tart run "$VM_NAME" --no-graphics --no-audio &
run_pid=$!
vm_ip="$(tart ip "$VM_NAME" --wait 180)"
wait_for_ssh
install_ssh_key

log "Copying tracked files"
git -C "$repo_dir" ls-files | rsync -a --files-from=- -e "ssh ${ssh_opts[*]}" "${repo_dir}/" "${VM_USER}@${vm_ip}:my-macos-setup/"

log "Bootstrapping (prepare.sh)"
vm_ssh "cd my-macos-setup && NONINTERACTIVE=1 ./prepare.sh"

log "Provisioning (build.sh)"
provision | tee "${work_dir}/first-run.log"

log "Provisioning again to check idempotency"
provision | tee "${work_dir}/second-run.log"

changed_tasks="$(grep -B1 '^changed: \[' "${work_dir}/second-run.log" | grep '^TASK' || true)"
if [ -n "$changed_tasks" ]; then
  log "Tasks still reporting a change on the second run:"
  echo "$changed_tasks"
  [ "$STRICT_IDEMPOTENCY" = "1" ] && exit 1
fi

log "Fresh machine provisioned successfully"
