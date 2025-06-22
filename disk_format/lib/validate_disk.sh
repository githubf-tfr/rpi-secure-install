#!/bin/bash

validate_disk_labels() {
    echo ""
    echo "📦 Partitions du disque sélectionné ($selected_dev) :"
    lsblk -pn -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$selected_dev" | sed '1d' | sed 's/^/    /'

    readarray -t detected_labels < <(
        lsblk -pn -o LABEL "$selected_dev" | sed '1d' | grep -v '^$'
    )

    if [[ "$DEBUG" == "1" ]]; then
        echo "[DEBUG] Labels détectés : ${detected_labels[*]}"
    fi

    echo ""
    echo "🔎 Vérification du disque sélectionné : $selected_dev"

    if [[ "${#detected_labels[@]}" -ne 2 ]]; then
        echo "❌ Le disque doit contenir exactement 2 partitions avec des labels définis (boot et root)."
        echo "    Labels trouvés : ${detected_labels[*]}"
        exit 1
    fi

    label1=$(echo "${detected_labels[0]}" | tr '[:upper:]' '[:lower:]')
    label2=$(echo "${detected_labels[1]}" | tr '[:upper:]' '[:lower:]')

    valid_boot=0
    valid_root=0

    for lbl in "$label1" "$label2"; do
        [[ "$lbl" == "boot" || "$lbl" == "bootfs" ]] && valid_boot=1
        [[ "$lbl" == "root" || "$lbl" == "rootfs" ]] && valid_root=1
    done

    if [[ "$valid_boot" -ne 1 || "$valid_root" -ne 1 ]]; then
        echo "❌ Les partitions doivent avoir les labels : boot (ou bootfs) ET root (ou rootfs)."
        echo "    Labels trouvés : $label1, $label2"
        exit 1
    fi

    echo "✅ Disque compatible détecté avec les labels : $label1, $label2"
}

