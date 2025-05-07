# Analyse du script `crypt_sdb.sh`

## Objectif du script

Ce script est un utilitaire avancé de sécurisation de disque (interne ou externe) qui permet de :
1. Paramétrer le périphérique cible (en argument ou interactivement)
2. Vérifier l'existence de données sur le disque avant manipulation
3. Tester l'intégrité physique du disque (optionnel)
4. Créer une partition chiffrée avec LUKS
5. Formater cette partition avec différents systèmes de fichiers (ext4, xfs, btrfs)
6. Configurer le montage automatique au démarrage
7. Sauvegarder la clé de chiffrement (optionnel)

## Structure et fonctionnalités

### Configuration initiale

```bash
set -euo pipefail
```
Cette ligne est cruciale pour la sécurité du script :
- `set -e` : Arrête l'exécution immédiatement si une commande échoue
- `set -u` : Considère l'utilisation de variables non définies comme une erreur
- `set -o pipefail` : Fait échouer un pipeline si l'une des commandes échoue

### Variables principales

- `DEFAULT_DISK="/dev/sdb"` : Périphérique cible par défaut
- `DISK` : Périphérique cible sélectionné par l'utilisateur ou par défaut
- `PART="${DISK}1"` : Première partition du disque
- `MAP="disque_securise"` : Nom du périphérique mappé après déchiffrement
- `MNT="/mnt/${MAP}"` : Point de montage
- `KEYDIR="/root/.keys"` : Répertoire pour stocker la clé de chiffrement
- `KEYFILE="${KEYDIR}/${MAP}.key"` : Fichier de clé
- `LOG="/var/log/crypt_sdb.log"` : Fichier de journalisation
- `KEY_SIZE=4` : Taille de la clé en Ko
- `FS_TYPE="ext4"` : Type de système de fichiers par défaut

### Mécanismes de sécurité

1. **Gestion des erreurs** :
   ```bash
   trap 'echo "ERREUR ligne $LINENO – consulte $LOG"; tail -n 20 "$LOG"; exit 1' ERR
   ```
   Cette ligne capture toutes les erreurs, affiche le numéro de ligne où l'erreur s'est produite, montre les 20 dernières lignes du journal et arrête le script.

2. **Journalisation complète** :
   ```bash
   exec > >(tee -a "$LOG") 2>&1
   ```
   Redirige toute la sortie standard et d'erreur vers le terminal ET vers le fichier journal.

### Étapes principales

#### 0. Sélection du périphérique cible

Le script permet désormais de spécifier le périphérique cible de plusieurs façons :
```bash
# Utiliser le premier argument comme périphérique cible s'il est fourni
if [ $# -ge 1 ]; then
    DISK="$1"
else
    # Afficher les disques disponibles
    echo "Disques disponibles :"
    lsblk -d -o NAME,SIZE,MODEL,VENDOR
    
    # Demander à l'utilisateur de choisir un périphérique
    read -rp "Entrez le périphérique cible (par défaut: $DEFAULT_DISK): " USER_DISK
    DISK=${USER_DISK:-$DEFAULT_DISK}
fi
```

Le script vérifie également que le périphérique existe avant de continuer :
```bash
if [ ! -b "$DISK" ]; then
    echo "ERREUR: Le périphérique $DISK n'existe pas ou n'est pas un périphérique bloc."
    exit 1
fi
```

#### 1. Vérification de l'existence de données

Le script vérifie maintenant si le disque contient déjà des partitions et demande une confirmation explicite avant de continuer :
```bash
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
```

#### 2. Test d'intégrité du disque (optionnel)

Le script propose d'exécuter `badblocks` en mode destructif pour vérifier l'intégrité physique du disque :
```bash
badblocks -wsv "$DISK"
```
Options :
- `-w` : Mode écriture (destructif)
- `-s` : Affiche la progression
- `-v` : Mode verbeux

#### 3. Choix du système de fichiers

Le script permet maintenant de choisir entre différents systèmes de fichiers :
```bash
echo "Systèmes de fichiers disponibles: ext4, xfs, btrfs"
read -rp "Choisissez le système de fichiers (par défaut: $FS_TYPE): " USER_FS
FS_TYPE=${USER_FS:-$FS_TYPE}
```

#### 4. Génération de la clé LUKS

```bash
mkdir -p "$KEYDIR"
chmod 700 "$KEYDIR"
dd if=/dev/urandom of="$KEYFILE" bs=1024 count=$KEY_SIZE status=none
chmod 600 "$KEYFILE"
```

