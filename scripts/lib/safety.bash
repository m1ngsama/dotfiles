#!/usr/bin/env bash

# Shared path validation for the bootstrap backup and restore tools. This file
# is sourced by other scripts and intentionally has no executable entry point.

dotfiles_die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

dotfiles_validate_absolute_path() {
  local candidate=$1
  local description=${2:-path}

  [[ -n $candidate ]] || dotfiles_die "$description is empty"
  [[ $candidate == /* ]] || dotfiles_die "$description must be absolute: $candidate"
  [[ $candidate != / ]] || dotfiles_die "$description must not be /"
  [[ $candidate != *$'\n'* && $candidate != *$'\r'* && $candidate != *$'\t'* ]] ||
    dotfiles_die "$description contains a control character"
}

dotfiles_prepare_directory() {
  local candidate=$1
  local description=${2:-directory}
  local canonical

  dotfiles_validate_absolute_path "$candidate" "$description"
  mkdir -p -- "$candidate"
  [[ -d $candidate ]] || dotfiles_die "$description is not a directory: $candidate"
  canonical=$(cd -P -- "$candidate" && pwd -P)
  dotfiles_validate_absolute_path "$canonical" "$description"
  printf '%s\n' "$canonical"
}

dotfiles_existing_directory() {
  local candidate=$1
  local description=${2:-directory}
  local canonical

  dotfiles_validate_absolute_path "$candidate" "$description"
  [[ -d $candidate ]] || dotfiles_die "$description does not exist: $candidate"
  canonical=$(cd -P -- "$candidate" && pwd -P)
  dotfiles_validate_absolute_path "$canonical" "$description"
  printf '%s\n' "$canonical"
}

dotfiles_validate_relative_path() {
  local relative=$1
  local component
  local -a components

  [[ -n $relative ]] || dotfiles_die 'managed path is empty'
  [[ $relative != /* ]] || dotfiles_die "managed path is absolute: $relative"
  [[ $relative != *$'\n'* && $relative != *$'\r'* && $relative != *$'\t'* ]] ||
    dotfiles_die 'managed path contains a control character'

  IFS='/' read -r -a components <<<"$relative"
  ((${#components[@]} > 0)) || dotfiles_die "invalid managed path: $relative"
  for component in "${components[@]}"; do
    [[ -n $component && $component != . && $component != .. ]] ||
      dotfiles_die "unsafe managed path: $relative"
  done
}

dotfiles_assert_safe_parent_chain() {
  local root=$1
  local relative=$2
  local current=$root
  local component
  local index
  local -a components

  dotfiles_validate_relative_path "$relative"
  IFS='/' read -r -a components <<<"$relative"
  for ((index = 0; index < ${#components[@]} - 1; index++)); do
    component=${components[$index]}
    current="$current/$component"
    [[ ! -L $current ]] || dotfiles_die "refusing symlinked parent: $current"
    if [[ -e $current && ! -d $current ]]; then
      dotfiles_die "managed path has a non-directory parent: $current"
    fi
  done
}

dotfiles_safe_cleanup_tree() {
  local candidate=$1
  local expected_parent=$2
  local expected_prefix=$3

  [[ -n $candidate && -n $expected_parent && -n $expected_prefix ]] || return 0
  case "$candidate" in
    "$expected_parent"/"$expected_prefix"*)
      [[ $candidate != "$expected_parent" ]] || return 0
      rm -rf -- "$candidate"
      ;;
  esac
}

dotfiles_atomic_replace() {
  local source=$1
  local target=$2

  [[ -e $source || -L $source ]] || dotfiles_die "replacement source is missing: $source"
  [[ ! -d $target || -L $target ]] ||
    dotfiles_die "refusing to replace a real directory target: $target"

  case $(uname -s) in
    Darwin)
      # BSD mv -h replaces a destination symlink instead of following it.
      mv -fh -- "$source" "$target"
      ;;
    Linux)
      # GNU mv -T always treats the destination as a path, never a directory.
      mv -fT -- "$source" "$target"
      ;;
    *)
      dotfiles_die 'atomic replacement is supported only on macOS and Linux'
      ;;
  esac
}
