#!/bin/bash

create_additional_partitions() {
    echo ""
    echo "🔧 Vérification de la table de partition sur $selected_dev"

    table_type=$(parted -s "$selected_dev" print | grep "Partition Table" | awk '{print $3}')
    if [[ "$table_type" == "gpt" ]]; then
        echo "❌ Table de partition détectée : GPT"
        echo "   Ce cas n'est pas encore géré automatiquement."
        exit 1
    elif [[ "$table_type" != "msdos" ]]; then
        echo "❌ Type de partition non reconnu : $table_type"
        echo "   Seul 'msdos' (MBR) est supporté pour l'instant."
        exit 1
    fi

    nb_parts=$(lsblk -n -o NAME "$selected_dev" | grep -E "^$(basename "$selected_dev")" | wc -l)
    if (( nb_parts > 2 )); then
        echo "⚠️  Ce disque contient déjà plus de 2 partitions."
        echo "   → Partitionnement probablement déjà réalisé. Arrêt."
        exit 1
    fi

    START_MIB=$(parted -sm "$selected_dev" unit MiB print free | grep ":free;" | tail -1 | cut -d: -f2 | sed 's/MiB//')
    PART_NUM=3

    if [[ -z "$START_MIB" || -z "$PART_NUM" ]]; then
        echo "❌ Impossible de déterminer START_MIB ou PART_NUM. Abandon."
        exit 1
    fi

    echo ""
    echo "🧱 Création des partitions complémentaires à partir de ${START_MIB}MiB…"

    for entry in "${PARTITIONS[@]}"; do
        IFS=":" read -r LABEL SIZE TYPE MOUNT OPTIONS <<< "$entry"

        [[ "$MOUNT" == "/" || "$MOUNT" == "/boot" ]] && continue

        END_MIB=$(echo "$START_MIB + ($SIZE * 1024)" | bc | awk '{printf "%d", $0}')
        DEV_PART="${selected_dev}${PART_NUM}"

        echo "➕ Création de $LABEL ($SIZE Go) - $TYPE : ${START_MIB}MiB → ${END_MIB}MiB"

        if [[ "$TYPE" == "swap" ]]; then
            parted -s "$selected_dev" mkpart primary "${START_MIB}MiB" "${END_MIB}MiB"
            mkswap -L "$LABEL" "$DEV_PART"
        else
            parted -s "$selected_dev" mkpart primary "$TYPE" "${START_MIB}MiB" "${END_MIB}MiB"
            mkfs."$TYPE" -L "$LABEL" "$DEV_PART"
        fi

        [[ "$DEBUG" == "1" ]] && echo "[DEBUG] Partition $PART_NUM : $LABEL ($TYPE), $MOUNT"

        START_MIB=$END_MIB
        ((PART_NUM++))
    done

    echo "✅ Création des partitions complémentaires terminée."
}

