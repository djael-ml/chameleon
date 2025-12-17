#!/bin/bash

# ==============================================================================
#  PROJECT: CHAMELEON 🦎
#  REPOSITORY: https://github.com/djael-ml/chameleon
#  DESCRIPTION: The Ultimate Adaptive Linux Cleaner & Optimizer
#  LICENSE: MIT (Open Source)
#  VERSION: 1.0.0
# ==============================================================================

# --- CONFIGURATION & VARIABLES ---
LOG_FILE="/var/log/chameleon.log"
BACKUP_DIR="/var/backups/chameleon"
MOUNT_POINT="/"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- FONCTIONS UTILITAIRES ---

log() {
    echo -e "${BLUE}[CHAMELEON]${NC} $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[ATTENTION]${NC} $1"
    echo "[WARN] $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERREUR]${NC} $1"
    echo "[ERROR] $1" >> "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

# --- BANNIÈRE ASCII ---
show_banner() {
    clear
    echo -e "${GREEN}"
    echo "   ▄████████    ▄█    █▄       ▄████████   ▄▄▄▄███▄▄▄▄      ▄████████  ▄█          ▄████████  ▄██████▄  ▄█▄        "
    echo "  ███    ███   ███    ███     ███    ███ ▄██▀▀▀███▀▀▀██▄   ███    ███ ███         ███    ███ ███    ███ ███▀       "
    echo "  ███    █▀    ███    ███     ███    ███ ███   ███   ███   ███    █▀  ███         ███    █▀  ███    ███ ███        "
    echo "  ███         ▄███▄▄▄▄███▄▄   ███    ███ ███   ███   ███  ▄███▄▄▄     ███        ▄███▄▄▄     ███    ███ ███        "
    echo "  ███        ▀▀███▀▀▀▀███▀  ▀███████████ ███   ███   ███ ▀▀███▀▀▀     ███       ▀▀███▀▀▀     ███    ███ ███        "
    echo "  ███    █▄    ███    ███     ███    ███ ███   ███   ███   ███    █▄  ███         ███    █▄  ███    ███ ███        "
    echo "  ███    ███   ███    ███     ███    ███ ███   ███   ███   ███    ███ ███▌    ▄   ███    ███ ███    ███ ███▄    ▄  "
    echo "  ████████▀    ███    █▀      ███    █▀   ▀█   ███   █▀    ██████████ █████▄▄██   ██████████  ▀██████▀   ▀██████▀  "
    echo "                                                                      ▀                                            "
    echo -e "${CYAN}             >> ADAPTIVE LINUX CLEANER & OPTIMIZER <<${NC}"
    echo -e "${CYAN}             >> Repo: github.com/djael-ml/chameleon <<${NC}"
    echo ""
}

# --- CHECK ROOT ---
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Ce script doit être lancé en tant que root (sudo).${NC}"
   exit 1
fi

#init log
if [ ! -f "$LOG_FILE" ]; then touch "$LOG_FILE"; fi
chmod 644 "$LOG_FILE"

# --- 1. DÉTECTION CAMÉLÉON (OS & PACKAGES) ---
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID=$ID
        DISTRO_LIKE=$ID_LIKE
    else
        error "Impossible de détecter la distribution Linux."
        exit 1
    fi
    
    log "Système détecté : $PRETTY_NAME ($DISTRO_ID)"

    case "$DISTRO_ID" in
        ubuntu|debian|linuxmint|pop|kali|neon|zorin)
            PM="apt"
            PM_INSTALL="apt install -y"
            PM_REMOVE="apt remove -y"
            PM_PURGE="apt purge -y"
            PM_CLEAN="apt autoremove -y && apt clean"
            PM_UPDATE="apt update"
            ;;
        arch|manjaro|endeavouros|garuda)
            PM="pacman"
            PM_INSTALL="pacman -S --noconfirm --needed"
            PM_REMOVE="pacman -Rns --noconfirm"
            PM_PURGE="pacman -Rns --noconfirm"
            PM_CLEAN="pacman -Sc --noconfirm"
            PM_UPDATE="pacman -Sy"
            ;;
        fedora|rhel|centos|nobara)
            PM="dnf"
            PM_INSTALL="dnf install -y"
            PM_REMOVE="dnf remove -y"
            PM_PURGE="dnf remove -y"
            PM_CLEAN="dnf clean all"
            PM_UPDATE="dnf check-update"
            ;;
        opensuse*|suse)
            PM="zypper"
            PM_INSTALL="zypper install -y"
            PM_REMOVE="zypper remove -y"
            PM_PURGE="zypper remove -u -y"
            PM_CLEAN="zypper clean -a"
            PM_UPDATE="zypper refresh"
            ;;
        *)
            warn "Distribution non officiellement supportée ($DISTRO_ID). Mode compatibilité..."
            PM="unknown"
            ;;
    esac
    log "Wrapper de paquets actif : $PM"
}

