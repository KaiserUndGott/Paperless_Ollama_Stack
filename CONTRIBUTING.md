# Beiträge zum Paperless-Ollama-Stack

Vielen Dank für Ihr Interesse, zum Paperless-Ollama-Stack beizutragen! Dieses Dokument beschreibt die Richtlinien für Beiträge.

## 🤝 Wie Sie beitragen können

### Fehler melden

Wenn Sie einen Fehler gefunden haben:

1. Prüfen Sie zunächst, ob das Problem bereits als [Issue](https://github.com/KaiserUndGott/Paperless_Ollama_Stack/issues) gemeldet wurde
2. Falls nicht, erstellen Sie ein neues Issue mit:
   - Klarer Beschreibung des Problems
   - Schritten zur Reproduktion
   - Erwartetes vs. tatsächliches Verhalten
   - Ihrer Umgebung (OS, Docker-Version, etc.)
   - Relevanten Log-Ausgaben

### Verbesserungen vorschlagen

Feature-Requests sind willkommen! Bitte:

1. Erstellen Sie ein Issue mit dem Label `enhancement`
2. Beschreiben Sie den Anwendungsfall
3. Erklären Sie, warum diese Funktion nützlich wäre
4. Schlagen Sie eine mögliche Implementierung vor (optional)

### Pull Requests

1. **Fork** das Repository
2. **Erstellen** Sie einen Feature-Branch (`git checkout -b feature/AmazingFeature`)
3. **Committen** Sie Ihre Änderungen (`git commit -m 'Add some AmazingFeature'`)
4. **Pushen** Sie zum Branch (`git push origin feature/AmazingFeature`)
5. **Öffnen** Sie einen Pull Request

#### Pull Request Richtlinien

- Beschreiben Sie klar, was der PR ändert und warum
- Referenzieren Sie relevante Issues (z.B. `Fixes #123`)
- Testen Sie Ihre Änderungen auf Ubuntu und (wenn möglich) Unraid
- Halten Sie sich an den bestehenden Code-Stil
- Aktualisieren Sie die Dokumentation bei Bedarf

## 📝 Code-Stil

### Bash-Script Konventionen

- Verwenden Sie 4 Leerzeichen für Einrückungen
- Variablen in GROSSBUCHSTABEN für globale Konfiguration
- Variablen in kleinbuchstaben für lokale Variablen
- Aussagekräftige Funktionsnamen
- Kommentare für komplexe Logik
- Fehlerbehandlung mit `set -e` und expliziten Checks

### Commit-Messages

- Verwenden Sie klare, beschreibende Commit-Messages
- Beginnen Sie mit einem Verb im Imperativ (z.B. "Add", "Fix", "Update")
- Halten Sie die erste Zeile unter 72 Zeichen
- Fügen Sie bei Bedarf einen detaillierten Beschreibungstext hinzu

Beispiel:
```
Add platform detection for Unraid

- Automatically detect Unraid systems
- Skip Docker installation on Unraid
- Add platform-specific path selection
```

## 🧪 Testen

Vor dem Einreichen eines Pull Requests:

1. **Testen Sie auf einer frischen Ubuntu-Installation**:
   ```bash
   # In einer VM oder Container
   sudo ./install_v12.sh
   ```

2. **Prüfen Sie die Logs**:
   ```bash
   tail -f /var/log/paperless-install.log
   ```

3. **Verifizieren Sie die Funktionalität**:
   - Alle Container sollten laufen
   - Paperless-NGX sollte erreichbar sein
   - Paperless-AI sollte funktionieren
   - Ollama sollte das Gemma2-Modell geladen haben

## 📚 Dokumentation

Wenn Sie Code ändern, der die Funktionalität beeinflusst:

- Aktualisieren Sie die README.md
- Fügen Sie Einträge zu CHANGELOG.md hinzu
- Aktualisieren Sie Code-Kommentare
- Ergänzen Sie Beispiele bei Bedarf

## 🐛 Debugging

Hilfreiche Befehle zum Debuggen:

```bash
# Docker Compose Validierung
cd /opt/paperless-stack
docker compose config

# Container-Logs
docker compose logs -f

# Einzelner Container-Log
docker compose logs paperless-ngx

# Container-Status
docker compose ps

# In Container einloggen
docker exec -it paperless-ngx bash
```

## 💬 Kommunikation

- Seien Sie respektvoll und konstruktiv
- Verwenden Sie Deutsch oder Englisch
- Bleiben Sie beim Thema in Issues und PRs
- Fragen Sie nach, wenn etwas unklar ist

## 📜 Lizenz

Durch Beiträge stimmen Sie zu, dass Ihre Arbeit unter der [MIT-Lizenz](LICENSE) lizenziert wird, die für dieses Projekt gilt.

## 🙏 Danke

Vielen Dank, dass Sie sich die Zeit nehmen, zu diesem Projekt beizutragen!

---

Bei Fragen können Sie gerne ein Issue erstellen oder mich kontaktieren.
