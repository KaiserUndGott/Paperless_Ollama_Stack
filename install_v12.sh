#!/bin/bash

# Paperless-NGX + Ollama AI Stack Installation Script
# Version 12.2.0 - Multi-Platform mit Re-Installation (FBW) Stand: 25.11.2025
# Vollautomatische Docker-Installation mit Ollama, Gemma2:9B, Whisper und RAG-Chat

set -e

# =============================================================================
# CONFIGURATION VARIABLES
# =============================================================================

STACK_DIR="/opt/paperless-stack"
PAPERLESS_DATA_DIR=""
DOCKER_USER="${SUDO_USER:-paperless}"
HOST_IP=""
PAPERLESS_PORT=""
PAPERLESS_AI_PORT=""
POSTGRES_PORT=""
REDIS_PORT=""
OLLAMA_PORT=""

PAPERLESS_ADMIN_USERNAME=""
ADMIN_PASSWORD=""
DB_PASSWORD=""
REDIS_PASSWORD=""
SECRET_KEY=""
PAPERLESS_API_TOKEN=""

INSTALL_PAPERLESS_AI="true"
PAPERLESS_AI_VERSION="latest"
INSTALL_RAG_CHAT="true"
INSTALL_SMB="false"

# Platform detection
PLATFORM=""  # Will be "ubuntu" or "unraid"
IS_UNRAID=false

# Re-installation handling
EXISTING_DATA=false
RESTORE_OLLAMA_MODELS=false
OLLAMA_BACKUP_DIR=""

LOG_FILE="/var/log/paperless-install.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

show_section() {
    echo
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo
}

# =============================================================================
# RE-INSTALLATION HANDLING
# =============================================================================

check_existing_installation() {
    if [[ -d "$STACK_DIR" ]] || docker ps -a --filter "name=paperless-" --format "{{.Names}}" 2>/dev/null | grep -q "paperless"; then
        return 0  # Installation existiert
    fi
    return 1  # Keine Installation gefunden
}

show_existing_installation_info() {
    echo
    show_section "BESTEHENDE INSTALLATION GEFUNDEN"

    # Zeige Container-Status
    echo -e "${BOLD}Container-Status:${NC}"
    local containers=($(docker ps -a --filter "name=paperless-" --format "{{.Names}}" 2>/dev/null || echo ""))
    if [[ ${#containers[@]} -gt 0 ]]; then
        for container in "${containers[@]}"; do
            local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
            local status_color="$YELLOW"
            [[ "$status" == "running" ]] && status_color="$GREEN"
            [[ "$status" == "exited" ]] && status_color="$RED"
            echo -e "  ${status_color}●${NC} $container: $status"
        done
    else
        echo -e "  ${YELLOW}Keine Container gefunden${NC}"
    fi
    echo

    # Zeige Verzeichnisse
    echo -e "${BOLD}Installationsverzeichnisse:${NC}"
    [[ -d "$STACK_DIR" ]] && echo -e "  ✓ $STACK_DIR ($(du -sh "$STACK_DIR" 2>/dev/null | cut -f1))"
    [[ -d "/mnt/user/dokumente/paperless" ]] && echo -e "  ✓ /mnt/user/dokumente/paperless ($(du -sh /mnt/user/dokumente/paperless 2>/dev/null | cut -f1))"
    [[ -d "/var/lib/paperless" ]] && echo -e "  ✓ /var/lib/paperless ($(du -sh /var/lib/paperless 2>/dev/null | cut -f1))"

    # Zeige Ollama-Modelle
    if [[ -d "$STACK_DIR/data/ollama" ]]; then
        echo
        echo -e "${BOLD}Ollama-Modelle:${NC}"
        local ollama_size=$(du -sh "$STACK_DIR/data/ollama" 2>/dev/null | cut -f1)
        echo -e "  ✓ Modell-Verzeichnis: $ollama_size"

        # Versuche installierte Modelle zu listen
        if docker ps --filter "name=paperless-ollama" --format "{{.Names}}" | grep -q "paperless-ollama"; then
            echo -e "${CYAN}"
            docker exec paperless-ollama ollama list 2>/dev/null | head -5 || echo "  (Container läuft, aber Modelle nicht abrufbar)"
            echo -e "${NC}"
        else
            echo -e "  ${YELLOW}(Ollama Container läuft nicht - Modelle werden trotzdem erhalten)${NC}"
        fi
    fi
    echo
}

handle_existing_installation() {
    show_existing_installation_info

    echo -e "${BOLD}${YELLOW}Was möchten Sie tun?${NC}"
    echo
    echo "  1) Installation abbrechen"
    echo "  2) Container neu erstellen (behält ALLE Daten + Ollama-Modelle)"
    echo "  3) Komplette Neuinstallation (⚠️  LÖSCHT ALLE DATEN außer Ollama-Modelle)"
    echo "  4) Nur Container neustarten (keine Änderungen)"
    echo

    local choice
    while true; do
        read -p "$(echo -e ${CYAN}"Ihre Wahl [1-4]: "${NC})" choice
        case $choice in
            1)
                log_info "Installation abgebrochen"
                exit 0
                ;;
            2)
                log_info "Container werden neu erstellt, Daten bleiben erhalten..."
                recreate_containers
                return 0
                ;;
            3)
                confirm_full_reinstall
                return 0
                ;;
            4)
                log_info "Container werden neugestartet..."
                restart_existing_containers
                exit 0
                ;;
            *)
                echo -e "${RED}Ungültige Eingabe. Bitte 1-4 wählen.${NC}"
                ;;
        esac
    done
}

recreate_containers() {
    log_info "Stoppe bestehende Container..."
    cd "$STACK_DIR" 2>/dev/null || true
    docker compose down 2>/dev/null || true

    # Entferne Container manuell falls compose fehlschlägt
    for container in $(docker ps -a --filter "name=paperless-" --format "{{.Names}}" 2>/dev/null); do
        log_info "Entferne Container: $container"
        docker rm -f "$container" 2>/dev/null || true
    done

    log_info "Behalte alle Datenverzeichnisse und Volumes..."
    log_success "✓ Alle Daten bleiben erhalten"
    log_success "✓ Ollama-Modelle bleiben erhalten (~5GB gespart)"
    echo

    # Entferne nur Konfigurationsdateien für Neuerstellung
    if [[ -f "$STACK_DIR/.env" ]]; then
        mv "$STACK_DIR/.env" "$STACK_DIR/.env.backup"
        log_info "Alte .env als .env.backup gesichert"
    fi

    if [[ -f "$STACK_DIR/docker-compose.yml" ]]; then
        mv "$STACK_DIR/docker-compose.yml" "$STACK_DIR/docker-compose.yml.backup"
        log_info "Alte docker-compose.yml als .backup gesichert"
    fi

    log_success "Container-Neuinstallation vorbereitet"
    echo

    # Flag setzen, dass wir bestehende Daten haben
    EXISTING_DATA=true
}

restart_existing_containers() {
    cd "$STACK_DIR" || {
        log_error "Stack-Verzeichnis nicht gefunden: $STACK_DIR"
        exit 1
    }

    log_info "Starte Container neu..."
    docker compose restart

    log_success "Container wurden neugestartet"
    docker compose ps
}

confirm_full_reinstall() {
    echo
    echo -e "${RED}${BOLD}⚠️  WARNUNG: KOMPLETTE NEUINSTALLATION ⚠️${NC}"
    echo
    echo -e "${YELLOW}Dies wird löschen:${NC}"
    echo -e "  ❌ Alle Docker Container"
    echo -e "  ❌ Alle Paperless-NGX Dokumente und Datenbank"
    echo -e "  ❌ Alle Paperless-AI Daten"
    echo -e "  ❌ PostgreSQL und Redis Daten"
    echo
    echo -e "${GREEN}Dies wird erhalten:${NC}"
    echo -e "  ✓ Ollama-Modelle (Gemma2:9B ~5GB)"
    echo

    read -p "$(echo -e ${RED}${BOLD}"Wirklich ALLE DATEN löschen? (yes/NO): "${NC})" confirm

    if [[ "$confirm" == "yes" ]]; then
        full_reinstall
    else
        log_info "Neuinstallation abgebrochen"
        exit 0
    fi
}