install_pkg() {
    if [[ "$PM" == "unknown" ]]; then return; fi
    # Vérifie si déjà installé pour éviter du spam log (rapide)
    if command -v "$1" &> /dev/null; then return; fi
    
    log "Installation de $1..."
    $PM_INSTALL "$1" >> "$LOG_FILE" 2>&1
}

# --- PRÉREQUIS UI ---
check_dependencies() {
    if ! command -v whiptail &> /dev/null; then
        echo "Installation de l'interface graphique (whiptail)..."
        install_pkg "whiptail"
        install_pkg "libnewt-dev"
        # Fallback manual check for pacman if wrapper failed
        if [[ "$PM" == "pacman" ]] && ! command -v whiptail &> /dev/null; then
             pacman -S --noconfirm libnewt >> "$LOG_FILE" 2>&1
        fi
    fi
}

# --- SNAPSHOT SÉCURITÉ ---
create_snapshot() {
    log "Tentative de création d'un point de restauration..."
    if command -v timeshift &> /dev/null; then
        timeshift --create --comments "Auto-Backup Chameleon" --tags D
        success "Snapshot Timeshift créé."
    elif command -v snapper &> /dev/null; then
        snapper create -d "Auto-Backup Chameleon"
        success "Snapshot Snapper créé."
    else
        warn "Aucun outil de snapshot (Timeshift/Snapper) détecté. Ignoré."
    fi
}

# --- MODULES ---

