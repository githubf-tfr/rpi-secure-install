#!/bin/bash
check_dependencies() {
  for dep in "$@"; do
    if ! command -v "$dep" &>/dev/null; then
      log_error "Dépendance manquante : $dep"
      exit 1
    fi
  done
}