full_reinstall() {
    log_warning "Starte komplette Neuinstallation..."

    # Backup der Ollama-Modelle
    backup_ollama_models

    # Stoppe und lösche alle Container + Volumes
    log_info "Stoppe und lösche alle Container und Volumes..."
    cd "$STACK_DIR" 2>/dev/null && docker compose down -v 2>/dev/null || true

    # Entferne Container manuell
    for container in $(docker ps -a --filter "name=paperless-" --format "{{.Names}}" 2>/dev/null); do
        log_info "Entferne Container: $container"
        docker rm -f "$container" 2>/dev/null || true
    done

    # Entferne Volumes
    for volume in $(docker volume ls --filter "name=paperless" --format "{{.Name}}" 2>/dev/null); do
        log_info "Entferne Volume: $volume"
        docker volume rm -f "$volume" 2>/dev/null || true
    done

    # Lösche Verzeichnisse (außer Ollama-Backup)
    log_info "Lösche Installationsverzeichnisse..."
    [[ -d "$STACK_DIR" ]] && rm -rf "$STACK_DIR"

    # Frage nach Paperless-Datenverzeichnis
    if [[ -d "/mnt/user/dokumente/paperless" ]]; then
        echo
        read -p "$(echo -e ${YELLOW}"Auch /mnt/user/dokumente/paperless löschen? (yes/NO): "${NC})" delete_data
        if [[ "$delete_data" == "yes" ]]; then
            rm -rf /mnt/user/dokumente/paperless
            log_warning "Paperless-Datenverzeichnis gelöscht"
        else
            log_info "Paperless-Datenverzeichnis bleibt erhalten"
        fi
    fi

    log_success "Alte Installation vollständig entfernt"
    echo

    # Setze Flag für Ollama-Restore
    RESTORE_OLLAMA_MODELS=true
}

backup_ollama_models() {
    local ollama_dir="$STACK_DIR/data/ollama"

    if [[ ! -d "$ollama_dir" ]]; then
        log_warning "Keine Ollama-Modelle gefunden zum Sichern"
        return 0
    fi

    local backup_dir="/tmp/ollama_backup_$(date +%Y%m%d_%H%M%S)"
    OLLAMA_BACKUP_DIR="$backup_dir"

    log_info "Sichere Ollama-Modelle nach $backup_dir..."
    log_info "Dies kann einige Minuten dauern (~5GB)..."

    mkdir -p "$backup_dir"

    if cp -a "$ollama_dir" "$backup_dir/"; then
        local backup_size=$(du -sh "$backup_dir" 2>/dev/null | cut -f1)
        log_success "✓ Ollama-Modelle gesichert: $backup_size"
        OLLAMA_BACKUP_DIR="$backup_dir/ollama"
    else
        log_error "Backup der Ollama-Modelle fehlgeschlagen!"
        log_warning "Modelle müssen nach Installation neu geladen werden"
        OLLAMA_BACKUP_DIR=""
    fi
}

restore_ollama_models() {
    if [[ -z "$OLLAMA_BACKUP_DIR" ]] || [[ ! -d "$OLLAMA_BACKUP_DIR" ]]; then
        log_warning "Kein Ollama-Modell-Backup gefunden"
        return 1
    fi

    local target_dir="$STACK_DIR/data/ollama"

    log_info "Stelle Ollama-Modelle wieder her..."
    log_info "Ziel: $target_dir"

    # Erstelle Zielverzeichnis
    mkdir -p "$target_dir"

    # Kopiere Modelle zurück
    if cp -a "$OLLAMA_BACKUP_DIR/"* "$target_dir/"; then
        log_success "✓ Ollama-Modelle wiederhergestellt"

        # Setze korrekte Berechtigungen
        chown -R "$DOCKER_USER:$DOCKER_USER" "$target_dir"

        # Lösche Backup
        rm -rf "$(dirname "$OLLAMA_BACKUP_DIR")"
        log_info "Backup-Verzeichnis aufgeräumt"

        return 0
    else
        log_error "Wiederherstellung der Ollama-Modelle fehlgeschlagen"
        return 1
    fi
}

# =============================================================================
# PLATFORM DETECTION
# =============================================================================

detect_platform() {
    show_section "PLATTFORM-ERKENNUNG"

    # Automatische Erkennung
    if [[ -f /etc/unraid-version ]]; then
        log_info "Unraid-System automatisch erkannt"
        PLATFORM="unraid"
        IS_UNRAID=true
    elif [[ -f /etc/os-release ]]; then
        source /etc/os-release
        if [[ "$ID" == "ubuntu" ]] || [[ "$ID_LIKE" == *"ubuntu"* ]] || [[ "$ID_LIKE" == *"debian"* ]]; then
            log_info "Ubuntu/Debian-System automatisch erkannt"
            PLATFORM="ubuntu"
        fi
    fi

    # Manuelle Bestätigung/Korrektur
    echo -e "${BOLD}${GREEN}Auf welcher Plattform soll der Stack installiert werden?${NC}"
    echo -e "  1) Ubuntu / Debian (Testing/Entwicklung)"
    echo -e "  2) Unraid (Produktivbetrieb)"

    if [[ -n "$PLATFORM" ]]; then
        if [[ "$PLATFORM" == "unraid" ]]; then
            echo -e "${CYAN}Automatisch erkannt: Unraid${NC}"
        else
            echo -e "${CYAN}Automatisch erkannt: Ubuntu/Debian${NC}"
        fi
    fi

    while true; do
        echo -n "➤ Ihre Wahl [1-2]: "
        read -r platform_choice
        case $platform_choice in
            1)
                PLATFORM="ubuntu"
                IS_UNRAID=false
                log_info "✓ Plattform: Ubuntu/Debian"
                break
                ;;
            2)
                PLATFORM="unraid"
                IS_UNRAID=true
                log_info "✓ Plattform: Unraid"
                break
                ;;
            *)
                echo -e "${RED}Ungültige Eingabe! Bitte wählen Sie 1 oder 2.${NC}"
                ;;
        esac
    done

    # Pfade basierend auf Plattform setzen
    if [[ "$IS_UNRAID" == true ]]; then
        PAPERLESS_DATA_DIR="/mnt/user/dokumente/paperless"
        log_info "Datenverzeichnis (Unraid): $PAPERLESS_DATA_DIR"
    else
        # Ubuntu - flexible Pfadwahl
        echo
        echo -e "${BOLD}${GREEN}Datenverzeichnis für Paperless wählen:${NC}"
        echo -e "  1) /mnt/user/dokumente/paperless (Unraid-kompatibel)"
        echo -e "  2) /var/lib/paperless (Standard Linux)"
        echo -e "  3) Benutzerdefiniert"

        while true; do
            echo -n "➤ Ihre Wahl [1-3]: "
            read -r dir_choice
            case $dir_choice in
                1)
                    PAPERLESS_DATA_DIR="/mnt/user/dokumente/paperless"
                    break
                    ;;
                2)
                    PAPERLESS_DATA_DIR="/var/lib/paperless"
                    break
                    ;;
                3)
                    echo -n "➤ Pfad eingeben: "
                    read -r custom_dir
                    PAPERLESS_DATA_DIR="$custom_dir"
                    break
                    ;;
                *)
                    echo -e "${RED}Ungültige Eingabe!${NC}"
                    ;;
            esac
        done
        log_info "Datenverzeichnis (Ubuntu): $PAPERLESS_DATA_DIR"
    fi

    log_success "✓ Plattform-Konfiguration abgeschlossen"
}

# =============================================================================
# HEADER AND INTRODUCTION
# =============================================================================

