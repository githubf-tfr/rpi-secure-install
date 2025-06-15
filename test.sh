#!/bin/bash

set -e

DEBUG=1
echo "🔍 Détection des périphériques USB..."

# Récupère tous les périphériques block avec interface USB (même non montés)
readarray -t usb_devices < <(lsblk -S -o NAME,TRAN | awk '$2 == "usb" {print $1}')

# Mode debug : afficher le contenu brut du tableau usb_devices
if [[ "$DEBUG" == "1" ]]; then
  echo "[DEBUG] usb_devices = ${usb_devices[*]}"
fi

if [[ -z "$usb_devices" ]]; then
  echo "❌ Aucun périphérique USB détecté."
  exit 1
fi

echo ""
echo "📋 Liste des périphériques USB disponibles :"
echo ""

index=0
for dev in "${usb_devices[@]}"; do
  if [[ "$DEBUG" == "1" ]]; then
    printf '[DEBUG] raw dev: "%s"\n' "$dev"
  fi
  full_dev="/dev/$dev"
  echo "[$index] $full_dev"
  lsblk "$full_dev" -o NAME,SIZE,LABEL,TYPE,MOUNTPOINT | sed '1d' | sed 's/^/    /'
  echo ""
  index=$((index+1))
done

# Choisir le disque/usb à partitionner
read -p "👉 Entrez le numéro du disque à utiliser : " selected_index
selected_dev="/dev/${usb_devices[$selected_index]}"

if [[ ! -b "$selected_dev" ]]; then
  echo "❌ Erreur : périphérique invalide sélectionné."
  exit 1
fi

echo "✅ Vous avez sélectionné : $selected_dev"

echo ""
echo "📦 Partitions du disque sélectionné ($selected_dev) :"
lsblk -pn -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$selected_dev" | sed '1d' | sed 's/^/    /'

readarray -t labels < <(
  lsblk -pn -o LABEL "$selected_dev" | sed '1d' | grep -v '^$'
)

if [[ "$DEBUG" == "1" ]]; then
  echo "[DEBUG] Labels détectés : ${labels[*]}"
fi

#Contrôle de l'usb

echo ""
echo "🔎 Vérification du disque sélectionné : $selected_dev"

#### Récupérer les labels des partitions
readarray -t detected_labels < <(lsblk -pn -o LABEL "$selected_dev" | sed '1d' | grep -v '^$')

if [[ "${#detected_labels[@]}" -ne 2 ]]; then
  echo "❌ Le disque doit contenir exactement 2 partitions avec des labels définis (boot et root)."
  echo "    Labels trouvés : ${detected_labels[*]}"
  exit 1
fi

#### Convertir en minuscule pour standardiser
label1=$(echo "${detected_labels[0]}" | tr '[:upper:]' '[:lower:]')
label2=$(echo "${detected_labels[1]}" | tr '[:upper:]' '[:lower:]')

#### Vérifier que les deux labels sont présents
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

# Choisir le profil

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

# Charger le profil sélectionné
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


# === Calcul de la capacité totale demandée ===
total_requested_gb=0
for entry in "${PARTITIONS[@]}"; do
  IFS=":" read -r LABEL SIZE TYPE MOUNT OPTIONS <<< "$entry"
  total_requested_gb=$(echo "$total_requested_gb + $SIZE" | bc)
done

# === Taille du disque sélectionné (en Go, arrondi)
disk_size_bytes=$(lsblk -nb -o SIZE "$selected_dev" | head -n1)
disk_size_gb=$(awk "BEGIN { printf \"%.0f\", $disk_size_bytes / (1024*1024*1024) }")

echo "📏 Espace demandé par le profil : ${total_requested_gb} Go"
echo "💽 Capacité du disque détecté : ${disk_size_gb} Go"

# === Vérification
if (( $(echo "$total_requested_gb > $disk_size_gb" | bc -l) )); then
  echo "❌ Le disque est trop petit pour le profil sélectionné !"
  echo "   Profil : ${total_requested_gb} Go > Disque : ${disk_size_gb} Go"
  exit 1
else
  echo "✅ Espace disque suffisant pour le profil sélectionné."
fi


# Trouver le chemin de la partition ROOT/ROOTFS
root_partition=$(lsblk -nrp -o NAME,LABEL "$selected_dev" \
  | awk -v label="$label2" '$2 == label { print $1 }')

if [[ -z "$root_partition" ]]; then
  echo "❌ Impossible de localiser la partition root/rootfs."
  exit 1
fi

# Obtenir la taille en GiB (arrondie)
root_size_gb=$(lsblk -nb -o SIZE "$root_partition" | awk '{ printf "%.0f", $1 / (1024^3) }')

echo "📦 Taille de la partition root (${label2}) : ${root_size_gb} Go"

# Extraire la taille cible du profil pour la partition ROOT
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

echo ""
echo "🔎 Comparaison : partition ROOT actuelle vs profil"

if (( root_size_gb < expected_root_size_gb )); then
  echo "⚠️  La partition ROOT est TROP PETITE ($root_size_gb Go < $expected_root_size_gb Go)"
  echo "   ➤ Prévoir un agrandissement."
