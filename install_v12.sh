#!/bin/bash

# Paperless-NGX + Ollama AI Stack Installation Script
# Version 12.0 - Ollama Integration (FBW) Stand: 25.11.2025
# Docker-Installation mit Ollama, Gemma2:9B, Whisper und RAG-Chat

set -e

# =============================================================================
# CONFIGURATION VARIABLES
# =============================================================================

STACK_DIR="/opt/paperless-stack"
PAPERLESS_DATA_DIR="/mnt/user/dokumente/paperless"
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
    echo "║                      + OLLAMA AI STACK - Version 12.0                         ║"
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
    show_section "BESTEHENDE INSTALLATION PRÜFEN"

    local existing_found=false

    if command -v docker >/dev/null 2>&1; then
        if docker ps -a --filter "name=paperless" -q 2>/dev/null | grep -q .; then
            existing_found=true
        fi
    fi

    if [[ -d "$STACK_DIR" ]]; then
        existing_found=true
    fi

    if [[ "$existing_found" == "true" ]]; then
        echo -e "${YELLOW}Bestehende Installation gefunden.${NC}"
        echo -n "➤ Komplett bereinigen? [j/N]: "
        read -r cleanup_choice

        if [[ "$cleanup_choice" =~ ^[jJyY]$ ]]; then
            log_info "Bereinige bestehende Installation..."

            if command -v docker >/dev/null 2>&1; then
                docker ps -a --filter "name=paperless" -q 2>/dev/null | xargs -r docker rm -f >/dev/null 2>&1 || true
                docker ps -a --filter "name=ollama" -q 2>/dev/null | xargs -r docker rm -f >/dev/null 2>&1 || true
                docker images --filter "reference=*paperless*" -q 2>/dev/null | xargs -r docker rmi -f >/dev/null 2>&1 || true
                docker images --filter "reference=*ollama*" -q 2>/dev/null | xargs -r docker rmi -f >/dev/null 2>&1 || true
                docker volume ls --filter "name=paperless" -q 2>/dev/null | xargs -r docker volume rm -f >/dev/null 2>&1 || true
                docker volume ls --filter "name=ollama" -q 2>/dev/null | xargs -r docker volume rm -f >/dev/null 2>&1 || true
                docker network ls --filter "name=paperless" -q 2>/dev/null | xargs -r docker network rm >/dev/null 2>&1 || true
                log_info "✓ Docker Container und Volumes entfernt"
            fi

            if [[ -d "$STACK_DIR" ]]; then
                rm -rf "$STACK_DIR"
                log_info "✓ Installationsverzeichnis entfernt: $STACK_DIR"
            fi

            if command -v docker >/dev/null 2>&1; then
                docker system prune -f >/dev/null 2>&1 || true
                log_info "✓ Docker System bereinigt"
            fi

            log_success "✓ Bereinigung abgeschlossen"
        fi
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

install_system_packages() {
    log_info "Installiere System-Pakete..."

    local pm=$(detect_package_manager)

    case $pm in
        apt)
            apt update -qq
            apt install -y curl wget openssl ca-certificates gnupg mc nano htop net-tools lsb-release jq apache2-utils python3 python3-requests

            apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
            install -m 0755 -d /etc/apt/keyrings
            rm -f /etc/apt/keyrings/docker.gpg
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt update -qq
            apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        yum|dnf)
            $pm install -y curl wget openssl ca-certificates gnupg mc nano htop net-tools jq httpd-tools python3 python3-requests
            $pm config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            $pm install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
    esac

    log_success "System-Pakete installiert"
}