module_cleaner() {
    log "=== MODULE CLEANER ==="
    
    # Cache
    log "Nettoyage Cache & Orphelins..."
    eval "$PM_CLEAN" >> "$LOG_FILE" 2>&1

    if [[ "$PM" == "apt" ]]; then
        dpkg -l | grep "^rc" | awk '{print $2}' | xargs -r dpkg -P >> "$LOG_FILE" 2>&1
    elif [[ "$PM" == "pacman" ]]; then
        ORPHANS=$(pacman -Qdtq)
        if [[ -n "$ORPHANS" ]]; then pacman -Rns --noconfirm $ORPHANS >> "$LOG_FILE" 2>&1; fi
    fi

    # Logs
    log "Nettoyage Journal Systemd (Max 50Mo)..."
    journalctl --vacuum-size=50M >> "$LOG_FILE" 2>&1

    # Caches Users
    log "Nettoyage Caches Utilisateurs (~/.cache/thumbnails)..."
    rm -rf /home/*/.cache/thumbnails/*
    rm -rf /root/.cache/thumbnails/*

    success "Système nettoyé."
}

module_debloater() {
    log "=== MODULE DEBLOATER ==="
    
    # Liste de base
    BLOAT_LIST=("gnome-games" "aisleriot" "gnome-mahjongg" "gnome-mines" "gnome-sudoku" "libreoffice-math" "libreoffice-draw" "thunderbird" "hexchat" "hypnotix")

    # Ubuntu Specific
    if [[ "$DISTRO_ID" == "ubuntu" ]]; then
        BLOAT_LIST+=("whoopsie" "apport" "ubuntu-report")
    fi

    for app in "${BLOAT_LIST[@]}"; do
        $PM_REMOVE "$app" >> "$LOG_FILE" 2>&1
    done

    # Flatpak Cleaner
    if command -v flatpak &> /dev/null; then
        log "Nettoyage runtimes Flatpak inutilisés..."
        flatpak uninstall --unused -y >> "$LOG_FILE" 2>&1
    fi

    success "Bloatwares traités."
}

module_optimizer() {
    log "=== MODULE OPTIMIZER ==="

    SYSCTL_CONF="/etc/sysctl.d/99-chameleon.conf"
    echo "# Chameleon Tuning" > "$SYSCTL_CONF"
    
    # Gestion mémoire
    echo "vm.swappiness=10" >> "$SYSCTL_CONF"
    echo "vm.vfs_cache_pressure=50" >> "$SYSCTL_CONF"
    echo "vm.dirty_ratio=10" >> "$SYSCTL_CONF"
    echo "vm.dirty_background_ratio=5" >> "$SYSCTL_CONF"
    
    # Réseau
    echo "net.core.default_qdisc=fq" >> "$SYSCTL_CONF"
    echo "net.ipv4.tcp_congestion_control=bbr" >> "$SYSCTL_CONF"
    
    sysctl -p "$SYSCTL_CONF" >> "$LOG_FILE" 2>&1
    log "Paramètres noyau appliqués (Swappiness, BBR)."

    # ZRAM
    if ! command -v zramctl &> /dev/null; then
        log "Installation ZRAM..."
        [[ "$PM" == "apt" ]] && install_pkg "zram-tools"
        [[ "$PM" == "pacman" ]] && install_pkg "zram-generator"
    fi

    # SSD TRIM
    systemctl enable --now fstrim.timer >> "$LOG_FILE" 2>&1
    
    # CPU Governor Performance (si possible)
    if command -v cpupower &> /dev/null; then
        cpupower frequency-set -g performance >> "$LOG_FILE" 2>&1
    fi

    success "Optimisations terminées."
}

module_gaming() {
    log "=== MODULE GAMING ==="
    install_pkg "gamemode"
    
    GPU=$(lspci | grep -i vga)
    if [[ "$GPU" == *"NVIDIA"* ]]; then
        log "Configuration NVIDIA..."
        if [[ "$PM" == "apt" ]]; then
            install_pkg "ubuntu-drivers-common"
            ubuntu-drivers autoinstall >> "$LOG_FILE" 2>&1
        elif [[ "$PM" == "pacman" ]]; then
            install_pkg "nvidia-dkms" "nvidia-utils"
        fi
    else
        log "Configuration AMD/Intel (Mesa)..."
        if [[ "$PM" == "apt" ]]; then install_pkg "mesa-vulkan-drivers"; fi
        if [[ "$PM" == "pacman" ]]; then install_pkg "mesa" "vulkan-radeon"; fi
    fi
    
    install_pkg "wine" "lutris" "steam"
    success "Environnement Gaming prêt."
}

module_security() {
    log "=== MODULE SECURITY ==="

    # Firewall
    if [[ "$PM" == "apt" ]]; then
        install_pkg "ufw"
        ufw default deny incoming
        ufw default allow outgoing
        # On ne force pas le enable pour ne pas couper SSH, l'user le fera
        log "UFW installé. Lancez 'ufw enable' manuellement pour activer."
    elif [[ "$PM" == "pacman" ]] || [[ "$PM" == "dnf" ]]; then
        install_pkg "firewalld"
        systemctl enable --now firewalld >> "$LOG_FILE" 2>&1
    fi

    # DNS Cloudflare
    if systemctl is-active --quiet systemd-resolved; then
        mkdir -p /etc/systemd/resolved.conf.d
        echo -e "[Resolve]\nDNS=1.1.1.1 9.9.9.9\nDNSOverTLS=yes" > /etc/systemd/resolved.conf.d/chameleon_dns.conf
        systemctl restart systemd-resolved
        log "DNS sécurisés activés."
    fi

    success "Sécurité renforcée."
}

module_postinstall() {
    log "=== MODULE POST-INSTALL ==="
    APPS=("vlc" "git" "curl" "wget" "htop" "neofetch" "btop" "p7zip-full" "unrar" "zsh")
    
    for app in "${APPS[@]}"; do
        install_pkg "$app"
    done
    success "Logiciels essentiels installés."
}

# --- MENU INTERACTIF ---

main_menu() {
    check_dependencies
    
    CHOICES=$(whiptail --title "Chameleon Control Center" --checklist \
    "Bienvenue. Cochez les modules à exécuter :" 20 78 10 \
    "CLEAN" "Nettoyage (Cache, Logs, Orphelins)" ON \
    "BLOAT" "Retirer les Bloatwares & Télémétrie" OFF \
    "OPTIM" "Boost Performance (RAM, SSD, CPU)" ON \
    "GAME"  "Pack Gaming (Drivers, GameMode)" OFF \
    "SECURE" "Sécurité (Firewall, DNS Privé)" OFF \
    "APPS"  "Install Apps Essentielles" OFF \
    3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        echo "Annulation."
        exit 0
    fi

    create_snapshot

    if [[ $CHOICES == *"CLEAN"* ]]; then module_cleaner; fi
    if [[ $CHOICES == *"BLOAT"* ]]; then module_debloater; fi
    if [[ $CHOICES == *"OPTIM"* ]]; then module_optimizer; fi
    if [[ $CHOICES == *"GAME"* ]]; then module_gaming; fi
    if [[ $CHOICES == *"SECURE"* ]]; then module_security; fi
    if [[ $CHOICES == *"APPS"* ]]; then module_postinstall; fi

    show_banner
    echo -e "${GREEN}Terminé ! Un redémarrage est recommandé.${NC}"
    echo "Log: $LOG_FILE"
}

# --- MAIN ---
show_banner
detect_distro

if [[ "$1" == "--auto" ]]; then
    create_snapshot
    module_cleaner
    module_optimizer
    success "Mode auto terminé."
else
    main_menu
fi
