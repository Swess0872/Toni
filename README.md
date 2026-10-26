# Toni — Strichsystem

Eine Gruppen-Strichliste: Wer Mist baut, bekommt einen Strich. Wer pro Monat die meisten Striche hat, „gewinnt“.

| Teil | Technik | Ordner |
|---|---|---|
| Apps (iOS, Android, Web/PWA, TV-Browser) | Flutter | [app/](app/) |
| Server | ASP.NET Core (.NET 10), PostgreSQL, SignalR | [api/](api/) |
| Kubernetes | Helm + Argo CD (GitOps) | [deploy/](deploy/) |
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

```
git push main ──► GitHub Actions: Tests → Images nach ghcr.io/<owner>/toni-api|toni-web
                                     └─► Commit: neuer Image-Tag in deploy/charts/toni/values.yaml
Argo CD (im Cluster) ◄── sieht den Commit ──► rollt die neue Version aus
```

### Cluster einmalig einrichten

Voraussetzungen:

- `kubectl` zeigt auf den Cluster.
- Der DNS-Eintrag `toni.techstein.ch` zeigt auf die öffentliche IP des Clusters.
- Die Ports **80 und 443** sind von außen erreichbar, ggf. per Port-Weiterleitung im Router. Let's Encrypt prüft über Port 80.
- Es gibt eine Default-StorageClass für die Postgres-Daten (`kubectl get storageclass`). Sonst `database.storageClass` in [deploy/charts/toni/values.yaml](deploy/charts/toni/values.yaml) setzen.

Traefik lauscht direkt auf Port 80/443 der Nodes (`traefik.hostPorts: true` in [deploy/platform/values.yaml](deploy/platform/values.yaml)), weil ein selbst gehosteter Cluster meist keinen LoadBalancer hat.

```bash
REPO_URL=https://github.com/<owner>/<repo> \
ACME_EMAIL=<deine-mail> \
./deploy/bootstrap/install.sh
```

Das Skript installiert Argo CD (falls noch nicht vorhanden), legt die Secrets an (JWT-Schlüssel, erster Admin-Login) und erstellt die Root-Application `toni-root`. Was schon im Cluster läuft (Argo CD, Traefik, cert-manager, CloudNativePG), wird erkannt und nicht angefasst. Läuft Argo CD in einem anderen Namespace als `argocd`, setze `ARGOCD_NAMESPACE=<ns>`.

Ab dann installiert Argo CD alles Weitere aus [deploy/platform/](deploy/platform/):

- **Traefik** (Ingress; wird übersprungen, wenn schon eines läuft, z.B. bei k3s)
- **cert-manager** + Let's-Encrypt-Issuer
- **CloudNativePG** (Postgres-Operator) und die Toni-Datenbank
- **Toni** (API + Web) aus [deploy/charts/toni/](deploy/charts/toni/)
- **Argo CD selbst**: Updates laufen über [deploy/argocd/kustomization.yaml](deploy/argocd/kustomization.yaml). Gilt nur, wenn das Skript Argo CD installiert hat; ein schon vorhandenes Argo CD bleibt, wie es ist.

Für ein **privates Repo** zusätzlich `GITHUB_TOKEN=<PAT mit repo + read:packages>` mitgeben.

Status: `kubectl -n argocd get applications`

## Store-Releases

Tag pushen (`git tag v1.0.0 && git push --tags`), dann landet die Android-App im internen Test-Track von Google Play und die iOS-App in TestFlight. Einrichtung der Accounts und Secrets: [docs/STORE-RELEASE.md](docs/STORE-RELEASE.md).
