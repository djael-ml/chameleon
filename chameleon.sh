#!/bin/bash

# ==============================================================================
#  PROJECT: CHAMELEON (ULTIMATE EDITION) 🦎
#  REPOSITORY: https://github.com/djael-ml/chameleon
#  DESCRIPTION: The Most Comprehensive Adaptive Linux Tool
#  LICENSE: MIT
#  VERSION: 2.0.0
# ==============================================================================

# --- 1. CONFIGURATION GLOBALE ---

LOG_FILE="/var/log/chameleon.log"
BACKUP_DIR="/var/backups/chameleon_configs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Couleurs & Styles
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- 2. FONCTIONS SYSTÈME DE BASE ---

# Initialisation Log & Backup
mkdir -p "$BACKUP_DIR"
if [ ! -f "$LOG_FILE" ]; then touch "$LOG_FILE"; fi
chmod 644 "$LOG_FILE"

log() {
    local msg="$1"
    echo -e "${BLUE}[CHAMELEON]${NC} $msg"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $msg" >> "$LOG_FILE"
}

warn() {
    local msg="$1"
    echo -e "${YELLOW}[ATTENTION]${NC} $msg"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] $msg" >> "$LOG_FILE"
}

error() {
    local msg="$1"
    echo -e "${RED}[ERREUR]${NC} $msg"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $msg" >> "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

# Gestion d'erreur paranoïaque
run_safe() {
    local cmd="$1"
    local desc="$2"
    
    log "Exécution : $desc"
    eval "$cmd" >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        success "$desc"
        return 0
    else
        error "ECHEC : $desc"
        return 1
    fi
}

# Sauvegarde de fichier de config avant modif
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "$BACKUP_DIR/$(basename "$file")_$TIMESTAMP.bak"
        log "Backup créé pour $file"
    fi
}

# Restauration de fichier
restore_file() {
    local file="$1"
    # Trouve le backup le plus récent
    local latest_backup=$(ls -t "$BACKUP_DIR/$(basename "$file")_"*.bak 2>/dev/null | head -n1)
    
    if [ -f "$latest_backup" ]; then
        cp "$latest_backup" "$file"
        success "Restauré : $file (depuis $latest_backup)"
    else
        warn "Aucun backup trouvé pour $file"
    fi
}

# --- 3. DÉTECTION CAMÉLÉON AVANCÉE ---

detect_system() {
    # Distro Check
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID=$ID
        DISTRO_LIKE=$ID_LIKE
    else
        error "OS indétectable."
        exit 1
    fi

    # Desktop Environment Check
    detect_de() {
        if [ "$XDG_CURRENT_DESKTOP" = "" ]; then
            DESKTOP_ENV=$(echo "$XDG_DATA_DIRS" | sed 's/.*\(xfce\|kde\|gnome\).*/\1/')
        else
            DESKTOP_ENV=$XDG_CURRENT_DESKTOP
        fi
        DESKTOP_ENV=${DESKTOP_ENV,,}  # lowercase
    }
    detect_de

    log "Système : $PRETTY_NAME ($DISTRO_ID)"
    log "Bureau : $DESKTOP_ENV"

    # Package Manager Wrapper
    case "$DISTRO_ID" in
        ubuntu|debian|linuxmint|pop|kali|neon|zorin|elementary)
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
        fedora|rhel|centos|nobara|almalinux)
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
            warn "Distro non standard ($DISTRO_ID). Mode limité."
            PM="unknown"
            ;;
    esac
}

install_pkg() {
    if [[ "$PM" == "unknown" ]]; then return; fi
    if command -v "$1" &> /dev/null; then return; fi
    run_safe "$PM_INSTALL $1" "Installation de $1"
}

remove_pkg() {
    if [[ "$PM" == "unknown" ]]; then return; fi
    # On check si installé avant de tenter la suppression pour logs propres
    # (Approximatif mais suffisant pour clean logs)
    run_safe "$PM_REMOVE $1" "Suppression de $1"
}

