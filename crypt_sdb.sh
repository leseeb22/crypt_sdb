#!/usr/bin/env bash
# =========================================================================
#  Script de sécurisation de disque (interne ou externe)
#  Version: 1.0.0
#  Date: 25/05/2023
#  Fonctionnalités :
#  - Paramétrage du périphérique cible
#  - Vérification préalable de l'existence de données
#  - Test destructif badblocks -wsv (optionnel)
#  - Chiffrement LUKS (clé /root/.keys), formatage EXT4 ou autre
#  - Montage automatique via crypttab + fstab
#  Arrêt immédiat sur erreur (set -e) ; journal complet /var/log/crypt_sdb.log
# =========================================================================

set -euo pipefail

# ---------- VARIABLES PAR DÉFAUT -----------------------------------------
DEFAULT_DISK="/dev/sdb"
MAP="disque_securise"
MNT="/mnt/${MAP}"
KEYDIR="/root/.keys"
KEYFILE="${KEYDIR}/${MAP}.key"
LOG="/var/log/crypt_sdb.log"
KEY_SIZE=4 # Taille de la clé en Ko
FS_TYPE="ext4" # Type de système de fichiers par défaut
# -------------------------------------------------------------------------

trap 'echo "ERREUR ligne $LINENO – consulte $LOG"; tail -n 20 "$LOG"; exit 1' ERR
exec > >(tee -a "$LOG") 2>&1

echo "=== DÉBUT – $(date) ==="

############################################################################
# 0) SÉLECTION DU PÉRIPHÉRIQUE CIBLE
############################################################################

# Utiliser le premier argument comme périphérique cible s'il est fourni
if [ $# -ge 1 ]; then
    DISK="$1"
else
    # Afficher les disques disponibles
    echo "Disques disponibles :"
    lsblk -d -o NAME,SIZE,MODEL,VENDOR
    echo ""
    
    # Demander à l'utilisateur de choisir un périphérique
    read -rp "Entrez le périphérique cible (par défaut: $DEFAULT_DISK): " USER_DISK
    DISK=${USER_DISK:-$DEFAULT_DISK}
fi

# Vérifier que le périphérique existe
if [ ! -b "$DISK" ]; then
    echo "ERREUR: Le périphérique $DISK n'existe pas ou n'est pas un périphérique bloc."
    exit 1
fi

PART="${DISK}1"
echo "Périphérique cible sélectionné: $DISK"

############################################################################
# 1) VÉRIFICATION DE L'EXISTENCE DE DONNÉES
############################################################################
echo "Vérification de l'existence de données sur $DISK..."

# Vérifier si le disque contient des partitions
PARTITIONS=$(lsblk -n -o NAME "$DISK" | grep -v "$(basename "$DISK")$" | wc -l)

if [ "$PARTITIONS" -gt 0 ]; then
    echo "ATTENTION: Le disque $DISK contient $PARTITIONS partition(s)."
    
    # Afficher les partitions et leur utilisation
    echo "Détails des partitions:"
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL "$DISK"
    
    read -rp "Êtes-vous ABSOLUMENT SÛR de vouloir effacer TOUTES les données sur $DISK? (yes/NO): " CONFIRM
    if [[ ${CONFIRM,,} != "yes" ]]; then
        echo "Opération annulée par l'utilisateur."
        exit 0
    fi
fi

############################################################################
# 2) CHOIX : lancer ou non badblocks -wsv
############################################################################
read -rp "Lancer le test badblocks DESTRUCTIF (écriture) ? (yes/no) : " BB
if [[ ${BB,,} == "yes" || ${BB,,} == "y" ]]; then
    echo "= badblocks -wsv (TOUTES données supprimées) ="
    umount "$PART" 2>/dev/null || true
    badblocks -wsv "$DISK"
    echo "= badblocks terminé – zéro erreur ="   # si set -e : stoppe s'il y a des erreurs
else
    echo "= badblocks SKIPPÉ à votre demande ="
fi

############################################################################
# 3) CHOIX DU SYSTÈME DE FICHIERS
############################################################################
echo "Systèmes de fichiers disponibles: ext4, xfs, btrfs"
read -rp "Choisissez le système de fichiers (par défaut: $FS_TYPE): " USER_FS
FS_TYPE=${USER_FS:-$FS_TYPE}

############################################################################
# 4) GÉNÉRATION CLÉ LUKS
############################################################################
echo "= Génération clé LUKS (${KEY_SIZE} Ko) ="
mkdir -p "$KEYDIR"
chmod 700 "$KEYDIR"
dd if=/dev/urandom of="$KEYFILE" bs=1024 count=$KEY_SIZE status=none
chmod 600 "$KEYFILE"

# Option de sauvegarde de la clé
read -rp "Voulez-vous sauvegarder la clé de chiffrement? (yes/no): " BACKUP_KEY
if [[ ${BACKUP_KEY,,} == "yes" || ${BACKUP_KEY,,} == "y" ]]; then
    BACKUP_PATH="/root/backup_${MAP}_key_$(date +%Y%m%d).key"
    cp "$KEYFILE" "$BACKUP_PATH"
    chmod 600 "$BACKUP_PATH"
    echo "Clé sauvegardée dans $BACKUP_PATH"
    echo "IMPORTANT: Conservez cette clé dans un endroit sécurisé. Sans elle, vos données seront irrécupérables."
fi

############################################################################
# 5) PARTITION GPT
############################################################################
echo "= Table GPT + partition primaire 100 % ="
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary 0% 100%

############################################################################
# 6) CHIFFREMENT + OUVERTURE
############################################################################
echo "= Chiffrement LUKS + ouverture ="
cryptsetup luksFormat "$PART" "$KEYFILE" --batch-mode
cryptsetup luksOpen "$PART" "$MAP" --key-file "$KEYFILE"

############################################################################
# 7) FORMATAGE + MONTAGE
############################################################################
echo "= Formatage $FS_TYPE + montage ="

# Formatage selon le système de fichiers choisi
case "$FS_TYPE" in
    "ext4")
        mkfs.ext4 -L "$MAP" "/dev/mapper/$MAP"
        ;;
    "xfs")
        mkfs.xfs -L "$MAP" "/dev/mapper/$MAP"
        ;;
    "btrfs")
        mkfs.btrfs -L "$MAP" "/dev/mapper/$MAP"
        ;;
    *)
        echo "Système de fichiers non supporté: $FS_TYPE. Utilisation de ext4 par défaut."
        mkfs.ext4 -L "$MAP" "/dev/mapper/$MAP"
        FS_TYPE="ext4"
        ;;
esac

mkdir -p "$MNT"
mount "/dev/mapper/$MAP" "$MNT"

############################################################################
# 8) CONFIGURATION DÉMARRAGE AUTO
############################################################################
UUID=$(blkid -s UUID -o value "$PART")
grep -qxF "$MAP" /etc/crypttab || echo "${MAP} UUID=${UUID} ${KEYFILE} luks" >> /etc/crypttab
grep -qxF "$MNT" /etc/fstab || echo "/dev/mapper/${MAP} ${MNT} $FS_TYPE defaults 0 2" >> /etc/fstab
sync

echo "=== FIN sans erreur – $(date) ==="
echo "Disque $DISK configuré avec succès:"
echo "- Partition chiffrée avec LUKS"
echo "- Formaté en $FS_TYPE"
echo "- Monté sur $MNT"
echo "- Configuration automatique au démarrage"
