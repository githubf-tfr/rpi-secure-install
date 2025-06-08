#!/bin/bash

# === Disque ciblé (à adapter manuellement) ===
DISK="/dev/sdX"  # Remplace "sdX" par "sda", "sdb", etc.

# === Liste des partitions : LABEL:TAILLE(Go):TYPE:POINT_DE_MONTAGE:OPTIONS fstab ===
PARTITIONS=(
  "BOOT:0.25:fat32:/boot:defaults"
  "ROOT:15:ext4:/:defaults"
  "SWAP:2:swap:none:sw"
  "HOME:1:ext4:/home:defaults,nodev"
  "VAR:20:ext4:/var:defaults"
  "VARLOG:10:ext4:/var/log:defaults,nodev,nosuid,noexec"
  "AUDIT:5:ext4:/var/log/audit:defaults,nodev,nosuid,noexec"
  "DOCKER:60:ext4:/Docker:defaults,nodev,nosuid,noexec"
)

# === TMPFS mounts : MONTAGE:OPTIONS ===
TMPFS_MOUNTS=(
  "/tmp:defaults,noexec,nosuid,nodev,size=1G"
  "/var/tmp:defaults,noexec,nosuid,nodev,size=1G"
)

