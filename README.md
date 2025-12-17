# Chameleon 🦎 (Ultimate Edition)

> **The Most Comprehensive Adaptive Linux Cleaner & Optimizer**

Chameleon est un outil puissant, "tout-en-un", conçu pour nettoyer, optimiser, sécuriser et configurer n'importe quelle distribution Linux.
Contrairement aux scripts basiques, Chameleon **s'adapte** à votre environnement (Ubuntu, Arch, Fedora, GNOME, KDE...) et vous offre un **contrôle total** via une interface graphique terminal.

![Bash](https://img.shields.io/badge/Language-Bash-4EAA25?style=flat-square)
![Linux](https://img.shields.io/badge/OS-Linux-FCC624?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)

## 🔥 Pourquoi utiliser Chameleon ?

* **🦎 Adaptatif :** Détecte votre OS (`apt`, `pacman`, `dnf`, `zypper`) ET votre bureau (GNOME, KDE, XFCE) pour ne pas supprimer les mauvais fichiers.
* **🛡️ Sécurité Paranoïaque :** Crée automatiquement un **Snapshot système** (Timeshift/Snapper) et sauvegarde vos fichiers de config (`.bak`) avant toute modification.
* **🎛️ Contrôle Granulaire :** Pas de bouton magique obscur. Vous choisissez via des menus à cocher exactement ce que vous voulez (Vider le cache ? Oui. Supprimer Firefox ? Non.).
* **🚀 Performance Extrême :** Algorithmes TCP BBR, ZRAM, Swappiness, I/O schedulers, CPU Governor...
* **🎮 Gaming Ready :** Installe tout le nécessaire pour jouer (Drivers Nvidia/AMD, GameMode, Steam, Lutris, Wine).

## 🛠️ Fonctionnalités Détaillées

### 1. 🧹 Deep Clean (Nettoyage)
* Cache des paquets (`apt clean`, `pacman -Sc`...)
* Dépendances orphelines
* Logs système (Journalctl vacuum)
* Caches utilisateurs (Thumbnails, Browser)
* Corbeilles root & utilisateurs

### 2. ⚡ Optimization (Boost)
* **RAM :** Gestion intelligente du Swap (zram + swappiness 10).
* **Réseau :** Activation de TCP BBR et optimisation de la file d'attente.
* **Disque :** Activation du TRIM SSD et options de montage.
* **CPU :** Force le mode "Performance" et désactive les throttles inutiles.

### 3. 🗑️ Debloater (Nettoyage Apps)
* Détection des environnements (ne supprime pas les apps KDE si vous êtes sous GNOME).
* Suppression de la télémétrie (Ubuntu report, whoopsie).
* Nettoyage des Runtimes Flatpak et Snaps obsolètes.
* Suppression des suites bureautiques ou jeux préinstallés inutiles.

### 4. 🔒 Sécurité
* Configuration automatique du Firewall (UFW / Firewalld).
* Mise en place de DNS privés chiffrés (Cloudflare / Quad9).
* Désactivation IPv6 (optionnel).
* Scan Rootkit.

## 🚀 Installation

Une seule ligne de commande suffit. Le script vérifie ses propres dépendances.

```bash
# Télécharger et lancer
wget [https://raw.githubusercontent.com/djael-ml/chameleon/main/chameleon.sh](https://raw.githubusercontent.com/djael-ml/chameleon/main/chameleon.sh)
chmod +x chameleon.sh
sudo ./chameleon.sh
