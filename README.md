# Paperless-NGX + Ollama AI Stack

Vollautomatisches Installations-Script für eine komplette Dokumentenverwaltungs-Lösung mit lokaler KI-Integration.

**Version 12.1.2** - Multi-Platform (Ubuntu/Unraid)

## 🎯 Features

- **Paperless-NGX** - Moderne Dokumentenverwaltung mit OCR
- **Paperless-AI** - KI-gestützte Dokumentenanalyse und Klassifizierung
- **Ollama** - Lokale KI-Engine (keine Cloud-API erforderlich)
- **Gemma2:9B** - Leistungsstarkes Open-Source Sprachmodell
- **RAG-Chat** - Interaktive Dokumenten-Chats mit KI
- **OpenAI Whisper** - Integrierte Spracherkennung für Audio-Dateien
- **PostgreSQL + Redis** - Robuste Datenbank-Backend
- **🆕 Multi-Platform** - Unterstützung für Ubuntu und Unraid
- **🆕 Automatische Docker-Installation** - Vollständiges Docker-Setup für Ubuntu
- **🆕 Plattform-Erkennung** - Automatische Erkennung der Zielplattform
- **🆕 Flexible Pfadwahl** - Anpassbare Datenverzeichnisse je nach Umgebung

## 📋 Voraussetzungen

### Allgemein
- **RAM**: Mindestens 8GB (16GB empfohlen für Ollama)
- **Festplatte**: Mindestens 20GB freier Speicher
- **CPU**: x64 Prozessor mit mindestens 4 Kernen
- **Root-Zugriff**: Das Script muss als root/sudo ausgeführt werden

### Ubuntu/Debian
- **Betriebssystem**: Ubuntu 20.04+ / Debian 11+ / CentOS 8+ / Rocky Linux 8+
- **Docker**: Wird automatisch installiert, wenn nicht vorhanden
- **Internet**: Für Package-Download und Docker-Installation

### Unraid
- **Unraid Version**: 6.9+
- **Docker**: Muss in Unraid-Einstellungen aktiviert sein
- **Community Applications Plugin**: Empfohlen (aber nicht erforderlich)

## 🚀 Installation

### 1. Script herunterladen

```bash
# Script herunterladen
wget https://raw.githubusercontent.com/KaiserUndGott/Paperless_Ollama_Stack/main/install_v12.sh

# Ausführbar machen
chmod +x install_v12.sh
```

### 2. Installation starten

```bash
sudo ./install_v12.sh
```

Das Script führt Sie interaktiv durch die Installation:

1. **Plattform-Auswahl**: Ubuntu/Debian oder Unraid
2. **Datenverzeichnis**: Auswahl oder Erstellung des Speicherorts
3. **Credentials**: Admin-Benutzername und sicheres Passwort
4. **Docker-Installation**: Automatisch auf Ubuntu (falls nötig)
5. **Stack-Deployment**: Alle Container werden gestartet
6. **Ollama-Model**: Gemma2:9B wird automatisch geladen

### Installation auf Ubuntu (Testing)

Ideal für Tests auf einem "nackten" Ubuntu-Server:

```bash
# Frisches Ubuntu 22.04/24.04 System
sudo ./install_v12.sh

# Das Script wird automatisch installieren:
# - Docker Engine + Docker Compose Plugin
# - Alle erforderlichen System-Pakete
# - Den kompletten Paperless-Stack
```

### Installation auf Unraid (Produktion)

Für den Produktivbetrieb mit Portainer:

```bash
# Auf Unraid Terminal oder SSH
sudo ./install_v12.sh

# Wählen Sie "2" für Unraid-Platform
# Das Script überspringt die Docker-Installation
# und verwendet die bestehende Unraid-Docker-Umgebung
```

**Hinweis**: Das Datenverzeichnis wird je nach Plattform vorgeschlagen:
- **Unraid**: `/mnt/user/dokumente/paperless` (Standard)
- **Ubuntu**: `/var/lib/paperless` oder `/mnt/user/dokumente/paperless` (wählbar)

### 3. Installation überwachen