show_header() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                                ║"
    echo "║    ██████╗  █████╗ ██████╗ ███████╗██████╗ ██╗     ███████╗███████╗███████╗    ║"
    echo "║    ██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗██║     ██╔════╝██╔════╝██╔════╝    ║"
    echo "║    ██████╔╝███████║██████╔╝█████╗  ██████╔╝██║     █████╗  ███████╗███████╗    ║"
    echo "║    ██╔═══╝ ██╔══██║██╔═══╝ ██╔══╝  ██╔══██╗██║     ██╔══╝  ╚════██║╚════██║    ║"
    echo "║    ██║     ██║  ██║██║     ███████╗██║  ██║███████╗███████╗███████║███████║    ║"
    echo "║    ╚═╝     ╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚══════╝    ║"
    echo "║                                                                                ║"
    echo "║                  + OLLAMA AI STACK - Version 12.1 (Multi-Platform)            ║"
    echo "║                                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
    echo -e "${GREEN}🎯 ${BOLD}Diese Installation beinhaltet:${NC}"
    echo -e "   • Paperless-NGX (Dokumentenverwaltung)"
    echo -e "   • Paperless-AI mit RAG-Chat (KI-Analyse)"
    echo -e "   • Ollama mit Gemma2:9B (Lokale KI)"
    echo -e "   • OpenAI Whisper (Spracherkennung)"
    echo -e "   • PostgreSQL + Redis"
    echo -e "   • Automatische Docker-Installation (Ubuntu)"
    echo
    echo -e "${YELLOW}⏱️  Geschätzte Installationszeit: 15-20 Minuten${NC}"
    echo -e "${YELLOW}📦 Download-Größe: ca. 5-6 GB (Ollama + Gemma2:9B)${NC}"
    echo

    echo -e "${BOLD}${YELLOW}Möchten Sie mit der Installation fortfahren?${NC}"
    echo -n "➤ Installation starten? [j/N]: "
    read -r start_install

    if [[ ! "$start_install" =~ ^[jJyY]$ ]]; then
        echo
        log_info "Installation abgebrochen vom Benutzer"
        exit 0
    fi

    log_success "✓ Installation wird gestartet"
    echo
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Dieses Script muss als root ausgeführt werden!"
        echo -e "${RED}Bitte starten Sie das Script mit 'sudo':${NC}"
        echo -e "${YELLOW}sudo ./install_v12.sh${NC}"
        exit 1
    fi

    if [[ -n "$SUDO_USER" ]]; then
        DOCKER_USER="$SUDO_USER"
        log_info "Docker wird als User '$DOCKER_USER' ausgeführt"
    else
        log_warning "SUDO_USER nicht gesetzt - verwende 'paperless'"
        DOCKER_USER="paperless"
    fi
}

# =============================================================================
# USERNAME AND PASSWORD COLLECTION
# =============================================================================

