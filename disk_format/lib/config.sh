#!/bin/bash
CONFIG_FILE="$ROOT_DIR/config/default.conf"

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  log_warn "Fichier de config non trouvé : $CONFIG_FILE"
fi
