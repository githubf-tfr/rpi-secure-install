#!/bin/bash

# === Disque ciblé (à adapter manuellement) ===
DISK="/dev/sdX"  # Remplace "sdX" par "sda", "sdb", etc.

# === Liste des partitions : LABEL:TAILLE(Go):TYPE:POINT_DE_MONTAGE ===
PARTITIONS=(
  "BOOT:0.25:fat32:/boot"
  "ROOT:15:ext4:/"
  "SWAP:2:swap:none"
  "HOME:1:ext4:/home"
  "VAR:20:ext4:/var"
  "VARLOG:10:ext4:/var/log"
  "AUDIT:5:ext4:/var/log/audit"
  "DOCKER:60:ext4:/Docker"
)

# === TMPFS mounts (en RAM) ===
TMPFS_MOUNTS=(
  "/tmp:size=1G"
  "/var/tmp:size=1G"
)
