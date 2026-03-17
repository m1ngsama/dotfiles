#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
source_dir="${repo_root}/ranger"

target_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/ranger"
state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/dotfiles-backups/ranger"
backup_dir=""
mode="link"
dry_run="false"

files=(
  "rc.conf"
  "scope.sh"
)

usage() {
  cat <<'EOF'
Usage: install-ranger.sh [options]

Install the tracked ranger configuration into ~/.config/ranger.

Options:
  --copy               Copy files instead of creating symlinks
  --link               Create symlinks (default)
  --dry-run            Print the planned actions without changing anything
  --target-dir <path>  Override the install target directory
  -h, --help           Show this help message
EOF
}

log() {
  printf '%s\n' "$*"
}

run() {
  if [[ "${dry_run}" == "true" ]]; then
    printf '[dry-run] %s\n' "$*"
    return 0
  fi

  "$@"
}

ensure_backup_dir() {
  if [[ -n "${backup_dir}" ]]; then
    return 0
  fi

  backup_dir="${state_dir}/$(date +%Y%m%d-%H%M%S)-$$"
  run mkdir -p -- "${backup_dir}"
}

backup_target() {
  local target="${1}"

  if [[ ! -e "${target}" && ! -L "${target}" ]]; then
    return 0
  fi

  if [[ -d "${target}" && ! -L "${target}" ]]; then
    printf 'Refusing to replace directory target: %s\n' "${target}" >&2
    exit 1
  fi

  ensure_backup_dir
  log "Backing up ${target} -> ${backup_dir}/$(basename -- "${target}")"
  run mv -- "${target}" "${backup_dir}/$(basename -- "${target}")"
}

install_one() {
  local name="${1}"
  local src="${source_dir}/${name}"
  local dst="${target_dir}/${name}"

  if [[ ! -f "${src}" ]]; then
    printf 'Missing source file: %s\n' "${src}" >&2
    exit 1
  fi

  if [[ "${mode}" == "link" && -L "${dst}" ]]; then
    local current
    current="$(readlink -- "${dst}" || true)"
    if [[ "${current}" == "${src}" ]]; then
      log "Already linked: ${dst}"
      return 0
    fi
  fi

  if [[ "${mode}" == "copy" && -f "${dst}" && ! -L "${dst}" ]] && cmp -s -- "${src}" "${dst}"; then
    log "Already up to date: ${dst}"
    return 0
  fi

  backup_target "${dst}"

  case "${mode}" in
    link)
      log "Linking ${dst} -> ${src}"
      run ln -s -- "${src}" "${dst}"
      ;;
    copy)
      local install_mode="644"
      if [[ -x "${src}" ]]; then
        install_mode="755"
      fi
      log "Copying ${src} -> ${dst}"
      run install -m "${install_mode}" -- "${src}" "${dst}"
      ;;
    *)
      printf 'Unsupported mode: %s\n' "${mode}" >&2
      exit 1
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "${1}" in
    --copy)
      mode="copy"
      shift
      ;;
    --link)
      mode="link"
      shift
      ;;
    --dry-run)
      dry_run="true"
      shift
      ;;
    --target-dir)
      if [[ $# -lt 2 ]]; then
        printf 'Missing value for %s\n' "${1}" >&2
        exit 1
      fi
      target_dir="${2}"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "${1}" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "${source_dir}" ]]; then
  printf 'Missing ranger source directory: %s\n' "${source_dir}" >&2
  exit 1
fi

run mkdir -p -- "${target_dir}"

for name in "${files[@]}"; do
  install_one "${name}"
done

if [[ -n "${backup_dir}" ]]; then
  log "Backups stored in ${backup_dir}"
fi

log "ranger config installed into ${target_dir}"