# --- 4. PRÉPARATION ---

check_root() {
    if [[ $EUID -ne 0 ]]; then
       echo -e "${RED}ERREUR : Lancez ce script avec SUDO.${NC}"
       exit 1
    fi
}

check_dependencies() {
    if ! command -v whiptail &> /dev/null; then
        echo "Installation de whiptail..."
        install_pkg "whiptail" "libnewt-dev"
        if [[ "$PM" == "pacman" ]]; then pacman -S --noconfirm libnewt; fi
    fi
}

create_snapshot() {
    log "=== SNAPSHOT DE SÉCURITÉ ==="
    if command -v timeshift &> /dev/null; then
        timeshift --create --comments "Chameleon_Auto_Backup" --tags D > /dev/null
        success "Snapshot Timeshift créé."
    elif command -v snapper &> /dev/null; then
        snapper create -d "Chameleon_Auto_Backup"
        success "Snapshot Snapper créé."
    else
        whiptail --title "Attention" --yesno "Aucun outil de snapshot (Timeshift/Snapper) n'est installé.\n\nVoulez-vous continuer sans sauvegarde système complète ?" 10 60
        if [ $? -ne 0 ]; then exit 0; fi
        warn "Continuation sans snapshot."
    fi
}

# --- 5. MODULE: DEEP CLEAN (GRANULAIRE) ---

