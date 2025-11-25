# Port-Übersicht Paperless-Ollama Stack

## Standard-Ports

Die folgenden Ports werden von den Containern verwendet. Das Script sucht automatisch nach freien Ports und wählt ggf. den nächsten verfügbaren Port.

### Web-Interfaces (extern zugänglich)

| Service | Standard-Port | Container-Port | Beschreibung | URL |
|---------|---------------|----------------|--------------|-----|
| **Paperless-NGX** | 8000 | 8000 | Hauptanwendung für Dokumentenverwaltung | `http://[SERVER-IP]:8000` |
| **Paperless-AI** | 3000 | 3000 | KI-gestützte Dokumentenanalyse und RAG-Chat | `http://[SERVER-IP]:3000` |
| **Ollama API** | 11434 | 11434 | Lokale KI-Engine API-Endpoint | `http://[SERVER-IP]:11434` |

### Datenbank-Services (intern)

| Service | Standard-Port | Container-Port | Beschreibung | Zugriff |
|---------|---------------|----------------|--------------|---------|
| **PostgreSQL** | 5432 | 5432 | Relationale Datenbank für Paperless-NGX | Intern + Host |
| **Redis** | 6379 | 6379 | Cache und Message-Broker | Intern + Host |

## Port-Konfiguration

Die Ports werden in der Datei `/opt/paperless-stack/.env` gespeichert:

```bash
# Web-Services
PAPERLESS_PORT=8000
PAPERLESS_AI_PORT=3000
OLLAMA_PORT=11434

# Datenbank-Services
POSTGRES_PORT=5432
REDIS_PORT=6379
```

## Automatische Port-Erkennung

Das Installations-Script prüft automatisch, ob die Standard-Ports belegt sind:

1. **Port verfügbar**: Standard-Port wird verwendet
2. **Port belegt**: Nächster freier Port wird gewählt (z.B. 8001, 8002, etc.)

Beispiel bei belegten Ports:
```
Port 8000 belegt → Paperless-NGX auf Port 8001
Port 11434 belegt → Ollama auf Port 11435
```

## Firewall-Konfiguration

Das Script öffnet automatisch die erforderlichen Ports in der Firewall (UFW/Firewalld):

**Extern zugängliche Ports:**
- Paperless-NGX: `${PAPERLESS_PORT}/tcp`
- Paperless-AI: `${PAPERLESS_AI_PORT}/tcp`
- Ollama API: `${OLLAMA_PORT}/tcp`

**Hinweis**: PostgreSQL und Redis Ports werden NICHT in der Firewall geöffnet (nur lokaler Zugriff).

## Container-Netzwerk

Alle Container sind im Docker-Netzwerk `paperless-net` verbunden:

```
paperless-net (bridge)
├── postgres (postgres:5432)
├── redis (redis:6379)
├── paperless-ollama (ollama:11434)
├── paperless-ngx (paperless-ngx:8000)
└── paperless-ai (paperless-ai:3000)
```

Container können untereinander über Service-Namen kommunizieren:
- `postgres:5432`
- `redis:6379`
- `ollama:11434` (für Paperless-AI)

## Port-Prüfung

Nach der Installation können Sie die verwendeten Ports prüfen:

```bash
# Alle Container-Ports anzeigen
cd /opt/paperless-stack
docker compose ps --format "table {{.Name}}\t{{.Ports}}"

# Aktuelle Port-Konfiguration anzeigen
cat /opt/paperless-stack/.env | grep PORT

# Netzwerk-Verbindungen prüfen
ss -tuln | grep -E "8000|3000|11434|5432|6379"
```

## Manuelle Port-Änderung

Falls Sie die Ports manuell ändern möchten:

1. Stack stoppen:
   ```bash
   cd /opt/paperless-stack
   docker compose down
   ```

2. Ports in `.env` anpassen:
   ```bash
   nano /opt/paperless-stack/.env
   # Ports ändern
   ```

3. Stack neu starten:
   ```bash
   docker compose up -d
   ```

4. Firewall-Regeln aktualisieren (UFW):
   ```bash
   sudo ufw allow [NEUER_PORT]/tcp
   sudo ufw delete allow [ALTER_PORT]/tcp
   ```

## Externe Zugriffe

### Von lokalem Netzwerk:
```
http://[SERVER-IP]:8000    # Paperless-NGX
http://[SERVER-IP]:3000    # Paperless-AI
http://[SERVER-IP]:11434   # Ollama API
```

### Von localhost (auf dem Server):
```
http://localhost:8000      # Paperless-NGX
http://localhost:3000      # Paperless-AI
http://localhost:11434     # Ollama API
```

## Troubleshooting

### Port bereits belegt
```bash
# Prüfen welcher Prozess den Port belegt
sudo ss -tulpn | grep :8000

# Prozess beenden oder anderen Port wählen
```

### Container kann nicht auf Port binden
```bash
# Container-Logs prüfen
docker compose logs paperless-ngx

# Port-Konflikt in .env lösen und neu starten
```

### Firewall blockiert Zugriff
```bash
# UFW Status prüfen
sudo ufw status

# Port manuell öffnen
sudo ufw allow 8000/tcp
```