setup_docker() {
    log_info "Konfiguriere Docker..."

    systemctl enable docker
    systemctl start docker

    if ! groups "$DOCKER_USER" | grep -q docker; then
        usermod -aG docker "$DOCKER_USER"
        log_success "User '$DOCKER_USER' zur docker-Gruppe hinzugefügt"
    fi

    if ! docker info >/dev/null 2>&1; then
        log_error "Docker läuft nicht korrekt!"
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
    while netstat -tuln 2>/dev/null | grep -q ":$PAPERLESS_PORT "; do
        PAPERLESS_PORT=$((PAPERLESS_PORT + 1))
    done

    PAPERLESS_AI_PORT=3000
    while netstat -tuln 2>/dev/null | grep -q ":$PAPERLESS_AI_PORT "; do
        PAPERLESS_AI_PORT=$((PAPERLESS_AI_PORT + 1))
    done

    OLLAMA_PORT=11434
    while netstat -tuln 2>/dev/null | grep -q ":$OLLAMA_PORT "; do
        OLLAMA_PORT=$((OLLAMA_PORT + 1))
    done

    POSTGRES_PORT=5432
    while netstat -tuln 2>/dev/null | grep -q ":$POSTGRES_PORT "; do
        POSTGRES_PORT=$((POSTGRES_PORT + 1))
    done

    REDIS_PORT=6379
    while netstat -tuln 2>/dev/null | grep -q ":$REDIS_PORT "; do
        REDIS_PORT=$((REDIS_PORT + 1))
    done

    log_success "Netzwerk konfiguriert: IP=$HOST_IP"
}

# =============================================================================
# DIRECTORY AND FILE CREATION
# =============================================================================

