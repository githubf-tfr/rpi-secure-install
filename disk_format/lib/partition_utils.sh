#!/bin/bash

check_disk_capacity() {
    echo ""
    echo "📏 Calcul de la capacité requise par le profil..."

    total_requested_gb=0
    for entry in "${PARTITIONS[@]}"; do
        IFS=":" read -r LABEL SIZE TYPE MOUNT OPTIONS <<< "$entry"
        total_requested_gb=$(echo "$total_requested_gb + $SIZE" | bc)
    done

    disk_size_bytes=$(lsblk -nb -o SIZE "$selected_dev" | head -n1)
    disk_size_gb=$(awk "BEGIN { printf \"%.0f\", $disk_size_bytes / (1024*1024*1024) }")

    echo "📦 Espace demandé par le profil : ${total_requested_gb} Go"
    echo "💽 Capacité du disque détecté : ${disk_size_gb} Go"

    if (( $(echo "$total_requested_gb > $disk_size_gb" | bc -l) )); then
        echo "❌ Le disque est trop petit pour le profil sélectionné !"
        echo "   Profil : ${total_requested_gb} Go > Disque : ${disk_size_gb} Go"
        exit 1
    else
        echo "✅ Espace disque suffisant pour le profil sélectionné."
    fi
}

