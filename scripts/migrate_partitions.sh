#!/bin/bash

set -e

CONFIG_FILE="config/default_120gb.sh"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Fichier de configuration introuvable : $CONFIG_FILE"
  exit 1
fi

source "$CONFIG_FILE"

# === Vérification du disque ===
echo "💡 Ce script ajoute des partitions SANS toucher au système existant."
echo "Disque cible : $DISK"
read -p "Continuer ? (y/N) " confirm
[[ "$confirm" != "y" && "$confirm" != "Y" ]] && exit 1

START_MIB=$(parted -sm "$DISK" unit MiB print free | grep ":free;" | tail -1 | cut -d: -f2 | sed 's/MiB//')
PART_NUM=$(lsblk -n -o NAME "$DISK" | grep -c "^$(basename "$DISK")")

# === Ajout et formatage des partitions complémentaires ===
for entry in "${PARTITIONS[@]}"; do
  IFS=":" read -r LABEL SIZE TYPE MOUNT OPTIONS <<< "$entry"

  # On ignore les partitions déjà existantes (/boot, /)
  [[ "$MOUNT" == "/" || "$MOUNT" == "/boot" ]] && continue

  END_MIB=$(echo "$START_MIB + ($SIZE * 1024)" | bc | awk '{printf "%d", $0}')

  echo "➕ Création de $LABEL ($SIZE Go) - $TYPE : ${START_MIB}MiB à ${END_MIB}MiB"
  if [[ \"$TYPE\" == \"swap\" ]]; then
    parted -s \"$DISK\" mkpart \"$LABEL\" linux-swap ${START_MIB}MiB ${END_MIB}MiB
  else
    parted -s \"$DISK\" mkpart \"$LABEL\" \"$TYPE\" ${START_MIB}MiB ${END_MIB}MiB
  fi


  DEV_PART="${DISK}${PART_NUM}"
  case "$TYPE" in
    ext4)
      echo "🔠 Formatage ext4 de $DEV_PART (LABEL=$LABEL)"
      mkfs.ext4 -L "$LABEL" "$DEV_PART"
      ;;
    swap)
      echo "💤 Initialisation swap sur $DEV_PART"
      mkswap -L "$LABEL" "$DEV_PART"
      ;;
  esac

  START_MIB=$END_MIB
  ((PART_NUM++))
done

# === Migration des données existantes ===
echo "📂 Migration des données vers les nouvelles partitions..."
MOUNT_TMP="/mnt/tmpmig"
mkdir -p "$MOUNT_TMP"

for entry in "${PARTITIONS[@]}"; do
  IFS=":" read -r LABEL SIZE TYPE MOUNT OPTIONS <<< "$entry"
  [[ "$MOUNT" == "/" || "$MOUNT" == "/boot" || "$MOUNT" == "none" ]] && continue

  DEV_PART="$(blkid -L "$LABEL")"
  echo "🔗 Montage $LABEL sur $MOUNT_TMP"
  mount "$DEV_PART" "$MOUNT_TMP"

  echo "🔄 Copie de $MOUNT → $MOUNT_TMP (rsync)"
  rsync -aAXH --exclude="lost+found" "$MOUNT/" "$MOUNT_TMP/"

  echo "🔌 Démontage temporaire de $MOUNT_TMP"
  umount "$MOUNT_TMP"

done

# === Ajout au fstab ===
echo "📝 Mise à jour de /etc/fstab"
BACKUP_FSTAB="/etc/fstab.bak.$(date +%s)"
sudo cp /etc/fstab "$BACKUP_FSTAB"
echo "📦 Sauvegarde de fstab dans $BACKUP_FSTAB"

for entry in "${PARTITIONS[@]}"; do
  IFS=":" read -r LABEL SIZE TYPE MOUNT OPTIONS <<< "$entry"
  [[ "$MOUNT" == "/" || "$MOUNT" == "/boot" || "$MOUNT" == "none" ]] && continue

  grep -q "LABEL=$LABEL" /etc/fstab || echo "LABEL=$LABEL $MOUNT $TYPE $OPTIONS 0 2" >> /etc/fstab

done

echo "✅ Migration et mise à jour terminées. Redémarrez pour tester les montages."