check_data_directories() {
    show_section "DATENVERZEICHNIS PRÜFEN"

    log_info "Prüfe Paperless-Datenverzeichnis: $PAPERLESS_DATA_DIR"

    if [[ ! -d "$PAPERLESS_DATA_DIR" ]]; then
        log_error "Datenverzeichnis existiert nicht: $PAPERLESS_DATA_DIR"
        echo -e "${RED}Das Verzeichnis $PAPERLESS_DATA_DIR wurde nicht gefunden!${NC}"
        echo -e "${YELLOW}Bitte erstellen Sie das Verzeichnis oder passen Sie PAPERLESS_DATA_DIR im Script an.${NC}"
        exit 1
    fi

    if [[ ! -w "$PAPERLESS_DATA_DIR" ]]; then
        log_error "Datenverzeichnis ist nicht beschreibbar: $PAPERLESS_DATA_DIR"
        exit 1
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

    cat > "$STACK_DIR/docker-compose.yml" << 'EOF'
services:
  postgres:
    image: postgres:15-alpine
    container_name: paperless-postgres
    restart: ${RESTART_POLICY}
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    ports:
      - "${POSTGRES_PORT}:5432"
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
    restart: ${RESTART_POLICY}
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - ./data/redis:/data
    ports:
      - "${REDIS_PORT}:6379"
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
    restart: ${RESTART_POLICY}
    volumes:
      - ./data/ollama:/root/.ollama
    ports:
      - "${OLLAMA_PORT}:11434"
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
    restart: ${RESTART_POLICY}
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      PAPERLESS_DBENGINE: postgresql
      PAPERLESS_DBHOST: postgres
      PAPERLESS_DBPORT: 5432
      PAPERLESS_DBNAME: ${POSTGRES_DB}
      PAPERLESS_DBUSER: ${POSTGRES_USER}
      PAPERLESS_DBPASS: ${POSTGRES_PASSWORD}
      PAPERLESS_REDIS: redis://:${REDIS_PASSWORD}@redis:6379
      PAPERLESS_SECRET_KEY: ${PAPERLESS_SECRET_KEY}
      PAPERLESS_URL: ${PAPERLESS_URL}
      PAPERLESS_CSRF_TRUSTED_ORIGINS: ${PAPERLESS_CSRF_TRUSTED_ORIGINS}
      PAPERLESS_ALLOWED_HOSTS: ${PAPERLESS_ALLOWED_HOSTS}
      PAPERLESS_TIME_ZONE: ${PAPERLESS_TIME_ZONE}
      PAPERLESS_ADMIN_USER: ${PAPERLESS_ADMIN_USER}
      PAPERLESS_ADMIN_PASSWORD: ${PAPERLESS_ADMIN_PASSWORD}
      PAPERLESS_OCR_LANGUAGE: ${PAPERLESS_OCR_LANGUAGE}
      PAPERLESS_OCR_MODE: ${PAPERLESS_OCR_MODE}
      PAPERLESS_OCR_CLEAN: ${PAPERLESS_OCR_CLEAN}
      PAPERLESS_OCR_OUTPUT_TYPE: ${PAPERLESS_OCR_OUTPUT_TYPE}
      PAPERLESS_OCR_ROTATE_PAGES: ${PAPERLESS_OCR_ROTATE_PAGES}
      PAPERLESS_OCR_ROTATE_PAGES_THRESHOLD: ${PAPERLESS_OCR_ROTATE_PAGES_THRESHOLD}
      PAPERLESS_OCR_DESKEW: ${PAPERLESS_OCR_DESKEW}
      PAPERLESS_CONSUMER_INBOX_TAG: ${PAPERLESS_CONSUMER_INBOX_TAG}
      PAPERLESS_CONSUMER_RECURSIVE: "true"
      PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS: "false"
    volumes:
      - /mnt/user/dokumente/paperless/data:/usr/src/paperless/data
      - /mnt/user/dokumente/paperless/media:/usr/src/paperless/media
      - /mnt/user/dokumente/paperless/export:/usr/src/paperless/export
      - /mnt/user/dokumente/paperless/consume:/usr/src/paperless/consume
    ports:
      - "${PAPERLESS_PORT}:8000"
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
    restart: ${RESTART_POLICY}
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
      - "${PAPERLESS_AI_PORT}:3000"
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

# =============================================================================
# DOCKER STACK DEPLOYMENT
# =============================================================================

start_stack() {
    show_section "DOCKER STACK DEPLOYMENT"

    log_info "Starte Docker Stack..."
    cd "$STACK_DIR"

    log_info "Starte PostgreSQL und Redis Container..."
    sudo -u "$DOCKER_USER" docker compose up -d postgres redis
    sleep 20

    log_info "Starte Ollama Container..."
    sudo -u "$DOCKER_USER" docker compose up -d ollama
    sleep 30

    log_info "Lade Gemma2:9B Modell herunter (ca. 5GB, kann einige Minuten dauern)..."
    if ! sudo -u "$DOCKER_USER" docker exec paperless-ollama ollama pull gemma2:9b; then
        log_warning "Gemma2:9B Download fehlgeschlagen - wird beim ersten Start nachgeholt"
    else
        log_success "✓ Gemma2:9B Modell erfolgreich geladen"
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

    local max_attempts=10
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        log_info "Prüfe Container-Bereitschaft (Versuch $attempt/$max_attempts)..."

        if curl -s -f "http://$HOST_IP:$PAPERLESS_PORT/accounts/login/" >/dev/null 2>&1; then
            log_success "Container ist bereit"
            break
        fi

        if [[ $attempt -eq $max_attempts ]]; then
            log_error "Container ist nach $max_attempts Versuchen nicht bereit!"
            return 1
        fi

        sleep 10
        ((attempt++))
    done

    log_info "Erstelle Standard-Tags..."

    if create_tag_via_management "Neu" "#42cd38" "true"; then
        log_success "✓ Tag 'Neu' als Inbox-Tag erstellt"
    else
        log_warning "⚠ Tag 'Neu' konnte nicht erstellt werden"
    fi

    if create_tag_via_management "RAG" "#b82fbc" "false"; then
        log_success "✓ Tag 'RAG' erstellt"
    else
        log_warning "⚠ Tag 'RAG' konnte nicht erstellt werden"
    fi

    if create_document_type "Dokumente"; then
        log_success "✓ Dokumententyp 'Dokumente' erstellt"
    else
        log_warning "⚠ Dokumententyp konnte nicht erstellt werden"
    fi

    if create_correspondent "Diverse"; then
        log_success "✓ Korrespondent 'Diverse' erstellt"
    else
        log_warning "⚠ Korrespondent konnte nicht erstellt werden"
    fi

    log_success "Standard-Setup abgeschlossen"

    verify_created_tags
    setup_inbox_tag

    return 0
}

verify_created_tags() {
    log_info "Verifiziere erstellte Tags..."

    local verify_command="
from documents.models import Tag
try:
    tags = Tag.objects.all()
    print('TAGS_FOUND:')
    for tag in tags:
        inbox_status = 'INBOX' if hasattr(tag, 'is_inbox_tag') and tag.is_inbox_tag else 'NORMAL'
        print(f'  - {tag.name} (ID: {tag.id}, Color: {tag.color}, Status: {inbox_status})')
    print('END_TAGS')

    inbox_tags = Tag.objects.filter(is_inbox_tag=True)
    if inbox_tags.exists():
        print('INBOX_TAGS_FOUND:')
        for tag in inbox_tags:
            print(f'  - INBOX_TAG: {tag.name} (ID: {tag.id})')
    else:
        print('NO_INBOX_TAGS_FOUND')
except Exception as e:
    print(f'ERROR: {str(e)}')
"

    local result
    if result=$(cd "$STACK_DIR" && echo "$verify_command" | sudo -u "$DOCKER_USER" docker compose exec -T paperless-ngx python manage.py shell 2>&1); then
        log_info "Verifizierung erfolgreich:"

        echo "$result" | grep -A 20 "TAGS_FOUND:" | grep -B 20 "END_TAGS" | grep "  -" | while read -r line; do
            if echo "$line" | grep -q "INBOX"; then
                log_success "$line"
            else
                log_info "$line"
            fi
        done

        if echo "$result" | grep -q "INBOX_TAGS_FOUND:"; then
            log_success "✓ Inbox-Tags gefunden:"
            echo "$result" | grep -A 10 "INBOX_TAGS_FOUND:" | grep "INBOX_TAG:" | while read -r line; do
                log_success "  $line"
            done
        else
            log_error "❌ Keine Inbox-Tags gefunden!"
        fi
    else
        log_warning "Tag-Verifizierung fehlgeschlagen: $result"
    fi
}

create_tag_via_management() {
    local tag_name="$1"
    local tag_color="$2"
    local is_inbox_tag="$3"

    log_info "Erstelle Tag '$tag_name' mit Farbe $tag_color..."

    local create_command="
from documents.models import Tag
import sys

try:
    tag, created = Tag.objects.get_or_create(
        name='$tag_name',
        defaults={
            'color': '$tag_color',
            'match': '',
            'matching_algorithm': 0,
            'is_inbox_tag': $(if [[ "$is_inbox_tag" == "true" ]]; then echo "True"; else echo "False"; fi)
        }
    )

    if not created and '$is_inbox_tag' == 'true':
        tag.is_inbox_tag = True
        tag.save()
        print('UPDATED_INBOX_STATUS')

    if created:
        print('CREATED:$tag_name')
    else:
        print('EXISTS:$tag_name')

    if hasattr(tag, 'is_inbox_tag') and tag.is_inbox_tag:
        print('INBOX_TAG_CONFIRMED')

    print('SUCCESS')
except Exception as e:
    print(f'ERROR: {str(e)}')
    import traceback
    traceback.print_exc()
    sys.exit(1)
"

    local result
    if result=$(cd "$STACK_DIR" && echo "$create_command" | sudo -u "$DOCKER_USER" docker compose exec -T paperless-ngx python manage.py shell 2>&1); then
        if echo "$result" | grep -q "SUCCESS"; then
            log_info "Tag-Erstellung erfolgreich: $result"

            if [[ "$is_inbox_tag" == "true" ]]; then
                if echo "$result" | grep -q "INBOX_TAG_CONFIRMED"; then
                    log_success "✓ Tag '$tag_name' als Inbox-Tag konfiguriert"
                else
                    log_warning "⚠ Tag '$tag_name' erstellt, aber Inbox-Status unsicher"
                fi
            fi

            return 0
        else
            log_error "Tag-Erstellung fehlgeschlagen: $result"
            return 1
        fi
    else
        log_error "Management Command fehlgeschlagen: $result"
        return 1
    fi
}

create_document_type() {
    local type_name="$1"

    log_info "Erstelle Dokumententyp '$type_name'..."

    local create_command="
from documents.models import DocumentType
try:
    doc_type, created = DocumentType.objects.get_or_create(
        name='$type_name',
        defaults={'match': '', 'matching_algorithm': 0}
    )
    print('SUCCESS')
except Exception as e:
    print(f'ERROR: {str(e)}')
"

    local result
    if result=$(cd "$STACK_DIR" && echo "$create_command" | sudo -u "$DOCKER_USER" docker compose exec -T paperless-ngx python manage.py shell 2>&1); then
        if echo "$result" | grep -q "SUCCESS"; then
            return 0
        else
            log_error "Dokumententyp-Erstellung fehlgeschlagen: $result"
            return 1
        fi
    else
        return 1
    fi
}

create_correspondent() {
    local correspondent_name="$1"

    log_info "Erstelle Korrespondent '$correspondent_name'..."

    local create_command="
from documents.models import Correspondent
try:
    correspondent, created = Correspondent.objects.get_or_create(
        name='$correspondent_name',
        defaults={'match': '', 'matching_algorithm': 0}
    )
    print('SUCCESS')
except Exception as e:
    print(f'ERROR: {str(e)}')
"

    local result
    if result=$(cd "$STACK_DIR" && echo "$create_command" | sudo -u "$DOCKER_USER" docker compose exec -T paperless-ngx python manage.py shell 2>&1); then
        if echo "$result" | grep -q "SUCCESS"; then
            return 0
        else
            log_error "Korrespondent-Erstellung fehlgeschlagen: $result"
            return 1
        fi
    else
        return 1
    fi
}

setup_inbox_tag() {
    log_info "Konfiguriere Posteingangs-Tag..."

    sleep 10

    local inbox_script="
from documents.models import Tag
try:
    neu_tag = Tag.objects.get(name='Neu')
    tag_id = neu_tag.id
    print(f'TAG_ID_FOUND:{tag_id}')
except Exception as e:
    print(f'ERROR:{str(e)}')
    tag_id = 1
    print('TAG_ID_FALLBACK:1')
"

    local tag_id_result
    if tag_id_result=$(cd "$STACK_DIR" && echo "$inbox_script" | sudo -u "$DOCKER_USER" docker compose exec -T paperless-ngx python manage.py shell 2>&1); then
        local found_tag_id
        if echo "$tag_id_result" | grep -q "TAG_ID_FOUND:"; then
            found_tag_id=$(echo "$tag_id_result" | grep "TAG_ID_FOUND:" | cut -d':' -f2)
        else
            found_tag_id="1"
        fi

        log_info "Verwende Tag-ID: $found_tag_id für Inbox-Tag"

        if [[ -f "$STACK_DIR/.env" ]]; then
            if grep -q "^PAPERLESS_CONSUMER_INBOX_TAG=" "$STACK_DIR/.env"; then
                sed -i "s/^PAPERLESS_CONSUMER_INBOX_TAG=.*/PAPERLESS_CONSUMER_INBOX_TAG=$found_tag_id/" "$STACK_DIR/.env"
            else
                echo "" >> "$STACK_DIR/.env"
                echo "PAPERLESS_CONSUMER_INBOX_TAG=$found_tag_id" >> "$STACK_DIR/.env"
            fi

            log_success "✓ Posteingangs-Tag konfiguriert (Tag-ID: $found_tag_id)"

            if sudo -u "$DOCKER_USER" docker compose restart paperless-ngx; then
                log_success "✓ Paperless-NGX mit neuer Tag-Konfiguration neugestartet"
                sleep 20
            else
                log_warning "⚠ Neustart von Paperless-NGX fehlgeschlagen"
            fi
        fi
    else
        log_error "Tag-ID Ermittlung fehlgeschlagen"
    fi
}

update_paperless_ai_tag_config() {
    log_info "Aktualisiere Paperless-AI Tag-Konfiguration..."

    sleep 20

    local max_tag_attempts=5
    local tag_attempt=1
    local tags_found=false

    while [[ $tag_attempt -le $max_tag_attempts ]]; do
        log_info "Prüfe Tag-Verfügbarkeit (Versuch $tag_attempt/$max_tag_attempts)..."

        local tag_query="
from documents.models import Tag
try:
    neu_tag = Tag.objects.get(name='Neu')
    print(f'NEU_TAG_ID:{neu_tag.id}')

    if Tag.objects.filter(name='RAG').exists():
        rag_tag = Tag.objects.get(name='RAG')
        print(f'RAG_TAG_ID:{rag_tag.id}')
    else:
        print('RAG_TAG_ID:NONE')

    print('TAGS_SUCCESS')
except Exception as e:
    print(f'ERROR:{str(e)}')
"

        local tag_result
        if tag_result=$(cd "$STACK_DIR" && echo "$tag_query" | sudo -u "$DOCKER_USER" docker compose exec -T paperless-ngx python manage.py shell 2>&1); then
            if echo "$tag_result" | grep -q "TAGS_SUCCESS"; then
                tags_found=true
                break
            else
                log_warning "Tags noch nicht verfügbar: $tag_result"
            fi
        else
            log_warning "Tag-Abfrage fehlgeschlagen (Versuch $tag_attempt): $tag_result"
        fi

        if [[ $tag_attempt -eq $max_tag_attempts ]]; then
            log_error "Tags sind nach $max_tag_attempts Versuchen nicht verfügbar!"
            log_warning "Paperless-AI wird mit Standard-Konfiguration weiterlaufen"
            return 1
        fi

        sleep 15
        ((tag_attempt++))
    done

    if [[ "$tags_found" == "true" ]]; then
        local neu_tag_id=$(echo "$tag_result" | grep "NEU_TAG_ID:" | cut -d':' -f2)
        local rag_tag_id=$(echo "$tag_result" | grep "RAG_TAG_ID:" | cut -d':' -f2)

        if [[ -n "$neu_tag_id" && "$neu_tag_id" != "" ]]; then
            log_info "Gefundene Tag-IDs: Neu=$neu_tag_id, RAG=$rag_tag_id"

            local ai_env_file="$STACK_DIR/config/paperless-ai/.env"
            if [[ -f "$ai_env_file" ]]; then
                sed -i "s/INBOX_TAG_ID=.*/INBOX_TAG_ID=$neu_tag_id/" "$ai_env_file" 2>/dev/null || true
                sed -i "s/TARGET_TAG_ID=.*/TARGET_TAG_ID=$neu_tag_id/" "$ai_env_file" 2>/dev/null || true
                sed -i "s/PROCESS_TAG_ID=.*/PROCESS_TAG_ID=$neu_tag_id/" "$ai_env_file" 2>/dev/null || true
                sed -i "s/TAGS=.*/TAGS=Neu/" "$ai_env_file"
                sed -i "s/TAG_NAMES=.*/TAG_NAMES=Neu/" "$ai_env_file" 2>/dev/null || true
                sed -i "s/SPECIFIC_TAGS=.*/SPECIFIC_TAGS=Neu/" "$ai_env_file"
                sed -i "s/PREDEFINED_TAGS=.*/PREDEFINED_TAGS=Neu/" "$ai_env_file"
                sed -i "s/TARGET_TAGS=.*/TARGET_TAGS=Neu/" "$ai_env_file"

                if [[ "$rag_tag_id" != "NONE" && -n "$rag_tag_id" ]]; then
                    sed -i "s/RAG_SPECIFIC_TAGS=.*/RAG_SPECIFIC_TAGS=RAG/" "$ai_env_file"
                    log_info "✓ RAG-Chat konfiguriert für Tag 'RAG' (ID: $rag_tag_id)"
                fi

                log_success "✓ Paperless-AI Tag-Konfiguration aktualisiert"

                log_info "Starte Paperless-AI Container neu..."
                sudo -u "$DOCKER_USER" docker compose restart paperless-ai
                sleep 20

                log_success "✓ Paperless-AI mit aktualisierter Konfiguration neugestartet"
            else
                log_error "Paperless-AI .env Datei nicht gefunden: $ai_env_file"
            fi
        else
            log_error "Konnte Tag-IDs nicht ermitteln: $tag_result"
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

================================================================================
WEB-ZUGRIFF
================================================================================
Paperless-NGX:    http://$HOST_IP:$PAPERLESS_PORT
  Benutzername:    $PAPERLESS_ADMIN_USERNAME
  Passwort:        $ADMIN_PASSWORD

Paperless-AI:     http://$HOST_IP:$PAPERLESS_AI_PORT
  Setup-Assistent beim ersten Besuch verwenden

Ollama API:       http://$HOST_IP:$OLLAMA_PORT
  Modell:          gemma2:9b
  API Endpoint:    http://$HOST_IP:$OLLAMA_PORT/v1

================================================================================
DATENBANK-ZUGRIFF
================================================================================
PostgreSQL:       $HOST_IP:$POSTGRES_PORT
  Datenbank:       paperless
  Benutzername:    paperless
  Passwort:        $DB_PASSWORD

Redis:            $HOST_IP:$REDIS_PORT
  Passwort:        $REDIS_PASSWORD

================================================================================
INSTALLIERTE FEATURES
================================================================================
✓ Paperless-NGX (Dokumentenverwaltung)
✓ PostgreSQL + Redis (Datenbank)
✓ Paperless-AI (KI-Analyse mit Ollama)
✓ Ollama (Lokale KI-Engine mit Gemma2:9B)
✓ RAG-Chat (Dokumenten-Chat mit Ollama)
✓ OpenAI Whisper (Spracherkennung)

================================================================================
MANAGEMENT
================================================================================
Installation:     $STACK_DIR
Datenverzeichnis: $PAPERLESS_DATA_DIR
Container Status: cd $STACK_DIR && docker compose ps
Logs anzeigen:    cd $STACK_DIR && docker compose logs
Container starten: cd $STACK_DIR && docker compose up -d
Container stoppen: cd $STACK_DIR && docker compose down

Ollama Modelle:
  Liste:          docker exec paperless-ollama ollama list
  Pull:           docker exec paperless-ollama ollama pull <model>
  Run:            docker exec paperless-ollama ollama run <model>

================================================================================
WICHTIGE HINWEISE
================================================================================
• Paperless-AI: Beim ersten Besuch den Setup-Assistenten durchlaufen
• API-Token wurde automatisch erstellt und konfiguriert
• Ollama verwendet Gemma2:9B für alle KI-Anfragen (lokal, keine API-Keys nötig)
• RAG-Chat: Markieren Sie Dokumente mit "RAG"-Tag für interaktive Chats
• Das "Neu"-Tag wird automatisch für neue Dokumente gesetzt
• OpenAI Whisper ist in Paperless-AI integriert für Audio-Transkription
• Posteingangs-Tag: Neue Dokumente erhalten automatisch das Tag "Neu"
• Bei Problemen: Container-Logs prüfen (docker compose logs)

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
    log_info "Konfiguriere Firewall..."

    local ports=("$PAPERLESS_PORT" "$PAPERLESS_AI_PORT" "$OLLAMA_PORT" "$POSTGRES_PORT" "$REDIS_PORT")

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
    else
        log_info "Keine Firewall gefunden oder nicht aktiv"
    fi
}

# =============================================================================
# COMPLETION
# =============================================================================

show_completion() {
    clear
    show_section "🎉 INSTALLATION ERFOLGREICH ABGESCHLOSSEN!"

    echo -e "${BOLD}${GREEN}Herzlichen Glückwunsch! Ihre Paperless-NGX + Ollama Installation ist bereit.${NC}"
    echo

    echo -e "${BOLD}${BLUE}🌐 WEB-ZUGRIFF${NC}"
    echo -e "${BLUE}╭─────────────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${BLUE}│${NC} ${BOLD}Paperless-NGX:${NC} ${BLUE}http://$HOST_IP:$PAPERLESS_PORT${NC}"
    echo -e "${BLUE}│${NC} ${BOLD}Benutzername:${NC}  ${GREEN}$PAPERLESS_ADMIN_USERNAME${NC}"
    echo -e "${BLUE}│${NC} ${BOLD}Passwort:${NC}      ${GREEN}$ADMIN_PASSWORD${NC}"
    echo -e "${BLUE}│${NC}"
    echo -e "${BLUE}│${NC} ${BOLD}Paperless-AI:${NC}  ${BLUE}http://$HOST_IP:$PAPERLESS_AI_PORT${NC}"
    echo -e "${BLUE}│${NC} ${BOLD}KI-Engine:${NC}     ${GREEN}Ollama mit Gemma2:9B${NC}"
    echo -e "${BLUE}│${NC} ${BOLD}Setup:${NC}         Setup-Assistent beim ersten Besuch verwenden"
    echo -e "${BLUE}│${NC}"
    echo -e "${BLUE}│${NC} ${BOLD}Ollama API:${NC}    ${BLUE}http://$HOST_IP:$OLLAMA_PORT${NC}"
    echo -e "${BLUE}│${NC} ${BOLD}Modell:${NC}        ${GREEN}gemma2:9b (lokal)${NC}"
    echo -e "${BLUE}╰─────────────────────────────────────────────────────────────────────────────────╯${NC}"
    echo

    echo -e "${BOLD}${GREEN}✅ INSTALLIERTE FEATURES${NC}"
    echo -e "${GREEN}╭─────────────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${GREEN}│${NC} ✓ Paperless-NGX (Dokumentenverwaltung)"
    echo -e "${GREEN}│${NC} ✓ PostgreSQL + Redis (Datenbank)"
    echo -e "${GREEN}│${NC} ✓ Paperless-AI (KI-Analyse mit Ollama)"
    echo -e "${GREEN}│${NC} ✓ Ollama (Lokale KI-Engine mit Gemma2:9B)"
    echo -e "${GREEN}│${NC} ✓ RAG-Chat (Dokumenten-Chat mit Ollama)"
    echo -e "${GREEN}│${NC} ✓ OpenAI Whisper (Spracherkennung integriert)"
    echo -e "${GREEN}│${NC}   → Standard AI: \"Neu\"-Tag (automatisch)"
    echo -e "${GREEN}│${NC}   → RAG-Chat: \"RAG\"-Tag (manuell)"
    echo -e "${GREEN}╰─────────────────────────────────────────────────────────────────────────────────╯${NC}"
    echo

    echo -e "${BOLD}${YELLOW}🚀 NÄCHSTE SCHRITTE${NC}"
    echo -e "${YELLOW}1.${NC} Öffnen Sie Paperless-NGX: ${BLUE}http://$HOST_IP:$PAPERLESS_PORT${NC}"
    echo -e "${YELLOW}2.${NC} Melden Sie sich an: ${GREEN}$PAPERLESS_ADMIN_USERNAME${NC} / ${GREEN}$ADMIN_PASSWORD${NC}"
    echo -e "${YELLOW}3.${NC} Laden Sie Ihr erstes Dokument hoch (erhält automatisch Tag \"Neu\")"
    echo -e "${YELLOW}4.${NC} Konfigurieren Sie Paperless-AI: ${BLUE}http://$HOST_IP:$PAPERLESS_AI_PORT${NC}"
    echo -e "    ${CYAN}→ KI-Engine: Ollama mit Gemma2:9B (lokal, keine API-Keys nötig)${NC}"
    echo -e "${YELLOW}5.${NC} Für RAG-Chat: Markieren Sie Dokumente zusätzlich mit \"RAG\"-Tag"
    echo
    echo -e "${BOLD}${BLUE}📄 Vollständige Zugangsdaten:${NC} ${YELLOW}$STACK_DIR/INSTALLATION_INFO.txt${NC}"
    echo -e "${BOLD}${BLUE}📊 Installation-Log:${NC} ${YELLOW}$LOG_FILE${NC}"
    echo
    echo -e "${BOLD}${GREEN}🎯 Installation erfolgreich abgeschlossen!${NC}"
    echo -e "${GREEN}Viel Erfolg mit Ihrer Paperless-NGX + Ollama Installation!${NC}"
    echo
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    show_header
    check_root
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

    show_completion
}

# Script ausführen
main "$@"
