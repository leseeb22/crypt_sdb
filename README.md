# crypt_sdb

Script Bash de préparation d'un disque chiffré sous Linux avec **LUKS**.

> **Attention : ce script peut effacer intégralement le disque sélectionné.** Vérifiez toujours le périphérique cible et disposez d'une sauvegarde avant exécution.

## Ce que fait le script

- sélection et contrôle du périphérique cible ;
- détection des partitions existantes et confirmation avant destruction ;
- test optionnel du disque ;
- création d'une partition GPT ;
- chiffrement LUKS avec fichier de clé ;
- choix du système de fichiers : ext4, XFS ou Btrfs ;
- montage et configuration de `crypttab` / `fstab` ;
- journalisation des opérations.

## Prérequis

Linux, droits root et les outils standards utilisés par le script, notamment :

```bash
cryptsetup parted util-linux
```

## Utilisation

```bash
sudo ./crypt_sdb.sh
```

ou avec un périphérique explicite :

```bash
sudo ./crypt_sdb.sh /dev/sdX
```

## Sécurité

Le script génère et manipule une clé de chiffrement. La perte de cette clé peut rendre les données irrécupérables. Stockez toute sauvegarde de clé hors du disque chiffré et protégez-la avec des permissions adaptées.

Avant usage en production, relisez le script et adaptez les chemins, politiques de sauvegarde et options LUKS à votre contexte.

## Documentation

- [Analyse technique](docs/analysis.md)
- [À propos de l'auteur](docs/author.md)

## Version

Version documentée : **1.0.0**.

## Auteur

Sébastien Vidotto — Heteractis.

## Licence

Voir [LICENCE](LICENCE).