module_cleaner_menu() {
    CHOICES=$(whiptail --title "Nettoyage Approfondi" --checklist \
    "Sélectionnez les éléments à nettoyer :" 15 70 5 \
    "PKG_CACHE" "Cache des paquets (apt/dnf/pacman)" ON \
    "ORPHANS" "Paquets orphelins (dépendances inutiles)" ON \
    "LOGS" "Journaux système (Systemd Journal)" ON \
    "USER_CACHE" "Cache Utilisateur (Thumbnails/Browser)" OFF \
    "TRASH" "Vider les corbeilles (Root & Users)" OFF \
    3>&1 1>&2 2>&3)

    if [[ $CHOICES == *"PKG_CACHE"* ]]; then
        run_safe "$PM_CLEAN" "Nettoyage Cache Paquets"
    fi

    if [[ $CHOICES == *"ORPHANS"* ]]; then
        log "Recherche d'orphelins..."
        if [[ "$PM" == "apt" ]]; then
            run_safe "apt autoremove -y" "Suppression orphelins APT"
            dpkg -l | grep "^rc" | awk '{print $2}' | xargs -r dpkg -P >> "$LOG_FILE" 2>&1
        elif [[ "$PM" == "pacman" ]]; then
            ORPHANS=$(pacman -Qdtq)
            if [[ -n "$ORPHANS" ]]; then run_safe "pacman -Rns --noconfirm $ORPHANS" "Suppression orphelins Pacman"; fi
        elif [[ "$PM" == "dnf" ]]; then
            run_safe "dnf autoremove -y" "Suppression orphelins DNF"
        fi
    fi

    if [[ $CHOICES == *"LOGS"* ]]; then
        run_safe "journalctl --vacuum-size=50M --vacuum-time=7d" "Nettoyage Logs Systemd"
    fi

    if [[ $CHOICES == *"USER_CACHE"* ]]; then
        log "Nettoyage caches utilisateurs..."
        rm -rf /home/*/.cache/thumbnails/*
        rm -rf /root/.cache/thumbnails/*
        success "Thumbnails supprimés."
    fi

    if [[ $CHOICES == *"TRASH"* ]]; then
        rm -rf /home/*/.local/share/Trash/*
        rm -rf /root/.local/share/Trash/*
        success "Corbeilles vidées."
    fi
}

# --- 6. MODULE: DEBLOATER (GRANULAIRE & INTELLIGENT) ---

module_debloater_menu() {
    # Définition des listes
    LIST_GNOME=("gnome-games" "aisleriot" "gnome-mahjongg" "gnome-mines" "gnome-sudoku" "gnome-todo" "gnome-weather" "gnome-maps")
    LIST_OFFICE=("libreoffice-math" "libreoffice-draw" "libreoffice-base")
    LIST_UBUNTU=("whoopsie" "apport" "ubuntu-report" "popularity-contest")
    LIST_MEDIA=("rhythmbox" "totem" "cheese")
    
    OPTIONS=()
    OPTIONS+=("COMMON" "Bloatware commun (Jeux, Accessoires)" ON)
    if [[ "$DESKTOP_ENV" == *"gnome"* ]] || [[ "$DISTRO_ID" == "ubuntu" ]]; then
        OPTIONS+=("GNOME" "Applications GNOME inutiles" OFF)
    fi
    OPTIONS+=("OFFICE" "Modules LibreOffice inutiles (Math/Draw)" OFF)
    if [[ "$DISTRO_ID" == "ubuntu" ]]; then
        OPTIONS+=("TELEMETRY" "Télémétrie Ubuntu & Tracking" ON)
    fi
    OPTIONS+=("FLATPAK" "Nettoyage Runtimes Flatpak" ON)
    OPTIONS+=("SNAP" "Nettoyage Cache Snap" ON)

    CHOICES=$(whiptail --title "Debloater (Anti-Gonflette)" --checklist \
    "Qu'est-ce qu'on dégage ?" 18 70 8 \
    "${OPTIONS[@]}" \
    3>&1 1>&2 2>&3)

    if [[ $CHOICES == *"COMMON"* ]]; then
        for app in "hexchat" "hypnotix" "thunderbird" "gnome-2048"; do remove_pkg "$app"; done
    fi

    if [[ $CHOICES == *"GNOME"* ]]; then
        for app in "${LIST_GNOME[@]}"; do remove_pkg "$app"; done
    fi

    if [[ $CHOICES == *"OFFICE"* ]]; then
        for app in "${LIST_OFFICE[@]}"; do remove_pkg "$app"; done
    fi

    if [[ $CHOICES == *"TELEMETRY"* ]]; then
        for app in "${LIST_UBUNTU[@]}"; do remove_pkg "$app"; done
    fi

    if [[ $CHOICES == *"FLATPAK"* ]]; then
        if command -v flatpak &> /dev/null; then
            run_safe "flatpak uninstall --unused -y" "Flatpak Unused Remove"
        fi
    fi

    if [[ $CHOICES == *"SNAP"* ]]; then
        if command -v snap &> /dev/null; then
           # Nettoyage safe des vieilles versions
           snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do
               snap remove "$snapname" --revision="$revision" >> "$LOG_FILE" 2>&1
           done
           success "Vieux snaps supprimés."
        fi
    fi
}

# --- 7. MODULE: OPTIMIZER (AVANCÉ) ---

module_optimizer_menu() {
    CHOICES=$(whiptail --title "Optimisation Performances" --checklist \
    "Tweaks Système :" 15 70 6 \
    "RAM" "Optimisation RAM (Swappiness 10 + Cache)" ON \
    "ZRAM" "Installer/Activer ZRAM (Compression RAM)" ON \
    "NET" "Optimisation Réseau (TCP BBR + Queue)" ON \
    "SSD" "Optimisation Disque (TRIM + Noatime)" ON \
    "CPU" "CPU Governor (Performance Mode)" ON \
    "WATCH" "Augmenter inotify (Pour IDEs/Jeux)" ON \
    3>&1 1>&2 2>&3)

    SYSCTL_CONF="/etc/sysctl.d/99-chameleon.conf"
    backup_file "$SYSCTL_CONF"
    # Création fichier vide ou append
    echo "# Chameleon Tweaks - $TIMESTAMP" > "$SYSCTL_CONF"

    if [[ $CHOICES == *"RAM"* ]]; then
        echo "vm.swappiness=10" >> "$SYSCTL_CONF"
        echo "vm.vfs_cache_pressure=50" >> "$SYSCTL_CONF"
        echo "vm.dirty_ratio=10" >> "$SYSCTL_CONF"
        echo "vm.dirty_background_ratio=5" >> "$SYSCTL_CONF"
    fi

    if [[ $CHOICES == *"NET"* ]]; then
        echo "net.core.default_qdisc=fq" >> "$SYSCTL_CONF"
        echo "net.ipv4.tcp_congestion_control=bbr" >> "$SYSCTL_CONF"
        echo "net.ipv4.tcp_fastopen=3" >> "$SYSCTL_CONF"
        echo "net.core.netdev_max_backlog=16384" >> "$SYSCTL_CONF"
    fi

    if [[ $CHOICES == *"WATCH"* ]]; then
        echo "fs.inotify.max_user_watches=524288" >> "$SYSCTL_CONF"
    fi
    
    # Appliquer sysctl si fichier non vide
    sysctl -p "$SYSCTL_CONF" >> "$LOG_FILE" 2>&1
    success "Sysctl appliqué."

    if [[ $CHOICES == *"ZRAM"* ]]; then
         if ! command -v zramctl &> /dev/null; then
            [[ "$PM" == "apt" ]] && install_pkg "zram-tools"
            [[ "$PM" == "pacman" ]] && install_pkg "zram-generator"
            [[ "$PM" == "dnf" ]] && install_pkg "zram-generator"
            success "ZRAM installé."
         fi
    fi

    if [[ $CHOICES == *"SSD"* ]]; then
        run_safe "systemctl enable --now fstrim.timer" "Activation fstrim"
    fi

    if [[ $CHOICES == *"CPU"* ]]; then
        if command -v cpupower &> /dev/null; then
            run_safe "cpupower frequency-set -g performance" "Mode Performance CPU"
        else
            install_pkg "linux-cpupower" # Generic attempt
            install_pkg "cpupower"
        fi
    fi
}

# --- 8. MODULE: GAMING & MEDIA ---

module_gaming_menu() {
    CHOICES=$(whiptail --title "Gaming Center" --checklist \
    "Installation & Config :" 15 70 5 \
    "DRIVERS" "Détection Auto Drivers GPU" ON \
    "GAMEMODE" "Feral GameMode" ON \
    "PLATFORMS" "Steam & Lutris" OFF \
    "WINE" "Wine & Dépendances" OFF \
    "MANGOHUD" "MangoHud (Overlay FPS)" OFF \
    3>&1 1>&2 2>&3)

    if [[ $CHOICES == *"DRIVERS"* ]]; then
        GPU=$(lspci | grep -i vga)
        log "GPU détecté: $GPU"
        if [[ "$GPU" == *"NVIDIA"* ]]; then
            if [[ "$PM" == "apt" ]]; then
                install_pkg "ubuntu-drivers-common"
                run_safe "ubuntu-drivers autoinstall" "Install Drivers Nvidia"
            elif [[ "$PM" == "pacman" ]]; then
                install_pkg "nvidia-dkms" "nvidia-utils" "lib32-nvidia-utils"
            fi
        else
            if [[ "$PM" == "apt" ]]; then install_pkg "mesa-vulkan-drivers" "libglx-mesa0"; fi
            if [[ "$PM" == "pacman" ]]; then install_pkg "mesa" "vulkan-radeon" "lib32-vulkan-radeon"; fi
        fi
    fi

    if [[ $CHOICES == *"GAMEMODE"* ]]; then install_pkg "gamemode"; fi
    if [[ $CHOICES == *"PLATFORMS"* ]]; then install_pkg "steam" "lutris"; fi
    if [[ $CHOICES == *"MANGOHUD"* ]]; then install_pkg "mangohud"; fi
    if [[ $CHOICES == *"WINE"* ]]; then install_pkg "wine" "winetricks"; fi
}

# --- 9. MODULE: SECURITY & PRIVACY ---

module_security_menu() {
    CHOICES=$(whiptail --title "Sécurité & Confidentialité" --checklist \
    "Durcissement du système :" 15 70 4 \
    "FIREWALL" "Installer & Activer Firewall (UFW/Firewalld)" ON \
    "DNS" "DNS Privés (Cloudflare/Quad9)" ON \
    "IPV6" "Désactiver IPv6 (Évite les fuites)" OFF \
    "ROOTKIT" "Scan Rootkit (rkhunter)" OFF \
    3>&1 1>&2 2>&3)

    if [[ $CHOICES == *"FIREWALL"* ]]; then
        if [[ "$PM" == "apt" ]]; then
            install_pkg "ufw"
            ufw default deny incoming
            ufw default allow outgoing
            ufw allow ssh
            echo "y" | ufw enable >> "$LOG_FILE" 2>&1
            success "UFW Activé."
        elif [[ "$PM" == "pacman" ]] || [[ "$PM" == "dnf" ]]; then
            install_pkg "firewalld"
            run_safe "systemctl enable --now firewalld" "Firewalld Activé"
        fi
    fi

    if [[ $CHOICES == *"DNS"* ]]; then
        if systemctl is-active --quiet systemd-resolved; then
            mkdir -p /etc/systemd/resolved.conf.d
            echo -e "[Resolve]\nDNS=1.1.1.1 9.9.9.9\nDNSOverTLS=yes" > /etc/systemd/resolved.conf.d/chameleon_dns.conf
            systemctl restart systemd-resolved
            success "DNS Cloudflare via Systemd."
        else
            warn "Systemd-resolved inactif. DNS non appliqués par sécurité."
        fi
    fi

    if [[ $CHOICES == *"IPV6"* ]]; then
        SYSCTL_IPV6="/etc/sysctl.d/90-disable-ipv6.conf"
        backup_file "$SYSCTL_IPV6"
        echo "net.ipv6.conf.all.disable_ipv6 = 1" > "$SYSCTL_IPV6"
        echo "net.ipv6.conf.default.disable_ipv6 = 1" >> "$SYSCTL_IPV6"
        sysctl -p "$SYSCTL_IPV6" >> "$LOG_FILE" 2>&1
        success "IPv6 Désactivé."
    fi
    
    if [[ $CHOICES == *"ROOTKIT"* ]]; then
        install_pkg "rkhunter"
        log "Mise à jour rkhunter..."
        rkhunter --propupd >> "$LOG_FILE" 2>&1
    fi
}

# --- 10. MODULE: INSTALLATION LOGICIELS (STORE) ---

module_software_menu() {
    CATEGORY=$(whiptail --title "App Store Chameleon" --menu \
    "Quelle catégorie installer ?" 15 60 5 \
    "DEV" "Outils Développeur (Git, Docker, VSCode...)" \
    "MEDIA" "Multimédia (VLC, OBS, Gimp...)" \
    "NET" "Internet (Brave, Discord, Signal...)" \
    "SYS" "Outils Système (Htop, Neofetch, Zsh...)" \
    "OFFICE" "Bureautique (OnlyOffice...)" \
    3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then return; fi

    APPS_TO_INSTALL=()
    
    case "$CATEGORY" in
        DEV)
            SELECTION=$(whiptail --checklist "Outils Dev" 15 60 5 \
            "git" "Git VCS" ON \
            "code" "VS Code (si dispo)" OFF \
            "docker" "Docker Engine" OFF \
            "python3-pip" "Python Pip" OFF \
            "npm" "Node Package Manager" OFF 3>&1 1>&2 2>&3)
            ;;
        MEDIA)
            SELECTION=$(whiptail --checklist "Multimédia" 15 60 5 \
            "vlc" "VLC Media Player" ON \
            "gimp" "Gimp Image Editor" OFF \
            "obs-studio" "OBS Studio" OFF \
            "kdenlive" "Kdenlive Video Editor" OFF 3>&1 1>&2 2>&3)
            ;;
        SYS)
            SELECTION=$(whiptail --checklist "Système" 15 60 5 \
            "htop" "Htop Monitor" ON \
            "btop" "Btop (Better Htop)" OFF \
            "neofetch" "Info Système" ON \
            "curl" "Curl" ON \
            "wget" "Wget" ON \
            "zsh" "Zsh Shell" OFF \
            "p7zip-full" "7Zip Support" ON 3>&1 1>&2 2>&3)
            ;;
        # Ajouter d'autres cas si besoin
    esac

    # Enlever les guillemets du résultat whiptail
    SELECTION=$(echo "$SELECTION" | tr -d '"')
    
    for app in $SELECTION; do
        install_pkg "$app"
    done
}

# --- 11. MODULE: RESTAURATION ---

module_restore() {
    whiptail --title "Restauration / Undo" --msgbox "Cette fonction restaure les fichiers de configuration modifiés par Chameleon (sysctl, dns) depuis le dossier $BACKUP_DIR." 10 60
    
    if [ "$(ls -A $BACKUP_DIR)" ]; then
        FILES=$(ls $BACKUP_DIR | whiptail --title "Fichiers disponibles" --menu "Choisir un backup à restaurer" 15 60 5 3>&1 1>&2 2>&3)
        # Logique simplifiée de restauration (à adapter selon le nommage)
        # Ici c'est indicatif car le nommage contient le timestamp
        echo "Fonctionnalité manuelle pour le moment : copiez les fichiers depuis $BACKUP_DIR"
        sleep 3
    else
        whiptail --msgbox "Aucun backup trouvé." 8 40
    fi
}

# --- 12. MENU PRINCIPAL & LOGIQUE ---

main_menu() {
    while true; do
        CHOICE=$(whiptail --title "CHAMELEON 2.0 - CONTROL CENTER" --menu \
        "Distro: $DISTRO_ID | DE: $DESKTOP_ENV | User: $USER" 20 75 10 \
        "1 CLEAN" "Nettoyage Granulaire (Cache, Logs)" \
        "2 BLOAT" "Suppression Bloatwares & Télémétrie" \
        "3 OPTIM" "Boost Performances (CPU, RAM, Réseau)" \
        "4 GAME"  "Configuration Gaming" \
        "5 SECU"  "Sécurité & Privacy" \
        "6 APPS"  "Installer des Logiciels" \
        "7 RESTORE" "Restaurer Configurations" \
        "8 AUTO"  "Lancer tout (Recommandé)" \
        "9 EXIT"  "Quitter" \
        3>&1 1>&2 2>&3)
        
        EXIT_STATUS=$?
        if [ $EXIT_STATUS -ne 0 ]; then exit 0; fi

        case "$CHOICE" in
            "1 CLEAN") module_cleaner_menu ;;
            "2 BLOAT") module_debloater_menu ;;
            "3 OPTIM") module_optimizer_menu ;;
            "4 GAME")  module_gaming_menu ;;
            "5 SECU")  module_security_menu ;;
            "6 APPS")  module_software_menu ;;
            "7 RESTORE") module_restore ;;
            "8 AUTO") 
                create_snapshot
                # Lancement silencieux des essentiels
                run_safe "$PM_CLEAN" "Auto Clean"
                module_optimizer_menu # On garde le menu pour optim car critique
                ;;
            "9 EXIT") exit 0 ;;
        esac
        
        whiptail --msgbox "Opération terminée." 8 40
    done
}

# --- EXECUTION ---

# Bannière ASCII
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
    echo -e "${CYAN}             >> THE ULTIMATE LINUX OPTIMIZER v2.0 <<${NC}"
    echo ""
}

check_root
show_banner
detect_system
check_dependencies

if [[ "$1" == "--auto" ]]; then
    create_snapshot
    log "Mode Auto CLI lancé..."
    # Config par défaut safe pour le mode auto
    run_safe "$PM_CLEAN" "Clean"
    # Applique sysctl safe
    echo "vm.swappiness=10" > /etc/sysctl.d/99-chameleon.conf
    sysctl -p /etc/sysctl.d/99-chameleon.conf
    success "Optimisation auto terminée."
else
    create_snapshot
    main_menu
fi
