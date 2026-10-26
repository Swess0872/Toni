# Toni — Strichsystem

Eine Gruppen-Strichliste: Wer Mist baut, bekommt einen Strich. Wer pro Monat die meisten Striche hat, „gewinnt“.

| Teil | Technik | Ordner |
|---|---|---|
| Apps (iOS, Android, Web/PWA, TV-Browser) | Flutter | [app/](app/) |
| Server | ASP.NET Core (.NET 10), PostgreSQL, SignalR | [api/](api/) |
| Kubernetes | Kubernetes-YAML + Argo CD (GitOps) | [deploy/](deploy/) |
| Pipelines | GitHub Actions + Fastlane | [.github/workflows/](.github/workflows/) |
| Design-Vorgabe | HTML-Prototyp + Spezifikation | [Toni_design/](Toni_design/) |

Die Layouts sind für das **Handy** gebaut. Auf dem **Fernseher** läuft die Web-App im TV-Browser: Ein Smart-TV wird automatisch erkannt, alternativ `?tv=1` an die URL hängen oder unter *Einstellungen → TV-Ansicht* einschalten. Die UI wird dann hochskaliert und lässt sich mit den Pfeiltasten der Fernbedienung bedienen. Der **PC** bekommt das mehrspaltige Layout.

## Lokal entwickeln

Voraussetzungen: .NET 10 SDK und Flutter (stable). Docker ist optional.

```bash
# API (http://localhost:5080). Lokal mit SQLite-Datei, Demo-Daten mit
# Logins max/toni2026 (Admin), lena/toni, jonas/toni
dotnet run --project api/Toni.Api

# App im Browser gegen die lokale API
cd app
flutter run -d chrome --dart-define=API_URL=http://localhost:5080
```

- Für den Android-Emulator `API_URL=http://10.0.2.2:5080` verwenden.
- Die TV-Ansicht testest du im Browser mit `?tv=1` am Ende der URL.
- Demo-Daten zurücksetzen: `api/toni-dev.db` löschen.
- Lokal mit Postgres statt SQLite: `docker compose -f api/docker-compose.yml up -d` starten und `ConnectionStrings__Default="Host=localhost;Database=toni;Username=toni;Password=toni"` setzen.

Tests: `dotnet test api/Toni.slnx` und `cd app && flutter test`.

### Datenbank-Schema ändern

Produktiv läuft Postgres mit EF-Core-Migrationen, die beim Start automatisch angewendet werden. Migrationen erzeugst du gegen Postgres, nicht gegen die lokale SQLite-Datei:

```bash
cd api
ConnectionStrings__Default="Host=localhost;Database=toni;Username=toni;Password=toni" \
  dotnet ef migrations add <Name> --project Toni.Api --output-dir Data/Migrations
```

## Wie der Code in den Cluster kommt

```text
git push main ──► GitHub Actions: Tests → Images nach ghcr.io/<owner>/toni-api|toni-web
                                     └─► Commit: neue Image-Version in deploy/toni/kustomization.yaml
Argo CD (im Cluster) ◄── sieht den Commit ──► rollt die neue Version aus
```

### Was in `deploy/` liegt

| Datei | Wofür |
|---|---|
| [deploy/toni/kustomization.yaml](deploy/toni/kustomization.yaml) | Liste aller Toni-Dateien + welche Image-Version läuft |
| [deploy/toni/postgres.yaml](deploy/toni/postgres.yaml) | Datenbank mit 2-GB-Volume |
| [deploy/toni/api.yaml](deploy/toni/api.yaml) | C#-Server |
| [deploy/toni/web.yaml](deploy/toni/web.yaml) | Web-App (nginx) |
| [deploy/toni/ingress.yaml](deploy/toni/ingress.yaml) | Adresse `toni.techstein.ch` + HTTPS-Zertifikat |
| [deploy/argocd/toni.yaml](deploy/argocd/toni.yaml) | Sagt Argo CD, dass es `deploy/toni` installieren soll |
| [deploy/argocd/cert-manager.yaml](deploy/argocd/cert-manager.yaml) | *Optional*, falls cert-manager fehlt |
| [deploy/argocd/traefik.yaml](deploy/argocd/traefik.yaml) | *Optional*, falls noch kein Ingress-Controller läuft |

### Cluster einmalig einrichten

Voraussetzungen: Argo CD läuft. Der DNS-Eintrag `toni.techstein.ch` zeigt auf die IP des Clusters, und die Ports 80/443 sind von außen erreichbar (Let's Encrypt prüft über Port 80).

**1. Fehlt etwas?** cert-manager und einen Ingress-Controller braucht Toni. Nur anwenden, was fehlt:

```bash
kubectl get crd certificates.cert-manager.io || kubectl apply -f deploy/argocd/cert-manager.yaml
kubectl get ingressclass                     # leer? → kubectl apply -f deploy/argocd/traefik.yaml
```

**2. Geheimnisse anlegen.** Sie gehören nicht ins Git, darum von Hand:

```bash
kubectl create namespace toni
kubectl -n toni create secret generic toni-secrets \
  --from-literal=dbPassword="$(openssl rand -hex 16)" \
  --from-literal=jwtKey="$(openssl rand -hex 32)" \
  --from-literal=adminPassword="<dein-admin-passwort>"
```

Mit `admin` und diesem Passwort meldest du dich in Toni zum ersten Mal an.

**3. Toni bei Argo CD anmelden.** In [deploy/argocd/toni.yaml](deploy/argocd/toni.yaml) `OWNER` durch deinen GitHub-Namen ersetzen, dann:

```bash
kubectl apply -f deploy/argocd/toni.yaml
```

Status: `kubectl -n argocd get application toni`. Ab jetzt geht jeder Push auf `main` automatisch live.

> **Hinweis:** GHCR legt neue Images als *privat* an, auch bei öffentlichem Repo. Nach dem ersten Release auf GitHub unter *Packages* `toni-api` und `toni-web` auf **Public** stellen.

## Store-Releases

Tag pushen (`git tag v1.0.0 && git push --tags`), dann landet die Android-App im internen Test-Track von Google Play und die iOS-App in TestFlight. Einrichtung der Accounts und Secrets: [docs/STORE-RELEASE.md](docs/STORE-RELEASE.md).