elif (( root_size_gb > expected_root_size_gb )); then
  echo "⚠️  La partition ROOT est TROP GRANDE ($root_size_gb Go > $expected_root_size_gb Go)"
  echo "   ➤ Prévoir une réduction (⚠️ à manipuler avec précaution !)"
else
  echo "✅ La taille de ROOT correspond au profil : $root_size_gb Go"
fi

echo ""
echo "🔎 Comparaison de la taille de la partition ROOT"

# Calcul de la différence
delta=$(( root_size_gb - expected_root_size_gb ))
abs_delta=${delta#-}  # valeur absolue

# Seuil de tolérance (1 Go ≈ 1%)
tolerance=1

if (( delta < -tolerance )); then
  echo "⚠️  La partition ROOT est TROP PETITE (${root_size_gb} Go < ${expected_root_size_gb} Go)"
  echo "   ➤ Lancement du processus d’agrandissement automatique (à venir ici...)"

  # Conversion de la taille attendue en MiB
  target_mib=$(( expected_root_size_gb * 1024 ))

  # Numéro de la partition ROOT (ex: /dev/sdc2 → 2)
  root_part_num=$(basename "$root_partition" | grep -o '[0-9]*$')

  # Commande pour redimensionner la partition
  echo "📐 Redimensionnement de la partition $root_partition à ${target_mib}MiB…"
  parted -s "$selected_dev" resizepart "$root_part_num" "${target_mib}MiB"
  # ✅ Vérification du système de fichiers
  echo "🔍 Vérification du système de fichiers ext4 avec e2fsck…"
  e2fsck -f "$root_partition"
  # Redimensionnement du système de fichiers
  echo "🧱 Redimensionnement du système de fichiers ext4 avec resize2fs…"
  resize2fs "$root_partition"

  echo "✅ Partition root étendue à ${expected_root_size_gb} Go"
  
elif (( abs_delta <= tolerance )); then
  echo "ℹ️  La taille de la partition ROOT est approximativement correcte (${root_size_gb} Go ~ ${expected_root_size_gb} Go)"
  echo "   ➤ On passe à la suite."

else
  echo "❌ La partition ROOT est TROP GRANDE (${root_size_gb} Go > ${expected_root_size_gb} Go)"
  echo "   ➤ Réduction non gérée automatiquement. Arrêt du script."
  exit 1
fi

DISK=$selected_dev
# Vérifie que seules les deux premières partitions (boot + root) existent
nb_parts=$(lsblk -n -o NAME "$DISK" | grep -E "^$(basename "$DISK")" | wc -l)

table_type=$(parted -s "$DISK" print | grep "Partition Table" | awk '{print $3}')

if [[ "$table_type" == "gpt" ]]; then
  echo "❌ Table de partition détectée : GPT"
  echo "   Ce cas n'est pas traité automatiquement. Contactez le développeur."
  exit 1
elif [[ "$table_type" != "msdos" ]]; then
  echo "❌ Type de partition non reconnu : $table_type"
  echo "   Seuls les disques avec table de type 'msdos' (MBR) sont supportés pour l'instant."
  exit 1
fi




if (( nb_parts > 2 )); then
  echo "⚠️  Ce disque a déjà plus de 2 partitions."
  echo "   → Il semble que le partitionnement ait déjà été effectué."
  echo "   ❌ Arrêt du script pour éviter un doublon ou une destruction."
  exit 1
fi


# Réinitialisation du point de départ (fin de l'espace libre)
START_MIB=$(parted -sm "$DISK" unit MiB print free | grep ":free;" | tail -1 | cut -d: -f2 | sed 's/MiB//')

PART_NUM=3

if [[ -z "$START_MIB" || -z "$PART_NUM" ]]; then
  echo "❌ ERREUR : Impossible de déterminer START_MIB ou PART_NUM. Abandon."
  exit 1
fi

# === Création des partitions complémentaires ===
for entry in "${PARTITIONS[@]}"; do

  IFS=":" read -r LABEL SIZE TYPE MOUNT OPTIONS <<< "$entry"

  # Sauter les partitions déjà existantes
  [[ "$MOUNT" == "/" || "$MOUNT" == "/boot" ]] && continue

  END_MIB=$(echo "$START_MIB + ($SIZE * 1024)" | bc | awk '{printf "%d", $0}')

  echo "➕ Création de $LABEL ($SIZE Go) - $TYPE : ${START_MIB}MiB à ${END_MIB}MiB"
  
  if [[ "$DEBUG" == "1" ]]; then
    echo "[DEBUG] LABEL=$LABEL, TYPE=<$TYPE>, MOUNT=$MOUNT"
  fi

  DEV_PART="${DISK}${PART_NUM}"
  echo "$DEV_PART"
  if [[ "$TYPE" == "swap" ]]; then
    parted -s "$DISK" mkpart primary "${START_MIB}MiB" "${END_MIB}MiB"
    mkswap -L "$LABEL" "$DEV_PART"
  else
    parted -s "$DISK" mkpart primary "$TYPE" "${START_MIB}MiB" "${END_MIB}MiB"
    mkfs."$TYPE" -L "$LABEL" "$DEV_PART"
  fi


  echo "[DEBUG] PART_NUM = $PART_NUM"
  


  START_MIB=$END_MIB
  ((PART_NUM++))
done