Die Installation dauert ca. 15-20 Minuten, abhängig von Ihrer Internetverbindung (ca. 5-6GB Download für Ollama + Gemma2:9B).

### 4. Erfolgsverifizierung

Das Script prüft automatisch nach der Installation den Status aller Container:

```
═══════════════════════════════════════════════════════════════════════════════
  INSTALLATIONS-VERIFIZIERUNG
═══════════════════════════════════════════════════════════════════════════════

Container-Status:
┌─────────────────────┬──────────────┬──────────────┬────────────────┐
│ Container           │ Status       │ Health       │ Uptime         │
├─────────────────────┼──────────────┼──────────────┼────────────────┤
│ ✓ postgres          │ running      │ healthy      │ 2m             │
│ ✓ redis             │ running      │ healthy      │ 2m             │
│ ✓ ollama            │ running      │ healthy      │ 1m             │
│ ✓ paperless-ngx     │ running      │ healthy      │ 1m             │
│ ✓ paperless-ai      │ running      │ no check     │ 0m             │
└─────────────────────┴──────────────┴──────────────┴────────────────┘

✅ Alle Container sind erfolgreich gestartet und gesund!
```

**Status-Symbole:**
- ✓ Grün = Container läuft und ist gesund
- ✗ Rot = Container läuft nicht oder ist ungesund
- Gelb = Container startet gerade
- Cyan = Kein Health-Check konfiguriert

Bei Problemen zeigt das Script automatisch Troubleshooting-Hinweise an.

## 🔧 Konfiguration

### Port-Konfiguration

Das Script sucht automatisch nach freien Ports. Standard-Ports:

- **Paperless-NGX**: 8000
- **Paperless-AI**: 3000
- **Ollama API**: 11434
- **PostgreSQL**: 5432
- **Redis**: 6379

### Volumes

Alle Paperless-Daten werden in `/mnt/user/dokumente/paperless` gespeichert:

```
/mnt/user/dokumente/paperless/
├── data/           # Datenbank-Dateien und Metadaten
├── media/          # Originaldokumente und verarbeitete Dateien
├── export/         # Exportierte Dokumente
└── consume/        # Upload-Ordner für neue Dokumente
```

Container-spezifische Daten werden in `/opt/paperless-stack/data` gespeichert:

```
/opt/paperless-stack/
├── data/
│   ├── postgres/        # PostgreSQL Datenbank
│   ├── redis/           # Redis Datenbank
│   ├── ollama/          # Ollama Modelle und Konfiguration
│   └── paperless-ai/    # Paperless-AI Daten
└── config/
    └── paperless-ai/    # Paperless-AI Konfiguration
```

## 📚 Verwendung

### Zugriff auf die Web-Interfaces

Nach erfolgreicher Installation:

1. **Paperless-NGX**: `http://[SERVER-IP]:8000`
   - Login mit den bei der Installation angegebenen Credentials
   - Dokumente hochladen, verwalten und durchsuchen

2. **Paperless-AI**: `http://[SERVER-IP]:3000`
   - Setup-Assistent beim ersten Besuch durchlaufen
   - KI-Features für Dokumentenanalyse nutzen

3. **Ollama API**: `http://[SERVER-IP]:11434`
   - API-Endpoint für direkte Ollama-Anfragen

### Tags und automatische Verarbeitung

- **"Neu"-Tag**: Wird automatisch allen neuen Dokumenten zugewiesen und triggert die KI-Verarbeitung
- **"RAG"-Tag**: Manuell für Dokumente setzen, die im RAG-Chat verfügbar sein sollen

### RAG-Chat verwenden

1. Dokumente in Paperless-NGX mit "RAG"-Tag markieren
2. In Paperless-AI den Chat öffnen
3. Fragen zu Ihren Dokumenten stellen - die KI antwortet basierend auf dem Dokumenteninhalt

### Ollama Modelle verwalten

```bash
# In den Stack-Ordner wechseln
cd /opt/paperless-stack

# Installierte Modelle anzeigen
docker exec paperless-ollama ollama list

# Neues Modell herunterladen
docker exec paperless-ollama ollama pull <model-name>

# Modell interaktiv testen
docker exec -it paperless-ollama ollama run gemma2:9b
```

