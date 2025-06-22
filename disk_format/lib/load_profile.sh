#!/bin/bash

load_profile_config() {
    echo ""
    echo "🧩 Profils disponibles dans le dossier config/:"
    mapfile -t profiles < <(find config/ -type f -printf "%f\n")

    for i in "${!profiles[@]}"; do
        echo "[$i] ${profiles[$i]}"
    done

    read -p "👉 Entrez le numéro du profil à utiliser : " selected_profile_index
    selected_profile="${profiles[$selected_profile_index]}"

    if [[ ! -f "config/$selected_profile" ]]; then
        echo "❌ Erreur : profil introuvable."
        exit 1
    fi

    echo "✅ Profil sélectionné : config/$selected_profile"

    # Charger le profil
    profile_path="config/$selected_profile"

    echo ""
    echo "📦 Chargement du profil : $profile_path"
    source "$profile_path"

    # Mode debug : afficher les partitions lues
    if [[ "$DEBUG" == "1" ]]; then
        echo "[DEBUG] PARTITIONS :"
        for entry in "${PARTITIONS[@]}"; do
            echo "  ↪︎ $entry"
        done

        echo "[DEBUG] TMPFS_MOUNTS :"
        for entry in "${TMPFS_MOUNTS[@]}"; do
            echo "  ↪︎ $entry"
        done
    fi
}

