#!/bin/bash
set -euo pipefail

# Détermination du chemin racine
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Chargement des modules
source "$ROOT_DIR/lib/log.sh"
source "$ROOT_DIR/lib/utils.sh"
source "$ROOT_DIR/lib/config.sh"

log_info "Démarrage du script principal"

# Exemple d'utilisation d'une fonction utilitaire
check_dependencies "curl" "jq"

# Traitement principal
log_debug "Traitement en cours..."
# ... script principal ici ...

log_info "Fin du script"

