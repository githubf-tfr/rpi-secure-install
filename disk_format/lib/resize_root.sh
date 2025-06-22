#!/bin/bash

resize_root_partition_if_needed() {
    echo ""
    echo "🔍 Analyse de la partition ROOT (${label2})…"

    root_partition=$(lsblk -nrp -o NAME,LABEL "$selected_dev" \
        | awk -v label="$label2" '$2 == label { print $1 }')

    if [[ -z "$root_partition" ]]; then
        echo "❌ Impossible de localiser la partition root/rootfs."
        exit 1
    fi

    root_size_gb=$(lsblk -nb -o SIZE "$root_partition" | awk '{ printf "%.0f", $1 / (1024^3) }')
    echo "📦 Taille de la partition root (${label2}) : ${root_size_gb} Go"

    expected_root_size_gb=""
    for entry in "${PARTITIONS[@]}"; do
        IFS=: read -r label size type mount options <<< "$entry"
        if [[ "$mount" == "/" ]]; then
            expected_root_size_gb=$size
            break
        fi
    done

    if [[ -z "$expected_root_size_gb" ]]; then
        echo "❌ Erreur : profil sans partition root (/)."
        exit 1
    fi

    echo "🔎 Comparaison : partition ROOT actuelle vs profil"

    delta=$(( root_size_gb - expected_root_size_gb ))
    abs_delta=${delta#-}
    tolerance=1

    if (( delta < -tolerance )); then
        echo "⚠️  La partition ROOT est TROP PETITE (${root_size_gb} Go < ${expected_root_size_gb} Go)"
        echo "   ➤ Redimensionnement automatique…"

        target_mib=$(( expected_root_size_gb * 1024 ))
        root_part_num=$(basename "$root_partition" | grep -o '[0-9]*$')

        echo "📐 Redimensionnement de la partition $root_partition à ${target_mib}MiB…"
        parted -s "$selected_dev" resizepart "$root_part_num" "${target_mib}MiB"

        echo "🔍 Vérification du système de fichiers avec e2fsck…"
        e2fsck -f "$root_partition"

        echo "🧱 Redimensionnement avec resize2fs…"
        resize2fs "$root_partition"

        echo "✅ Partition root étendue à ${expected_root_size_gb} Go"

    elif (( abs_delta <= tolerance )); then
        echo "ℹ️  La taille de la partition ROOT est approximativement correcte (${root_size_gb} Go ~ ${expected_root_size_gb} Go)"
    else
        echo "❌ La partition ROOT est TROP GRANDE (${root_size_gb} Go > ${expected_root_size_gb} Go)"
        echo "   ➤ Réduction non prise en charge automatiquement. Arrêt du script."
        exit 1
    fi
}

