# Changelog

Alle bemerkenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/),
und dieses Projekt hält sich an [Semantic Versioning](https://semver.org/lang/de/).

## [12.2.0] - 2025-11-25

### Hinzugefügt
- **Re-Installation Support**: Automatische Erkennung bestehender Installationen
- **Interaktives Update-Menu**: 4 Optionen für verschiedene Szenarien
  1. Installation abbrechen
  2. Container neu erstellen (behält alle Daten + Modelle)
  3. Komplette Neuinstallation (behält nur Ollama-Modelle)
  4. Container neustarten
- **Ollama-Modell-Schutz**: Automatisches Backup und Wiederherstellung bei Neuinstallation
- **Container-Update ohne Datenverlust**: Neue Container mit alter Konfiguration
- **Intelligente Modell-Prüfung**: Überspringe Download wenn Modell bereits vorhanden
- **Installation-Status-Anzeige**: Zeigt Container-Status, Verzeichnisgrößen, Modelle

### Geändert
- **cleanup_existing_installation()**: Komplett überarbeitet mit erweiterten Optionen
- **start_stack()**: Prüft ob Ollama-Modelle bereits vorhanden oder wiederhergestellt werden müssen
- **Ollama-Handling**: Drei Modi - Neuinstallation, Update, Wiederherstellung

### Technisch
- Neue Funktionen:
  - `check_existing_installation()` - Prüft ob Installation existiert
  - `show_existing_installation_info()` - Zeigt detaillierte Infos
  - `handle_existing_installation()` - Interaktives Menu
  - `recreate_containers()` - Update ohne Datenverlust
  - `restart_existing_containers()` - Einfacher Neustart
  - `confirm_full_reinstall()` - Sicherheitsabfrage
  - `full_reinstall()` - Komplette Neuinstallation mit Backup
  - `backup_ollama_models()` - Sichert Modelle nach /tmp
  - `restore_ollama_models()` - Stellt Modelle wieder her
- Neue Flags: EXISTING_DATA, RESTORE_OLLAMA_MODELS, OLLAMA_BACKUP_DIR
- Backup-Verzeichnis: `/tmp/ollama_backup_YYYYMMDD_HHMMSS/`

### Use Cases
- **Container-Update**: Script erneut starten → Option 2 → Neue Container mit allen Daten
- **Konfig-Änderung**: Script mit neuen Parametern starten → Option 2
- **Neuanfang**: Script starten → Option 3 → Alles neu außer Ollama-Modelle
- **Troubleshooting**: Script starten → Option 4 → Schneller Neustart

## [12.1.2] - 2025-11-25

### Behoben
- **Ollama Container Startup**: Robuste Warteschleife mit API-Prüfung vor Modell-Download
- **Gemma2:9B Download**: Verbesserte Fehlerbehandlung und Fortschrittsanzeige
- **Container-Bereitschaft**: Neue `wait_for_ollama()` Funktion prüft Container-Status und API-Verfügbarkeit
- **Download-Verifizierung**: Überprüfung dass Modell nach Download verfügbar ist
- **Fehlerdiagnose**: Detaillierte Fehlermeldungen mit Troubleshooting-Hinweisen

### Hinzugefügt
- **wait_for_ollama()**: Wartet bis zu 2.5 Minuten auf Ollama-API-Bereitschaft
- **download_ollama_model()**: Separierte Funktion für Modell-Download mit besserer Fehlerbehandlung
- **API-Healthcheck**: Prüft `http://localhost:11434/api/tags` vor Modell-Download
- **Container-Log-Ausgabe**: Zeigt Container-Logs bei Startup-Problemen
- **Manuelle Recovery-Anweisungen**: Gibt Befehle aus für manuellen Modell-Download

### Technisch
- Neue Funktion `wait_for_ollama()` mit 30 Versuchen à 5 Sekunden
- Neue Funktion `download_ollama_model()` mit Fortschrittsanzeige
- Ersetzt `sleep 30` durch robuste API-Prüfung
- Verbesserte Fehlerausgabe bei Ollama-Problemen

## [12.1.1] - 2025-11-25

### Hinzugefügt
- **Installations-Verifizierung**: Umfassende Container-Status-Prüfung nach Installation
- **Health-Check-Monitoring**: Automatische Überprüfung aller Container Health-Checks
- **Farbcodierte Status-Tabelle**: Übersichtliche Anzeige von Container-Status, Health und Uptime
- **Automatische Wiederholungsprüfung**: Zweite Prüfung bei "starting" Health-Status
- **Troubleshooting-Hinweise**: Automatische Hilfe bei Problemen

### Geändert
- **Verbesserte Abschluss-Ausgabe**: Status-Verifizierung vor Erfolgs-Meldung
- **Erweiterte Fehlerbehandlung**: Detaillierte Fehlerausgabe bei Container-Problemen

### Technisch
- Neue Funktion `verify_installation()` mit 140+ Zeilen
- Docker-Inspect-Abfragen für Status, Health und Uptime
- Farbcodierung: Grün (OK), Gelb (Warning), Rot (Error), Cyan (No Check)
- Automatische Container-Name-Normalisierung

## [12.1.0] - 2025-11-25

### Hinzugefügt
- **Multi-Platform-Unterstützung**: Automatische Erkennung und Unterstützung für Ubuntu und Unraid
- **Vollautomatische Docker-Installation**: Complete Docker-Setup für Ubuntu-Systeme
- **Plattformerkennung**: Automatische Erkennung von Ubuntu/Debian und Unraid-Systemen
- **Flexible Pfadwahl**: Auswahl des Datenverzeichnisses je nach Plattform
- **Verbesserte Port-Erkennung**: Unterstützung für `ss` und `netstat`
- **Erweiterte Docker-Prüfung**: Überprüfung von Docker und Docker Compose Plugin
- **Unraid-spezifische Anpassungen**: Übersprung der Docker-Installation auf Unraid
- **Automatische Verzeichniserstellung**: Option zur automatischen Erstellung fehlender Datenverzeichnisse
- **Plattform-Info in Konfiguration**: Platform-Variable in .env und INSTALLATION_INFO.txt

### Geändert
- **Header aktualisiert**: Version 12.1 - Multi-Platform
- **Verbesserte Firewall-Konfiguration**: Übersprung auf Unraid-Systemen
- **Erweiterte Fehlerbehandlung**: Bessere Fehlerberichte bei fehlgeschlagenen Installationen
- **Optimierte Netzwerk-Konfiguration**: Robustere Port-Erkennung
- **Credential-Abfrage zu Beginn**: Username und Passwort werden vor der Plattform-Erkennung abgefragt

### Dokumentation
- **LICENSE**: MIT-Lizenz hinzugefügt
- **CONTRIBUTING.md**: Umfassende Beitrags-Richtlinien
- **CHANGELOG.md**: Changelog-Datei erstellt
- **README.md**: Erweiterte Dokumentation mit Ubuntu- und Unraid-spezifischen Informationen

### Technisch
- Bash-Script von ~1800 auf ~1320 Zeilen optimiert
- Modularere Funktionsstruktur
- Verbesserte Logging-Ausgaben
- Plattform-abhängige Konfigurationspfade

## [12.0.0] - 2025-11-25

### Hinzugefügt
- **Initiales Release**: Paperless-NGX + Ollama AI Stack
- **Ollama Integration**: Lokale KI-Engine mit Gemma2:9B-Modell
- **Paperless-AI**: KI-gestützte Dokumentenanalyse und -klassifizierung
- **RAG-Chat**: Interaktive Dokumenten-Chats mit KI
- **OpenAI Whisper**: Integrierte Spracherkennung
- **PostgreSQL + Redis**: Robuste Datenbank-Backend
- **Automatische Tag-Erstellung**: "Neu" und "RAG" Tags
- **Container Icons**: Labels für bessere Übersicht in Docker-Tools
- **Credential-Management**: Sichere Passwort-Validierung mit Anforderungen
- **Vollständige .env-Konfiguration**: Alle Umgebungsvariablen zentral verwaltet
- **Docker Compose Setup**: Orchestrierung aller Stack-Komponenten
- **Healthchecks**: Automatische Gesundheitsprüfung aller Container
- **Automatischer Ollama-Model-Download**: Gemma2:9B wird automatisch geladen
- **API-Token-Generierung**: Automatische Erstellung des Paperless-API-Tokens
- **Firewall-Konfiguration**: Automatisches Öffnen benötigter Ports (UFW/Firewalld)

### Komponenten
- Paperless-NGX (ghcr.io/paperless-ngx/paperless-ngx:latest)
- Paperless-AI (clusterzx/paperless-ai:latest)
- Ollama (ollama/ollama:latest) mit Gemma2:9B
- PostgreSQL 15 (Alpine)
- Redis 7 (Alpine)

### Konfiguration
- Ports: 8000 (Paperless), 3000 (AI), 11434 (Ollama), 5432 (PostgreSQL), 6379 (Redis)
- OCR: Deutsch + Englisch, automatische Rotation und Deskewing
- RAG: Token-Limits optimiert für Gemma2:9B
- Whisper: Base-Modell für Audio-Transkription

---

## Versionsschema

- **Major** (X.0.0): Grundlegende Änderungen, Breaking Changes
- **Minor** (0.X.0): Neue Features, rückwärtskompatibel
- **Patch** (0.0.X): Bugfixes, kleine Verbesserungen
