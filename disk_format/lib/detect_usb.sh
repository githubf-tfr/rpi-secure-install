#!/bin/bash

detect_usb_devices() {
    echo "🔍 Détection des périphériques USB..."
    readarray -t usb_devices < <(lsblk -S -o NAME,TRAN | awk '$2 == "usb" {print $1}')

    if [[ "$DEBUG" == "1" ]]; then
        echo "[DEBUG] usb_devices = ${usb_devices[*]}"
    fi

    if [[ -z "${usb_devices[*]}" ]]; then
        echo "❌ Aucun périphérique USB détecté."
        exit 1
    fi
}

select_usb_device() {
    echo ""
    echo "📋 Liste des périphériques USB disponibles :"
    echo ""

    index=0
    for dev in "${usb_devices[@]}"; do
        if [[ "$DEBUG" == "1" ]]; then
            printf '[DEBUG] raw dev: \"%s\"\n' "$dev"
        fi
        full_dev=\"/dev/$dev\"
        echo \"[$index] $full_dev\"
        lsblk \"$full_dev\" -o NAME,SIZE,LABEL,TYPE,MOUNTPOINT | sed '1d' | sed 's/^/    /'
        echo \"\"
        index=$((index+1))
    done

    read -p \"👉 Entrez le numéro du disque à utiliser : \" selected_index
    selected_dev=\"/dev/${usb_devices[$selected_index]}\"

    if [[ ! -b \"$selected_dev\" ]]; then
        echo \"❌ Erreur : périphérique invalide sélectionné.\"
        exit 1
    fi

    echo \"✅ Vous avez sélectionné : $selected_dev\"
}

