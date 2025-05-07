# 🔐 Script de Sécurisation de Disque (Interne ou Externe)

## Développé par [Sébastien VIDOTTO](https://heteractis.fr)
**Architecte numérique & Stratège digital** – Fondateur de l'agence [Heteractis](https://heteractis.fr)

## 📋 Versionnage

| Version | Date | Description |
|---------|------|-------------|
| 1.0.0 | 25/05/2023 | Version initiale du script |

## 📋 Présentation

Ce script `crypt_sdb.sh` est un utilitaire avancé de sécurisation de disque sous Linux. Il permet de transformer n'importe quel disque (interne ou externe) en un support de stockage hautement sécurisé grâce au chiffrement LUKS, tout en automatisant l'ensemble du processus de configuration.

## 🚀 Fonctionnalités principales

1. **Paramétrage flexible du périphérique cible**
   - Spécification en argument ou sélection interactive
   - Affichage des disques disponibles pour faciliter le choix
   - Vérification de l'existence du périphérique avant manipulation

2. **Sécurité renforcée**
   - Vérification préalable de l'existence de données sur le disque
   - Demande de confirmation explicite avant toute opération destructive
   - Test d'intégrité physique du disque (optionnel via badblocks)
   - Chiffrement LUKS avec génération de clé aléatoire sécurisée
   - Permissions restrictives sur les fichiers sensibles

3. **Flexibilité de configuration**
   - Choix entre différents systèmes de fichiers (ext4, xfs, btrfs)
   - Option de sauvegarde de la clé de chiffrement
   - Taille de clé configurable

4. **Automatisation complète**
   - Configuration du montage automatique au démarrage via crypttab et fstab
   - Journalisation détaillée de toutes les opérations
   - Gestion robuste des erreurs avec arrêt immédiat en cas de problème

## 💼 Avantages et bénéfices

### Pour les entreprises et professionnels

- **Protection des données sensibles** : Empêche tout accès non autorisé aux informations confidentielles en cas de perte, de vol du disque ou d'accès non autorisé au système
- **Conformité RGPD** : Contribue au respect des obligations légales concernant la protection des données personnelles
- **Simplicité d'utilisation** : Automatisation complète du processus, ne nécessitant pas d'expertise technique approfondie
- **Fiabilité** : Vérifications multiples et gestion des erreurs pour éviter toute perte de données

### Pour les utilisateurs individuels

- **Sécurité de vos données personnelles** : Photos, documents administratifs, sauvegardes protégées contre les accès non autorisés
- **Tranquillité d'esprit** : En cas de perte, de vol ou d'accès non autorisé, vos données restent inaccessibles sans la clé de déchiffrement
- **Solution professionnelle** : Bénéficiez d'une solution de sécurité de niveau entreprise pour vos besoins personnels

## 🔧 Prérequis techniques

- Système Linux (testé sur Debian/Ubuntu)
- Droits administrateur (root)
- Packages requis : cryptsetup, parted, util-linux

## 📚 Utilisation

```bash
# Utilisation avec périphérique par défaut (/dev/sdb)
sudo ./crypt_sdb.sh

# Utilisation avec périphérique spécifique
sudo ./crypt_sdb.sh /dev/sdX
```

## ⚠️ Avertissement

Ce script effectue des opérations destructives sur le périphérique cible (qu'il s'agisse d'un disque interne ou externe). Toutes les données existantes seront effacées. Assurez-vous de sauvegarder vos données importantes avant utilisation.

## 🔄 Améliorations futures envisagées

- Support pour les mots de passe en plus des fichiers de clé
- Option pour créer plusieurs partitions avec des configurations différentes
- Chiffrement de partitions existantes sans perte de données
- Interface graphique pour une utilisation plus conviviale
- 
## ⚖️ Clause de responsabilité

Ce script est fourni "tel quel", à des fins pédagogiques et professionnelles.

Il utilise exclusivement des outils open source standards (cryptsetup, parted) disponibles sous Linux.  
L’auteur ne pourra être tenu responsable de toute perte de données, mauvaise utilisation ou dommage consécutif à l’exécution de ce script.

L’utilisateur est seul responsable :
- de la sauvegarde préalable de ses données,
- de la sélection du disque cible,
- de la gestion et de la conservation des clés de chiffrement générées.

Ce script n’implémente aucun mécanisme de récupération.  
Toute perte de la clé entraîne la perte définitive des données.

Ce projet respecte la législation française relative à l’utilisation de la cryptologie (LCEN – art. L.871-7 et R.871-12).  
Aucun service de chiffrement à des tiers n’est fourni.

Utilisation à vos risques et périls.

## 📞 Contact

Pour toute question ou suggestion d'amélioration, n'hésitez pas à me contacter :

- 📧 Email : leseeb22@gmail.com
- 🌐 Site web : [heteractis.fr](https://heteractis.fr)

---

*Développé avec ❤️ par Sébastien VIDOTTO, expert en solutions numériques sécurisées et stratégie digitale depuis plus de 18 ans.*
