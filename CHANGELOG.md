# Changelog

Alle bemerkenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/),
und dieses Projekt hält sich an [Semantic Versioning](https://semver.org/lang/de/).

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
