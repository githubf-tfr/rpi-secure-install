#!/bin/bash

set -e

# === Charger la configuration ===
CONFIG_FILE="config/default_120gb.sh"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Fichier de configuration introuvable : $CONFIG_FILE"
  exit 1
fi

source "$CONFIG_FILE"

# === Variables internes ===
START_MIB=1
PARTED_CMDS=()
FSTAB_LINES=()

# === Calcul des partitions ===
echo "# Aperçu du plan de partitionnement"
echo "Disque cible : $DISK"
echo ""

i=1
for entry in "${PARTITIONS[@]}"; do
  IFS=":" read -r LABEL SIZE TYPE MOUNT <<< "$entry"

  END_MIB=$(echo "$START_MIB + ($SIZE * 1024)" | bc | awk '{printf "%d", $0}')
  DEVICE="${DISK}${i}"

  echo "Partition $i : $LABEL ($SIZE Go) => $TYPE sur $MOUNT"
  PARTED_CMDS+=("mkpart $LABEL $TYPE ${START_MIB}MiB ${END_MIB}MiB")

  if [[ "$TYPE" == "swap" ]]; then
    FSTAB_LINES+=("$DEVICE none swap sw 0 0")
  elif [[ "$MOUNT" != "none" ]]; then
    FSTAB_LINES+=("$DEVICE $MOUNT $TYPE defaults 0 2")
  fi

  START_MIB=$END_MIB
  ((i++))
done

# === TMPFS mounts ===
for tmpfs in "${TMPFS_MOUNTS[@]}"; do
  IFS=":" read -r MOUNT_OPT <<< "$tmpfs"
  FSTAB_LINES+=("tmpfs $MOUNT_OPT tmpfs defaults 0 0")
done

# === Affichage des commandes parted ===
echo -e "\n# Commandes parted :"
echo "parted $DISK mklabel gpt"
for cmd in "${PARTED_CMDS[@]}"; do
  echo "parted $DISK $cmd"
done

# === Aperçu du fichier fstab ===
echo -e "\n# Aperçu de /etc/fstab :"
for line in "${FSTAB_LINES[@]}"; do
  echo "$line"
done