Cette section :
- Crée le répertoire pour la clé avec des permissions restrictives (700 = rwx-----)
- Génère une clé aléatoire de taille configurable (par défaut 4 Ko) à partir de `/dev/urandom`
- Définit des permissions restrictives sur le fichier de clé (600 = rw-------)

Le script propose également de sauvegarder la clé :
```bash
read -rp "Voulez-vous sauvegarder la clé de chiffrement? (yes/no): " BACKUP_KEY
if [[ ${BACKUP_KEY,,} == "yes" || ${BACKUP_KEY,,} == "y" ]]; then
    BACKUP_PATH="/root/backup_${MAP}_key_$(date +%Y%m%d).key"
    cp "$KEYFILE" "$BACKUP_PATH"
    chmod 600 "$BACKUP_PATH"
    echo "Clé sauvegardée dans $BACKUP_PATH"
    echo "IMPORTANT: Conservez cette clé dans un endroit sécurisé. Sans elle, vos données seront irrécupérables."
fi
```

#### 5. Partitionnement GPT

```bash
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary 0% 100%
```

Crée une table de partition GPT et une partition primaire utilisant 100% de l'espace disponible.

#### 6. Chiffrement et ouverture LUKS

```bash
cryptsetup luksFormat "$PART" "$KEYFILE" --batch-mode
cryptsetup luksOpen "$PART" "$MAP" --key-file "$KEYFILE"
```

Cette section :
- Formate la partition avec LUKS en utilisant la clé générée
- Ouvre la partition chiffrée et la mappe sous `/dev/mapper/$MAP`

#### 7. Formatage et montage

Le script supporte maintenant plusieurs systèmes de fichiers :
```bash
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
```

Puis monte le système de fichiers :
```bash
mkdir -p "$MNT"
mount "/dev/mapper/$MAP" "$MNT"
```

#### 8. Configuration du démarrage automatique

```bash
UUID=$(blkid -s UUID -o value "$PART")
grep -qxF "$MAP" /etc/crypttab || echo "${MAP} UUID=${UUID} ${KEYFILE} luks" >> /etc/crypttab
grep -qxF "$MNT" /etc/fstab || echo "/dev/mapper/${MAP} ${MNT} $FS_TYPE defaults 0 2" >> /etc/fstab
sync
```

Cette section :
- Récupère l'UUID de la partition
- Ajoute une entrée dans `/etc/crypttab` pour le déchiffrement automatique au démarrage (si elle n'existe pas déjà)
- Ajoute une entrée dans `/etc/fstab` pour le montage automatique avec le système de fichiers choisi (si elle n'existe pas déjà)
- Force l'écriture des tampons sur le disque avec `sync`

#### 9. Résumé final

Le script affiche un résumé des opérations effectuées :
```bash
echo "Disque $DISK configuré avec succès:"
echo "- Partition chiffrée avec LUKS"
echo "- Formaté en $FS_TYPE"
echo "- Monté sur $MNT"
echo "- Configuration automatique au démarrage"
```

## Points forts du script

1. **Sécurité renforcée** :
   - Utilisation de LUKS pour le chiffrement
   - Génération de clé aléatoire depuis `/dev/urandom`
   - Permissions restrictives sur les fichiers sensibles
   - Arrêt immédiat en cas d'erreur
   - Option de sauvegarde de la clé de chiffrement

2. **Robustesse** :
   - Gestion des erreurs avec trap
   - Journalisation complète
   - Vérification de l'existence des entrées avant modification des fichiers système
   - Vérification de l'existence du périphérique cible

3. **Flexibilité** :
   - Paramétrage du périphérique cible
   - Choix du système de fichiers
   - Vérification préalable de l'existence de données
   - Taille de clé configurable

4. **Automatisation** :
   - Configuration du montage automatique au démarrage
   - Processus complet de bout en bout
   - Résumé final des opérations effectuées

## Limitations potentielles

1. Pas de support pour les mots de passe (utilise uniquement des fichiers de clé)
2. Pas d'option pour créer plusieurs partitions
3. Pas d'option pour chiffrer un disque déjà partitionné sans le reformater

## Améliorations futures possibles

1. Ajouter une option pour utiliser un mot de passe en plus ou à la place du fichier de clé
2. Permettre la création de plusieurs partitions avec des configurations différentes
3. Ajouter une option pour chiffrer des partitions existantes sans perte de données
4. Implémenter une interface graphique simple pour une utilisation plus conviviale
5. Ajouter des options avancées pour LUKS (algorithme de chiffrement, taille de clé, etc.)