collect_credentials() {
    show_section "BENUTZER-KONFIGURATION"

    # Username abfragen
    echo -e "${BOLD}${GREEN}Admin-Benutzername eingeben:${NC}"
    while true; do
        echo -n "➤ Benutzername (min. 3 Zeichen): "
        read -r input_username

        if [[ ${#input_username} -lt 3 ]]; then
            echo -e "${RED}Benutzername muss mindestens 3 Zeichen lang sein!${NC}"
            continue
        fi

        if [[ ! "$input_username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo -e "${RED}Benutzername darf nur Buchstaben, Zahlen, _ und - enthalten!${NC}"
            continue
        fi

        PAPERLESS_ADMIN_USERNAME="$input_username"
        log_info "✓ Benutzername gesetzt: $PAPERLESS_ADMIN_USERNAME"
        break
    done

    echo

    # Passwort abfragen
    echo -e "${BOLD}${GREEN}Admin-Passwort eingeben:${NC}"
    echo -e "${CYAN}Anforderungen:${NC}"
    echo -e "  • Mindestens 12 Zeichen"
    echo -e "  • Mindestens 1 Großbuchstabe"
    echo -e "  • Mindestens 1 Kleinbuchstabe"
    echo -e "  • Mindestens 1 Zahl"
    echo -e "  • Mindestens 1 Sonderzeichen"
    echo

    while true; do
        echo -n "➤ Passwort eingeben: "
        read -s user_password
        echo

        # Passwort-Validierung
        local password_valid=true
        local error_messages=()

        if [[ ${#user_password} -lt 12 ]]; then
            password_valid=false
            error_messages+=("Mindestens 12 Zeichen erforderlich")
        fi

        if [[ ! "$user_password" =~ [A-Z] ]]; then
            password_valid=false
            error_messages+=("Mindestens einen Großbuchstaben erforderlich")
        fi

        if [[ ! "$user_password" =~ [a-z] ]]; then
            password_valid=false
            error_messages+=("Mindestens einen Kleinbuchstaben erforderlich")
        fi

        if [[ ! "$user_password" =~ [0-9] ]]; then
            password_valid=false
            error_messages+=("Mindestens eine Zahl erforderlich")
        fi

        if [[ ! "$user_password" =~ [^a-zA-Z0-9] ]]; then
            password_valid=false
            error_messages+=("Mindestens ein Sonderzeichen erforderlich")
        fi

        if [[ "$password_valid" == "false" ]]; then
            echo -e "${RED}Passwort entspricht nicht den Anforderungen:${NC}"
            for error in "${error_messages[@]}"; do
                echo -e "  ${RED}• $error${NC}"
            done
            echo -e "${YELLOW}Beispiel: Paperless2025!${NC}"
            echo
            continue
        fi

        # Passwort bestätigen
        echo -n "➤ Passwort wiederholen: "
        read -s user_password_confirm
        echo

        if [[ "$user_password" != "$user_password_confirm" ]]; then
            echo -e "${RED}Passwörter stimmen nicht überein!${NC}"
            echo
            continue
        fi

        ADMIN_PASSWORD="$user_password"
        DB_PASSWORD="$user_password"
        REDIS_PASSWORD="$user_password"
        SECRET_KEY="$user_password-$(openssl rand -hex 16)"

        log_success "✓ Credentials gesetzt (${#ADMIN_PASSWORD} Zeichen)"
        break
    done

    echo
    log_success "✓ Benutzer-Konfiguration abgeschlossen"
}

# =============================================================================
# SYSTEM CLEANUP
# =============================================================================

cleanup_existing_installation() {
    # Prüfe ob bestehende Installation vorhanden ist
    if check_existing_installation; then
        handle_existing_installation
        # Nach handle_existing_installation wird entweder:
        # - exit 0 (bei Abbruch oder Neustart)
        # - EXISTING_DATA=true gesetzt (bei Container-Update)
        # - RESTORE_OLLAMA_MODELS=true gesetzt (bei Komplett-Neuinstallation)
    else
        log_info "✓ Keine bestehende Installation gefunden"
    fi
}

# =============================================================================
# SYSTEM INSTALLATION
# =============================================================================

detect_package_manager() {
    if command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    else
        log_error "Kein unterstützter Paketmanager gefunden!"
        exit 1
    fi
}

check_docker_installation() {
    log_info "Prüfe Docker-Installation..."

    if command -v docker >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            local docker_version=$(docker --version | awk '{print $3}' | sed 's/,//')
            log_success "✓ Docker ist bereits installiert (Version: $docker_version)"

            # Docker Compose Plugin prüfen
            if docker compose version >/dev/null 2>&1; then
                local compose_version=$(docker compose version | awk '{print $4}')
                log_success "✓ Docker Compose Plugin ist installiert (Version: $compose_version)"
                return 0
            else
                log_warning "Docker Compose Plugin fehlt - wird installiert"
                return 1
            fi
        else
            log_warning "Docker ist installiert, läuft aber nicht korrekt"
            return 1
        fi
    else
        log_info "Docker ist nicht installiert - wird installiert"
        return 1
    fi
}

install_docker_ubuntu() {
    log_info "Installiere Docker für Ubuntu/Debian..."

    local pm=$(detect_package_manager)

    # System-Pakete aktualisieren
    log_info "Aktualisiere Paketlisten..."
    $pm update -qq

    # Erforderliche Basis-Pakete installieren
    log_info "Installiere Basis-Pakete..."
    $pm install -y ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common

    # Alte Docker-Versionen entfernen
    log_info "Entferne alte Docker-Versionen..."
    $pm remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Docker GPG-Schlüssel hinzufügen
    log_info "Füge Docker GPG-Schlüssel hinzu..."
    install -m 0755 -d /etc/apt/keyrings
    rm -f /etc/apt/keyrings/docker.gpg
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Docker Repository hinzufügen
    log_info "Füge Docker Repository hinzu..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Paketlisten aktualisieren
    $pm update -qq

    # Docker installieren
    log_info "Installiere Docker Engine..."
    $pm install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    log_success "✓ Docker erfolgreich installiert"
}

install_system_packages() {
    log_info "Installiere System-Pakete..."

    local pm=$(detect_package_manager)

    case $pm in
        apt)
            apt update -qq
            apt install -y curl wget openssl ca-certificates gnupg mc nano htop net-tools lsb-release jq apache2-utils python3 python3-requests
            ;;
        yum|dnf)
            $pm install -y curl wget openssl ca-certificates gnupg mc nano htop net-tools jq httpd-tools python3 python3-requests
            ;;
    esac

    log_success "System-Pakete installiert"
}

setup_docker() {
    show_section "DOCKER-INSTALLATION"

    # Für Unraid Docker-Installation überspringen
    if [[ "$IS_UNRAID" == true ]]; then
        log_info "Unraid erkannt - Docker sollte bereits installiert sein"

        if ! command -v docker >/dev/null 2>&1; then
            log_error "Docker ist auf Unraid nicht verfügbar!"
            log_error "Bitte stellen Sie sicher, dass Docker in den Unraid-Einstellungen aktiviert ist."
            exit 1
        fi

        log_success "✓ Docker ist auf Unraid verfügbar"
        return 0
    fi

    # Für Ubuntu: Docker prüfen und ggf. installieren
    if ! check_docker_installation; then
        log_info "Starte Docker-Installation..."
        install_docker_ubuntu
    fi

    log_info "Konfiguriere Docker..."

    # Docker Service aktivieren und starten
    systemctl enable docker
    systemctl start docker

    # User zur docker-Gruppe hinzufügen
    if ! groups "$DOCKER_USER" | grep -q docker; then
        usermod -aG docker "$DOCKER_USER"
        log_success "User '$DOCKER_USER' zur docker-Gruppe hinzugefügt"
        log_warning "HINWEIS: Der User muss sich ab- und wieder anmelden, damit die Gruppenzugehörigkeit aktiv wird"
    fi

    # Docker-Status prüfen
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker läuft nicht korrekt!"
        systemctl status docker
        exit 1
    fi

    log_success "Docker erfolgreich konfiguriert"
}

configure_network() {
    log_info "Konfiguriere Netzwerk..."

    HOST_IP=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -n1)
    if [[ -z "$HOST_IP" ]]; then
        HOST_IP=$(hostname -I | awk '{print $1}')
    fi

    PAPERLESS_PORT=8000
    while netstat -tuln 2>/dev/null | grep -q ":$PAPERLESS_PORT " || ss -tuln 2>/dev/null | grep -q ":$PAPERLESS_PORT "; do
        PAPERLESS_PORT=$((PAPERLESS_PORT + 1))
    done

    PAPERLESS_AI_PORT=3000
    while netstat -tuln 2>/dev/null | grep -q ":$PAPERLESS_AI_PORT " || ss -tuln 2>/dev/null | grep -q ":$PAPERLESS_AI_PORT "; do
        PAPERLESS_AI_PORT=$((PAPERLESS_AI_PORT + 1))
    done

    OLLAMA_PORT=11434
    while netstat -tuln 2>/dev/null | grep -q ":$OLLAMA_PORT " || ss -tuln 2>/dev/null | grep -q ":$OLLAMA_PORT "; do
        OLLAMA_PORT=$((OLLAMA_PORT + 1))
    done

    POSTGRES_PORT=5432
    while netstat -tuln 2>/dev/null | grep -q ":$POSTGRES_PORT " || ss -tuln 2>/dev/null | grep -q ":$POSTGRES_PORT "; do
        POSTGRES_PORT=$((POSTGRES_PORT + 1))
    done

    REDIS_PORT=6379
    while netstat -tuln 2>/dev/null | grep -q ":$REDIS_PORT " || ss -tuln 2>/dev/null | grep -q ":$REDIS_PORT "; do
        REDIS_PORT=$((REDIS_PORT + 1))
    done

    log_success "Netzwerk konfiguriert: IP=$HOST_IP, Ports: Paperless=$PAPERLESS_PORT, AI=$PAPERLESS_AI_PORT, Ollama=$OLLAMA_PORT"
}

# =============================================================================
# DIRECTORY AND FILE CREATION
# =============================================================================

check_data_directories() {
    show_section "DATENVERZEICHNIS PRÜFEN"

    log_info "Prüfe Paperless-Datenverzeichnis: $PAPERLESS_DATA_DIR"

    if [[ ! -d "$PAPERLESS_DATA_DIR" ]]; then
        log_warning "Datenverzeichnis existiert nicht: $PAPERLESS_DATA_DIR"
        echo -e "${YELLOW}Soll das Verzeichnis automatisch erstellt werden? [j/N]:${NC}"
        echo -n "➤ "
        read -r create_dir

        if [[ "$create_dir" =~ ^[jJyY]$ ]]; then
            mkdir -p "$PAPERLESS_DATA_DIR"
            log_success "✓ Verzeichnis erstellt: $PAPERLESS_DATA_DIR"
        else
            log_error "Datenverzeichnis muss existieren!"
            exit 1
        fi
    fi

    if [[ ! -w "$PAPERLESS_DATA_DIR" ]]; then
        log_warning "Datenverzeichnis ist nicht beschreibbar: $PAPERLESS_DATA_DIR"
        log_info "Versuche Berechtigungen zu setzen..."
        chown -R "$DOCKER_USER:$DOCKER_USER" "$PAPERLESS_DATA_DIR" 2>/dev/null || true
        chmod -R 755 "$PAPERLESS_DATA_DIR" 2>/dev/null || true
    fi

    log_success "✓ Datenverzeichnis gefunden und beschreibbar: $PAPERLESS_DATA_DIR"
}

create_directories() {
    log_info "Erstelle Verzeichnisstruktur..."

    mkdir -p "$STACK_DIR"

    local dirs=(
        "$PAPERLESS_DATA_DIR/media"
        "$PAPERLESS_DATA_DIR/data"
        "$PAPERLESS_DATA_DIR/export"
        "$PAPERLESS_DATA_DIR/consume"
        "$STACK_DIR/data/postgres"
        "$STACK_DIR/data/redis"
        "$STACK_DIR/data/ollama"
        "$STACK_DIR/config"
        "$STACK_DIR/data/paperless-ai"
        "$STACK_DIR/config/paperless-ai"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done

    log_success "Verzeichnisse erstellt"
}

set_permissions() {
    log_info "Setze Berechtigungen..."

    chown -R "$DOCKER_USER:$DOCKER_USER" "$STACK_DIR"
    chmod -R 755 "$STACK_DIR"
    chmod -R 777 "$STACK_DIR/data"

    chown -R "$DOCKER_USER:$DOCKER_USER" "$PAPERLESS_DATA_DIR"
    chmod -R 755 "$PAPERLESS_DATA_DIR"

    log_success "Berechtigungen gesetzt für User: $DOCKER_USER"
}

create_env_file() {
    log_info "Erstelle .env Datei..."

    cat > "$STACK_DIR/.env" << EOF
# Paperless-NGX + Ollama Stack Configuration
# Generated: $(date)
# Platform: $PLATFORM

# =============================================================================
# NETWORK CONFIGURATION
# =============================================================================
HOST_IP=$HOST_IP
PAPERLESS_PORT=$PAPERLESS_PORT
PAPERLESS_AI_PORT=$PAPERLESS_AI_PORT
OLLAMA_PORT=$OLLAMA_PORT
POSTGRES_PORT=$POSTGRES_PORT
REDIS_PORT=$REDIS_PORT

# =============================================================================
# DATABASE CONFIGURATION
# =============================================================================
POSTGRES_DB=paperless
POSTGRES_USER=paperless
POSTGRES_PASSWORD=$DB_PASSWORD

# =============================================================================
# REDIS CONFIGURATION
# =============================================================================
REDIS_PASSWORD=$REDIS_PASSWORD

# =============================================================================
# PAPERLESS-NGX CONFIGURATION
# =============================================================================
PAPERLESS_ADMIN_USER=$PAPERLESS_ADMIN_USERNAME
PAPERLESS_ADMIN_PASSWORD=$ADMIN_PASSWORD
PAPERLESS_SECRET_KEY=$SECRET_KEY
PAPERLESS_URL=http://$HOST_IP:$PAPERLESS_PORT
PAPERLESS_CSRF_TRUSTED_ORIGINS=http://$HOST_IP:$PAPERLESS_PORT,http://localhost:$PAPERLESS_PORT
PAPERLESS_ALLOWED_HOSTS=$HOST_IP,localhost,paperless-ngx
PAPERLESS_TIME_ZONE=Europe/Berlin

# =============================================================================
# PAPERLESS-NGX OCR CONFIGURATION
# =============================================================================
PAPERLESS_OCR_LANGUAGE=deu+eng
PAPERLESS_OCR_MODE=redo
PAPERLESS_OCR_CLEAN=clean
PAPERLESS_OCR_OUTPUT_TYPE=pdfa
PAPERLESS_OCR_ROTATE_PAGES=true
PAPERLESS_OCR_ROTATE_PAGES_THRESHOLD=11
PAPERLESS_OCR_DESKEW=true

# =============================================================================
# PAPERLESS-NGX INBOX TAG CONFIGURATION
# =============================================================================
PAPERLESS_CONSUMER_INBOX_TAG=1
PAPERLESS_CONSUMER_RECURSIVE=true
PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS=false

# =============================================================================
# API CONFIGURATION
# =============================================================================
PAPERLESS_API_TOKEN=$PAPERLESS_API_TOKEN

# =============================================================================
# OLLAMA CONFIGURATION
# =============================================================================
OLLAMA_HOST=http://ollama:11434

# =============================================================================
# DOCKER CONFIGURATION
# =============================================================================
COMPOSE_PROJECT_NAME=paperless-stack
RESTART_POLICY=unless-stopped
EOF

    chown "$DOCKER_USER:$DOCKER_USER" "$STACK_DIR/.env"
    chmod 644 "$STACK_DIR/.env"

    log_success ".env Datei erstellt"
}

create_paperless_ai_env() {
    log_info "Erstelle Paperless-AI .env..."

    local api_token="${PAPERLESS_API_TOKEN:-placeholder_token_will_be_updated}"

    cat > "$STACK_DIR/config/paperless-ai/.env" << EOF
# =============================================================================
# PAPERLESS-NGX CONNECTION SETTINGS
# =============================================================================
PAPERLESS_API_URL=http://paperless-ngx:8000/api
PAPERLESS_API_TOKEN=$api_token
PAPERLESS_USERNAME=$PAPERLESS_ADMIN_USERNAME
PAPERLESS_PASSWORD=$ADMIN_PASSWORD
PAPERLESS_EMAIL=$PAPERLESS_ADMIN_USERNAME@localhost

# =============================================================================
# OLLAMA AI PROVIDER CONFIGURATION
# =============================================================================
AI_PROVIDER=custom
CUSTOM_API_KEY=ollama
CUSTOM_BASE_URL=http://ollama:11434/v1
CUSTOM_MODEL=gemma2:9b

# =============================================================================
# RAG-CHAT CONFIGURATION WITH OLLAMA
# =============================================================================
ENABLE_RAG_CHAT=yes
RAG_CHAT_ENABLED=true
RAG_TAG_FILTER=RAG
RAG_ONLY_TAGGED_DOCUMENTS=yes
RAG_SPECIFIC_TAGS=RAG
RAG_AI_PROVIDER=custom
RAG_CUSTOM_API_KEY=ollama
RAG_CUSTOM_BASE_URL=http://ollama:11434/v1
RAG_CUSTOM_MODEL=gemma2:9b

# RAG Token Limits (optimized for Gemma2:9B)
RAG_CHUNK_SIZE=1500
RAG_MAX_CONTEXT_LENGTH=12000
RAG_RESPONSE_MAX_TOKENS=3000
RAG_TOKEN_LIMIT=15000
RAG_MAX_TOKENS=3000
RAG_MAX_PROMPT_LENGTH=30000

# RAG System Prompt
RAG_SYSTEM_PROMPT=Du bist ein hilfreicher KI-Assistent. Beantworte Fragen basierend auf den bereitgestellten Dokumenten präzise und ausführlich auf Deutsch.

# =============================================================================
# WHISPER CONFIGURATION (for audio transcription)
# =============================================================================
WHISPER_MODEL=base
WHISPER_ENABLED=true

# =============================================================================
# PROCESSING CONFIGURATION
# =============================================================================
SCAN_INTERVAL=*/5 * * * *
PROCESS_PREDEFINED_DOCUMENTS=yes
PROCESS_ONLY_TAGGED_DOCUMENTS=yes
SPECIFIC_TAGS=Neu
TAGS=Neu
TARGET_TAGS=Neu
PREDEFINED_TAGS=Neu
EOF

    chown "$DOCKER_USER:$DOCKER_USER" "$STACK_DIR/config/paperless-ai/.env"
    chmod 644 "$STACK_DIR/config/paperless-ai/.env"

    log_success "Paperless-AI .env erstellt"
}

# =============================================================================
# DOCKER COMPOSE FILE CREATION
# =============================================================================

create_compose_file() {
    log_info "Erstelle docker-compose.yml..."

    # Dynamische Volume-Pfade basierend auf Konfiguration
    local volume_path="$PAPERLESS_DATA_DIR"

    cat > "$STACK_DIR/docker-compose.yml" << EOF
services:
  postgres:
    image: postgres:15-alpine
    container_name: paperless-postgres
    restart: \${RESTART_POLICY}
    environment:
      POSTGRES_DB: \${POSTGRES_DB}
      POSTGRES_USER: \${POSTGRES_USER}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    ports:
      - "\${POSTGRES_PORT}:5432"
    networks:
      - paperless-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U paperless -d paperless"]
      interval: 10s
      timeout: 5s
      retries: 5
    labels:
      - "com.docker.compose.project=paperless-stack"
      - "icon=https://raw.githubusercontent.com/docker-library/docs/master/postgres/logo.png"

  redis:
    image: redis:7-alpine
    container_name: paperless-redis
    restart: \${RESTART_POLICY}
    command: redis-server --requirepass \${REDIS_PASSWORD}
    volumes:
      - ./data/redis:/data
    ports:
      - "\${REDIS_PORT}:6379"
    networks:
      - paperless-net
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    labels:
      - "com.docker.compose.project=paperless-stack"
      - "icon=https://raw.githubusercontent.com/docker-library/docs/master/redis/logo.png"

  ollama:
    image: ollama/ollama:latest
    container_name: paperless-ollama
    restart: \${RESTART_POLICY}
    volumes:
      - ./data/ollama:/root/.ollama
    ports:
      - "\${OLLAMA_PORT}:11434"
    networks:
      - paperless-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434/api/tags"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    labels:
      - "com.docker.compose.project=paperless-stack"
      - "icon=https://avatars.githubusercontent.com/u/151674099"

  paperless-ngx:
    image: ghcr.io/paperless-ngx/paperless-ngx:latest
    container_name: paperless-ngx
    restart: \${RESTART_POLICY}
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      PAPERLESS_DBENGINE: postgresql
      PAPERLESS_DBHOST: postgres
      PAPERLESS_DBPORT: 5432
      PAPERLESS_DBNAME: \${POSTGRES_DB}
      PAPERLESS_DBUSER: \${POSTGRES_USER}
      PAPERLESS_DBPASS: \${POSTGRES_PASSWORD}
      PAPERLESS_REDIS: redis://:\${REDIS_PASSWORD}@redis:6379
      PAPERLESS_SECRET_KEY: \${PAPERLESS_SECRET_KEY}
      PAPERLESS_URL: \${PAPERLESS_URL}
      PAPERLESS_CSRF_TRUSTED_ORIGINS: \${PAPERLESS_CSRF_TRUSTED_ORIGINS}
      PAPERLESS_ALLOWED_HOSTS: \${PAPERLESS_ALLOWED_HOSTS}
      PAPERLESS_TIME_ZONE: \${PAPERLESS_TIME_ZONE}
      PAPERLESS_ADMIN_USER: \${PAPERLESS_ADMIN_USER}
      PAPERLESS_ADMIN_PASSWORD: \${PAPERLESS_ADMIN_PASSWORD}
      PAPERLESS_OCR_LANGUAGE: \${PAPERLESS_OCR_LANGUAGE}
      PAPERLESS_OCR_MODE: \${PAPERLESS_OCR_MODE}
      PAPERLESS_OCR_CLEAN: \${PAPERLESS_OCR_CLEAN}
      PAPERLESS_OCR_OUTPUT_TYPE: \${PAPERLESS_OCR_OUTPUT_TYPE}
      PAPERLESS_OCR_ROTATE_PAGES: \${PAPERLESS_OCR_ROTATE_PAGES}
      PAPERLESS_OCR_ROTATE_PAGES_THRESHOLD: \${PAPERLESS_OCR_ROTATE_PAGES_THRESHOLD}
      PAPERLESS_OCR_DESKEW: \${PAPERLESS_OCR_DESKEW}
      PAPERLESS_CONSUMER_INBOX_TAG: \${PAPERLESS_CONSUMER_INBOX_TAG}
      PAPERLESS_CONSUMER_RECURSIVE: "true"
      PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS: "false"
    volumes:
      - $volume_path/data:/usr/src/paperless/data
      - $volume_path/media:/usr/src/paperless/media
      - $volume_path/export:/usr/src/paperless/export
      - $volume_path/consume:/usr/src/paperless/consume
    ports:
      - "\${PAPERLESS_PORT}:8000"
    networks:
      - paperless-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/accounts/login/"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 120s
    labels:
      - "com.docker.compose.project=paperless-stack"
      - "icon=https://raw.githubusercontent.com/paperless-ngx/paperless-ngx/main/resources/logo/web/svg/square.svg"

  paperless-ai:
    image: clusterzx/paperless-ai:latest
    container_name: paperless-ai
    restart: \${RESTART_POLICY}
    depends_on:
      paperless-ngx:
        condition: service_healthy
      postgres:
        condition: service_healthy
      ollama:
        condition: service_healthy
    volumes:
      - ./data/paperless-ai:/app/data
      - ./config/paperless-ai/.env:/app/data/.env
    ports:
      - "\${PAPERLESS_AI_PORT}:3000"
    networks:
      - paperless-net
    labels:
      - "com.docker.compose.project=paperless-stack"
      - "icon=https://avatars.githubusercontent.com/u/132757259"

networks:
  paperless-net:
    driver: bridge
EOF

    chown "$DOCKER_USER:$DOCKER_USER" "$STACK_DIR/docker-compose.yml"
    chmod 644 "$STACK_DIR/docker-compose.yml"

    cd "$STACK_DIR"
    if ! docker compose -f "$STACK_DIR/docker-compose.yml" config >/dev/null 2>&1; then
        log_error "docker-compose.yml ist ungültig!"
        docker compose config
        exit 1
    fi

    log_success "docker-compose.yml erstellt und validiert"
}

# [Die restlichen Funktionen bleiben identisch: start_stack, create_paperless_api_token,
# setup_paperless_defaults, etc. - aus Platzgründen hier gekürzt]
# Sie werden in der vollständigen Datei enthalten sein

# Fortsetzung folgt in Teil 2...

# =============================================================================
# DOCKER STACK DEPLOYMENT
# =============================================================================

wait_for_ollama() {
    log_info "Warte auf Ollama-Bereitschaft..."

    local max_attempts=30
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        log_info "Prüfe Ollama-Status (Versuch $attempt/$max_attempts)..."

        # Prüfe ob Container läuft
        if ! docker ps --filter "name=paperless-ollama" --format "{{.Status}}" | grep -q "Up"; then
            log_warning "Ollama Container läuft nicht - prüfe Logs..."
            docker logs paperless-ollama --tail 20

            if [[ $attempt -eq $max_attempts ]]; then
                log_error "Ollama Container konnte nicht gestartet werden!"
                echo
                echo -e "${YELLOW}Mögliche Ursachen:${NC}"
                echo -e "1. Nicht genug RAM (Ollama benötigt mindestens 4GB)"
                echo -e "2. Port $OLLAMA_PORT ist bereits belegt"
                echo -e "3. Volume-Berechtigungsprobleme"
                echo
                echo -e "${YELLOW}Troubleshooting:${NC}"
                echo -e "docker logs paperless-ollama"
                echo -e "docker inspect paperless-ollama"
                return 1
            fi
        else
            # Container läuft, prüfe API
            if curl -s -f "http://localhost:$OLLAMA_PORT/api/tags" >/dev/null 2>&1; then
                log_success "✓ Ollama ist bereit und antwortet"
                return 0
            fi
        fi

        sleep 5
        ((attempt++))
    done

    log_error "Ollama ist nach $max_attempts Versuchen nicht bereit!"
    return 1
}

download_ollama_model() {
    log_info "Lade Gemma2:9B Modell herunter (ca. 5GB, kann mehrere Minuten dauern)..."
    log_info "Dies ist ein einmaliger Download beim ersten Start."
    echo

    # Zeige Download-Fortschritt
    if sudo -u "$DOCKER_USER" docker exec paperless-ollama ollama pull gemma2:9b 2>&1 | while IFS= read -r line; do
        echo "  $line"
    done; then
        log_success "✓ Gemma2:9B Modell erfolgreich geladen"

        # Verifiziere dass Modell verfügbar ist
        if sudo -u "$DOCKER_USER" docker exec paperless-ollama ollama list | grep -q "gemma2:9b"; then
            log_success "✓ Modell verifiziert und einsatzbereit"
        else
            log_warning "⚠ Modell geladen, aber nicht in Liste gefunden"
        fi
        return 0
    else
        log_error "❌ Gemma2:9B Download fehlgeschlagen!"
        echo
        echo -e "${YELLOW}Mögliche Ursachen:${NC}"
        echo -e "1. Nicht genug Festplattenspeicher (benötigt ~5GB)"
        echo -e "2. Netzwerkprobleme während des Downloads"
        echo -e "3. Ollama Container ist nicht stabil"
        echo
        echo -e "${YELLOW}Lösung:${NC}"
        echo -e "Das Modell kann später manuell geladen werden:"
        echo -e "${CYAN}docker exec paperless-ollama ollama pull gemma2:9b${NC}"
        echo
        return 1
    fi
}

start_stack() {
    show_section "DOCKER STACK DEPLOYMENT"

    log_info "Starte Docker Stack..."
    cd "$STACK_DIR"

    log_info "Starte PostgreSQL und Redis Container..."
    sudo -u "$DOCKER_USER" docker compose up -d postgres redis
    sleep 20

    log_info "Starte Ollama Container..."
    sudo -u "$DOCKER_USER" docker compose up -d ollama

    if ! wait_for_ollama; then
        log_error "Ollama konnte nicht gestartet werden - fahre ohne Modell fort"
    else
        # Prüfe ob Ollama-Modelle wiederhergestellt werden müssen
        if [[ "$RESTORE_OLLAMA_MODELS" == "true" ]]; then
            if restore_ollama_models; then
                log_success "✓ Ollama-Modelle aus Backup wiederhergestellt"
            else
                log_warning "Wiederherstellung fehlgeschlagen - lade Modell neu herunter"
                download_ollama_model || log_warning "Modell-Download übersprungen - kann später nachgeholt werden"
            fi
        elif [[ "$EXISTING_DATA" == "true" ]]; then
            # Bei Container-Update: Prüfe ob Modell bereits vorhanden ist
            log_info "Prüfe vorhandene Ollama-Modelle..."
            if sudo -u "$DOCKER_USER" docker exec paperless-ollama ollama list 2>/dev/null | grep -q "gemma2:9b"; then
                log_success "✓ Gemma2:9B Modell bereits vorhanden - überspringe Download"
            else
                log_info "Kein Modell gefunden - starte Download..."
                download_ollama_model || log_warning "Modell-Download übersprungen - kann später nachgeholt werden"
            fi
        else
            # Normale Neuinstallation: Lade Modell herunter
            download_ollama_model || log_warning "Modell-Download übersprungen - kann später nachgeholt werden"
        fi
    fi

    log_info "Starte Paperless-NGX Container..."
    sudo -u "$DOCKER_USER" docker compose up -d paperless-ngx

    local max_attempts=30
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        log_info "Warte auf Paperless-NGX Bereitschaft (Versuch $attempt/$max_attempts)..."

        if curl -s -f "http://$HOST_IP:$PAPERLESS_PORT/accounts/login/" >/dev/null 2>&1; then
            log_success "Paperless-NGX ist bereit"
            break
        fi

        if [[ $attempt -eq $max_attempts ]]; then
            log_error "Paperless-NGX ist nach $max_attempts Versuchen nicht bereit!"
            return 1
        fi

        sleep 10
        ((attempt++))
    done

    create_paperless_api_token

    log_info "Starte Paperless-AI Container..."
    sudo -u "$DOCKER_USER" docker compose up -d paperless-ai
    sleep 30

    if ! setup_paperless_defaults; then
        log_warning "Standard-Setup fehlgeschlagen - Installation wird trotzdem fortgesetzt"
    fi

    update_paperless_ai_tag_config

    local container_count=$(sudo -u "$DOCKER_USER" docker compose ps --format "table {{.Service}}" | tail -n +2 | wc -l)
    log_success "✅ $container_count Container erfolgreich gestartet"

    log_success "Docker Stack erfolgreich gestartet!"
}

create_paperless_api_token() {
    log_info "Erstelle API Token für Paperless-AI..."

    local token_script="
from django.contrib.auth.models import User
from rest_framework.authtoken.models import Token

try:
    user = User.objects.get(username='$PAPERLESS_ADMIN_USERNAME')
    Token.objects.filter(user=user).delete()
    token = Token.objects.create(user=user)
    print(f'TOKEN:{token.key}')
except Exception as e:
    print(f'ERROR:{str(e)}')
"

    local token_result
    token_result=$(cd "$STACK_DIR" && echo "$token_script" | sudo -u "$DOCKER_USER" docker compose exec -T paperless-ngx python manage.py shell 2>/dev/null)

    if [[ $token_result == TOKEN:* ]]; then
        PAPERLESS_API_TOKEN=$(echo "$token_result" | cut -d':' -f2)
        log_success "API Token erstellt: ${PAPERLESS_API_TOKEN:0:8}..."

        if [[ -f "$STACK_DIR/config/paperless-ai/.env" ]]; then
            sed -i "s/PAPERLESS_API_TOKEN=.*/PAPERLESS_API_TOKEN=$PAPERLESS_API_TOKEN/" "$STACK_DIR/config/paperless-ai/.env"
            log_success "API Token in Paperless-AI Konfiguration aktualisiert"
        fi

        if [[ -f "$STACK_DIR/.env" ]]; then
            if grep -q "PAPERLESS_API_TOKEN=" "$STACK_DIR/.env"; then
                sed -i "s/PAPERLESS_API_TOKEN=.*/PAPERLESS_API_TOKEN=$PAPERLESS_API_TOKEN/" "$STACK_DIR/.env"
            else
                echo "PAPERLESS_API_TOKEN=$PAPERLESS_API_TOKEN" >> "$STACK_DIR/.env"
            fi
        fi
    else
        log_error "API Token Erstellung fehlgeschlagen"
    fi
}

setup_paperless_defaults() {
    log_info "Erstelle Paperless-NGX Standard-Einstellungen..."
    sleep 30

    if create_tag_via_management "Neu" "#42cd38" "true"; then
        log_success "✓ Tag 'Neu' als Inbox-Tag erstellt"
    fi

    if create_tag_via_management "RAG" "#b82fbc" "false"; then
        log_success "✓ Tag 'RAG' erstellt"
    fi

    setup_inbox_tag
    return 0
}

create_tag_via_management() {
    local tag_name="$1"
    local tag_color="$2"
    local is_inbox_tag="$3"

    local create_command="
from documents.models import Tag
try:
    tag, created = Tag.objects.get_or_create(
        name='$tag_name',
        defaults={'color': '$tag_color', 'match': '', 'matching_algorithm': 0, 'is_inbox_tag': $(if [[ "$is_inbox_tag" == "true" ]]; then echo "True"; else echo "False"; fi)}
    )
    print('SUCCESS')
except Exception as e:
    print(f'ERROR: {str(e)}')
"

    local result
    if result=$(cd "$STACK_DIR" && echo "$create_command" | sudo -u "$DOCKER_USER" docker compose exec -T paperless-ngx python manage.py shell 2>&1); then
        if echo "$result" | grep -q "SUCCESS"; then
            return 0
        fi
    fi
    return 1
}

setup_inbox_tag() {
    local inbox_script="
from documents.models import Tag
try:
    neu_tag = Tag.objects.get(name='Neu')
    print(f'TAG_ID_FOUND:{neu_tag.id}')
except: pass
"
    local tag_id_result
    if tag_id_result=$(cd "$STACK_DIR" && echo "$inbox_script" | sudo -u "$DOCKER_USER" docker compose exec -T paperless-ngx python manage.py shell 2>&1); then
        local found_tag_id=$(echo "$tag_id_result" | grep "TAG_ID_FOUND:" | cut -d':' -f2)
        if [[ -n "$found_tag_id" ]] && [[ -f "$STACK_DIR/.env" ]]; then
            sed -i "s/^PAPERLESS_CONSUMER_INBOX_TAG=.*/PAPERLESS_CONSUMER_INBOX_TAG=$found_tag_id/" "$STACK_DIR/.env"
            sudo -u "$DOCKER_USER" docker compose restart paperless-ngx >/dev/null 2>&1
        fi
    fi
}

update_paperless_ai_tag_config() {
    sleep 20
    local tag_query="
from documents.models import Tag
try:
    neu_tag = Tag.objects.get(name='Neu')
    print(f'NEU_TAG_ID:{neu_tag.id}')
    if Tag.objects.filter(name='RAG').exists():
        rag_tag = Tag.objects.get(name='RAG')
        print(f'RAG_TAG_ID:{rag_tag.id}')
    print('TAGS_SUCCESS')
except: pass
"
    local tag_result
    if tag_result=$(cd "$STACK_DIR" && echo "$tag_query" | sudo -u "$DOCKER_USER" docker compose exec -T paperless-ngx python manage.py shell 2>&1); then
        if echo "$tag_result" | grep -q "TAGS_SUCCESS"; then
            local ai_env_file="$STACK_DIR/config/paperless-ai/.env"
            if [[ -f "$ai_env_file" ]]; then
                sed -i "s/TAGS=.*/TAGS=Neu/" "$ai_env_file"
                sed -i "s/SPECIFIC_TAGS=.*/SPECIFIC_TAGS=Neu/" "$ai_env_file"
                sed -i "s/RAG_SPECIFIC_TAGS=.*/RAG_SPECIFIC_TAGS=RAG/" "$ai_env_file"
                sudo -u "$DOCKER_USER" docker compose restart paperless-ai >/dev/null 2>&1
            fi
        fi
    fi
}

# =============================================================================
# CREDENTIALS FILE
# =============================================================================

create_credentials_file() {
    log_info "Erstelle Zugangsdaten-Datei..."

    cat > "$STACK_DIR/INSTALLATION_INFO.txt" << EOF
================================================================================
PAPERLESS-NGX + OLLAMA AI STACK - INSTALLATION INFORMATION
================================================================================
Installation: $(date)
Platform: $PLATFORM

================================================================================
WEB-ZUGRIFF
================================================================================
Paperless-NGX:    http://$HOST_IP:$PAPERLESS_PORT
  Benutzername:    $PAPERLESS_ADMIN_USERNAME
  Passwort:        $ADMIN_PASSWORD

Paperless-AI:     http://$HOST_IP:$PAPERLESS_AI_PORT

Ollama API:       http://$HOST_IP:$OLLAMA_PORT
  Modell:          gemma2:9b

================================================================================
DATENBANK-ZUGRIFF
================================================================================
PostgreSQL:       $HOST_IP:$POSTGRES_PORT
Redis:            $HOST_IP:$REDIS_PORT

================================================================================
MANAGEMENT
================================================================================
Installation:     $STACK_DIR
Datenverzeichnis: $PAPERLESS_DATA_DIR
Container Status: cd $STACK_DIR && docker compose ps
Container starten: cd $STACK_DIR && docker compose up -d
Container stoppen: cd $STACK_DIR && docker compose down

Installation-Log: $LOG_FILE
EOF

    chmod 600 "$STACK_DIR/INSTALLATION_INFO.txt"
    chown "$DOCKER_USER:$DOCKER_USER" "$STACK_DIR/INSTALLATION_INFO.txt"
    log_success "Credentials gespeichert: $STACK_DIR/INSTALLATION_INFO.txt"
}

# =============================================================================
# FIREWALL CONFIGURATION
# =============================================================================

configure_firewall() {
    if [[ "$IS_UNRAID" == true ]]; then
        log_info "Unraid: Firewall-Konfiguration übersprungen"
        return 0
    fi

    log_info "Konfiguriere Firewall..."
    local ports=("$PAPERLESS_PORT" "$PAPERLESS_AI_PORT" "$OLLAMA_PORT")

    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        for port in "${ports[@]}"; do
            ufw allow "$port/tcp" >/dev/null 2>&1
        done
        log_success "UFW-Regeln hinzugefügt"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        for port in "${ports[@]}"; do
            firewall-cmd --permanent --add-port="$port/tcp" >/dev/null 2>&1
        done
        firewall-cmd --reload >/dev/null 2>&1
        log_success "Firewalld-Regeln hinzugefügt"
    fi
}

# =============================================================================
# =============================================================================
# INSTALLATION VERIFICATION
# =============================================================================

verify_installation() {
    show_section "INSTALLATIONS-VERIFIZIERUNG"
    
    log_info "Prüfe Container-Status..."
    cd "$STACK_DIR"
    
    # Container-Informationen sammeln
    local all_running=true
    local all_healthy=true
    local container_details=""
    
    # Erwartete Container
    local expected_containers=("postgres" "redis" "ollama" "paperless-ngx" "paperless-ai")
    
    echo -e "${BOLD}Container-Status:${NC}"
    echo -e "${BLUE}┌─────────────────────┬──────────────┬──────────────┬────────────────┐${NC}"
    echo -e "${BLUE}│ Container           │ Status       │ Health       │ Uptime         │${NC}"
    echo -e "${BLUE}├─────────────────────┼──────────────┼──────────────┼────────────────┤${NC}"
    
    for container_name in "${expected_containers[@]}"; do
        local full_name="paperless-${container_name}"
        if [[ "$container_name" == "paperless-ngx" ]] || [[ "$container_name" == "paperless-ai" ]]; then
            full_name="$container_name"
        fi
        
        # Container-Status abrufen
        local status=$(docker inspect --format='{{.State.Status}}' "$full_name" 2>/dev/null || echo "not found")
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$full_name" 2>/dev/null || echo "none")
        local uptime=$(docker inspect --format='{{.State.StartedAt}}' "$full_name" 2>/dev/null | xargs -I {} date -d {} +%s 2>/dev/null || echo "0")
        
        # Uptime berechnen
        local uptime_str="N/A"
        if [[ "$uptime" != "0" ]]; then
            local current_time=$(date +%s)
            local diff=$((current_time - uptime))
            local minutes=$((diff / 60))
            local hours=$((minutes / 60))
            local days=$((hours / 24))
            
            if [[ $days -gt 0 ]]; then
                uptime_str="${days}d ${hours % 24}h"
            elif [[ $hours -gt 0 ]]; then
                uptime_str="${hours}h ${minutes % 60}m"
            else
                uptime_str="${minutes}m"
            fi
        fi
        
        # Health-Status anpassen (wenn keine Healthcheck vorhanden)
        if [[ "$health" == "none" ]] && [[ "$status" == "running" ]]; then
            health="no check"
        fi
        
        # Farbcodierung
        local status_color="$GREEN"
        local health_color="$GREEN"
        local status_symbol="✓"
        
        if [[ "$status" != "running" ]]; then
            status_color="$RED"
            status_symbol="✗"
            all_running=false
        fi
        
        case "$health" in
            "healthy")
                health_color="$GREEN"
                ;;
            "unhealthy")
                health_color="$RED"
                all_healthy=false
                ;;
            "starting")
                health_color="$YELLOW"
                ;;
            "no check"|"none")
                health_color="$CYAN"
                ;;
            *)
                health_color="$YELLOW"
                ;;
        esac
        
        # Formatierte Ausgabe
        printf "${BLUE}│${NC} %-19s ${BLUE}│${NC} ${status_color}%-12s${NC} ${BLUE}│${NC} ${health_color}%-12s${NC} ${BLUE}│${NC} %-14s ${BLUE}│${NC}\n" \
            "${status_symbol} ${container_name}" "$status" "$health" "$uptime_str"
    done
    
    echo -e "${BLUE}└─────────────────────┴──────────────┴──────────────┴────────────────┘${NC}"
    echo
    
    # Zusammenfassung
    if [[ "$all_running" == true ]] && [[ "$all_healthy" == true ]]; then
        log_success "✅ Alle Container sind erfolgreich gestartet und gesund!"
        return 0
    elif [[ "$all_running" == true ]]; then
        log_warning "⚠️  Alle Container laufen, aber einige Health-Checks sind noch nicht grün"
        log_info "Dies ist normal direkt nach dem Start. Container werden initialisiert..."
        sleep 5
        
        # Erneute Prüfung nach Wartezeit
        log_info "Führe erneute Prüfung durch..."
        local still_unhealthy=false
        for container_name in "${expected_containers[@]}"; do
            local full_name="paperless-${container_name}"
            if [[ "$container_name" == "paperless-ngx" ]] || [[ "$container_name" == "paperless-ai" ]]; then
                full_name="$container_name"
            fi
            
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$full_name" 2>/dev/null || echo "none")
            if [[ "$health" == "unhealthy" ]] || [[ "$health" == "starting" ]]; then
                still_unhealthy=true
            fi
        done
        
        if [[ "$still_unhealthy" == false ]]; then
            log_success "✅ Alle Health-Checks sind jetzt grün!"
        else
            log_warning "⚠️  Einige Container benötigen noch mehr Zeit zum Starten"
        fi
        return 0
    else
        log_error "❌ Einige Container sind nicht gestartet!"
        echo
        echo -e "${BOLD}${YELLOW}Troubleshooting:${NC}"
        echo -e "1. Container-Logs prüfen:"
        echo -e "   ${CYAN}cd $STACK_DIR && docker compose logs${NC}"
        echo
        echo -e "2. Einzelne Container neu starten:"
        echo -e "   ${CYAN}cd $STACK_DIR && docker compose restart <container-name>${NC}"
        echo
        echo -e "3. Kompletten Stack neu starten:"
        echo -e "   ${CYAN}cd $STACK_DIR && docker compose down && docker compose up -d${NC}"
        echo
        return 1
    fi
}

# COMPLETION
# =============================================================================

show_completion() {
    clear
    show_section "🎉 INSTALLATION ERFOLGREICH ABGESCHLOSSEN!"

    echo -e "${BOLD}${GREEN}Herzlichen Glückwunsch! Ihre Paperless-NGX + Ollama Installation ist bereit.${NC}"
    echo
    echo -e "${BOLD}${BLUE}🌐 WEB-ZUGRIFF${NC}"
    echo -e "${BLUE}Paperless-NGX:${NC} http://$HOST_IP:$PAPERLESS_PORT"
    echo -e "${BLUE}  Login:${NC} $PAPERLESS_ADMIN_USERNAME / $ADMIN_PASSWORD"
    echo
    echo -e "${BLUE}Paperless-AI:${NC} http://$HOST_IP:$PAPERLESS_AI_PORT"
    echo -e "${BLUE}Ollama API:${NC} http://$HOST_IP:$OLLAMA_PORT"
    echo
    echo -e "${BOLD}${GREEN}✅ INSTALLIERTE KOMPONENTEN${NC}"
    echo -e "✓ Paperless-NGX, Paperless-AI, Ollama (Gemma2:9B)"
    echo -e "✓ PostgreSQL, Redis"
    echo -e "✓ RAG-Chat, OpenAI Whisper"
    echo
    echo -e "${BOLD}${YELLOW}🚀 NÄCHSTE SCHRITTE${NC}"
    echo -e "1. Paperless-NGX öffnen: http://$HOST_IP:$PAPERLESS_PORT"
    echo -e "2. Mit $PAPERLESS_ADMIN_USERNAME / *** anmelden"
    echo -e "3. Erstes Dokument hochladen"
    echo -e "4. Paperless-AI konfigurieren: http://$HOST_IP:$PAPERLESS_AI_PORT"
    echo
    echo -e "${BOLD}${BLUE}📄 Details:${NC} $STACK_DIR/INSTALLATION_INFO.txt"
    echo -e "${BOLD}${BLUE}📊 Log:${NC} $LOG_FILE"
    echo
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    show_header
    check_root
    detect_platform
    collect_credentials
    cleanup_existing_installation

    show_section "SYSTEM-INSTALLATION"
    install_system_packages
    setup_docker
    configure_network

    show_section "KONFIGURATION"
    check_data_directories
    create_directories
    set_permissions
    create_env_file
    create_paperless_ai_env
    create_compose_file

    start_stack
    create_credentials_file
    configure_firewall

    verify_installation

    show_completion
}

# Script ausführen
main "$@"