## 🛠️ Management

### Container verwalten

```bash
# In den Stack-Ordner wechseln
cd /opt/paperless-stack

# Status aller Container anzeigen
docker compose ps

# Logs anzeigen
docker compose logs -f

# Alle Container stoppen
docker compose down

# Alle Container starten
docker compose up -d

# Einzelnen Container neustarten
docker compose restart <service-name>
```

### Backup erstellen

```bash
# Vollständiges Backup (Paperless-Daten + Stack-Konfiguration)
sudo tar -czf paperless-backup-$(date +%Y%m%d).tar.gz \
  /mnt/user/dokumente/paperless \
  /opt/paperless-stack

# Nur Paperless-Daten sichern
sudo tar -czf paperless-data-backup-$(date +%Y%m%d).tar.gz \
  /mnt/user/dokumente/paperless
```

### Updates durchführen

```bash
cd /opt/paperless-stack

# Images aktualisieren
docker compose pull

# Container mit neuen Images neu starten
docker compose up -d
```

## 🔍 Troubleshooting

### Container startet nicht

```bash
# Logs des problematischen Containers anzeigen
docker compose logs <service-name>

# Container neu erstellen
docker compose up -d --force-recreate <service-name>
```

### Ollama Modell fehlt

```bash
# Gemma2:9B Modell manuell herunterladen
docker exec paperless-ollama ollama pull gemma2:9b
```

### Paperless-AI kann nicht auf Paperless-NGX zugreifen

```bash
# API Token überprüfen
cat /opt/paperless-stack/config/paperless-ai/.env | grep PAPERLESS_API_TOKEN

# Container neu starten
docker compose restart paperless-ai
```

### Speicherplatz prüfen

```bash
# Docker Speichernutzung anzeigen
docker system df

# Nicht verwendete Images/Container/Volumes entfernen
docker system prune -a --volumes
```

## 📖 Technische Details

### Stack-Komponenten

| Komponente | Image | Port | Beschreibung |
|------------|-------|------|--------------|
| Paperless-NGX | ghcr.io/paperless-ngx/paperless-ngx:latest | 8000 | Dokumentenverwaltung |
| Paperless-AI | clusterzx/paperless-ai:latest | 3000 | KI-Integration |
| Ollama | ollama/ollama:latest | 11434 | Lokale KI-Engine |
| PostgreSQL | postgres:15-alpine | 5432 | Datenbank |
| Redis | redis:7-alpine | 6379 | Cache |

### Netzwerk

Alle Container sind im Docker-Netzwerk `paperless-net` verbunden und können über ihre Service-Namen kommunizieren.

### Ressourcen-Anforderungen

| Komponente | RAM | CPU | Disk |
|------------|-----|-----|------|
| Paperless-NGX | 1-2 GB | 1-2 Cores | 2 GB |
| Paperless-AI | 512 MB | 1 Core | 1 GB |
| Ollama + Gemma2:9B | 4-6 GB | 2-4 Cores | 6 GB |
| PostgreSQL | 256 MB | 1 Core | 1 GB |
| Redis | 128 MB | 1 Core | 100 MB |

**Gesamt**: ~8-10 GB RAM, 4-6 CPU-Cores, ~20 GB Festplatte

## 🤝 Beiträge

Beiträge, Issues und Feature-Requests sind willkommen!

## 📄 Lizenz

Dieses Projekt ist unter der MIT-Lizenz lizenziert.

## 🙏 Credits

- [Paperless-NGX](https://github.com/paperless-ngx/paperless-ngx)
- [Paperless-AI](https://github.com/clusterzx/paperless-ai)
- [Ollama](https://github.com/ollama/ollama)
- [Gemma2](https://ai.google.dev/gemma)

## 📞 Support

Bei Fragen oder Problemen erstellen Sie bitte ein Issue in diesem Repository.

---

**Version**: 12.0
**Stand**: 25.11.2025
**Autor**: FBW
