#!/bin/bash
set -e

# === CONFIGURATION GLOBALE ===
DEBUG=1

# === IMPORT DES FONCTIONS ===
source "lib/detect_usb.sh"
source "lib/validate_disk.sh"
source "lib/load_profile.sh"
source "lib/partition_utils.sh"
source "lib/resize_root.sh"
source "lib/create_partitions.sh"

# === FONCTION PRINCIPALE ===
main() {
    detect_usb_devices
    select_usb_device
    validate_disk_labels
    load_profile_config
    check_disk_capacity
    resize_root_partition_if_needed
    create_additional_partitions
}

main "$@"
