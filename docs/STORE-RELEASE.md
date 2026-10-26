# Store-Releases einrichten

Die Pipeline [mobile-release.yml](../.github/workflows/mobile-release.yml) läuft bei jedem Tag `v*`:

- **Android:** App Bundle bauen → Google Play, Track *internal*
- **iOS:** IPA bauen und signieren → TestFlight

In die Produktion bringst du eine Version danach selbst: in der Play Console bzw. App Store Connect, oder mit `bundle exec fastlane promote` (Android) bzw. `bundle exec fastlane release` (iOS).

Alle Secrets trägst du unter **GitHub → Settings → Secrets and variables → Actions** ein.

## Android (Google Play)

1. **Play-Console-Konto** anlegen (einmalig 25 $) und die App `ch.techstein.toni` erstellen.
2. **Upload-Keystore** erzeugen und gut aufbewahren. Ohne ihn kannst du keine Updates mehr hochladen.
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   base64 -w0 upload-keystore.jks   # → ANDROID_KEYSTORE_BASE64
   ```
3. **Service-Account** für die Play Developer API anlegen: Google Cloud → Service-Account mit JSON-Key. In der Play Console unter *Nutzer und Berechtigungen* einladen und Releases erlauben.
4. **Ersten Upload von Hand machen:** Google verlangt, dass das erste AAB über die Play Console hochgeladen wird. Lokal bauen mit `flutter build appbundle`, danach übernimmt die Pipeline.

| Secret | Inhalt |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Keystore, base64-kodiert |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore-Passwort |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | Key-Passwort |
| `PLAY_SERVICE_ACCOUNT_JSON` | Inhalt der Service-Account-JSON-Datei |

## iOS (App Store)

1. **Apple Developer Program** (99 $/Jahr). In App Store Connect die App mit Bundle-ID `ch.techstein.toni` anlegen.
2. **App-Store-Connect-API-Key** erzeugen (*Benutzer und Zugriff → Integrationen*, Rolle „App Manager“). Die `.p8`-Datei kannst du nur einmal herunterladen.
3. **Zertifikats-Repo für fastlane match:** ein leeres, **privates** GitHub-Repo, z.B. `toni-certificates`. Beim ersten Lauf erstellt match dort Zertifikat und Provisioning-Profil, verschlüsselt mit `MATCH_PASSWORD`.
4. Danach kannst du die Repository-Variable `MATCH_READONLY=true` setzen. Ab dann liest die Pipeline die Zertifikate nur noch.

| Secret | Inhalt |
|---|---|
| `APPSTORE_KEY_ID` | Key-ID des API-Keys |
| `APPSTORE_ISSUER_ID` | Issuer-ID |
| `APPSTORE_KEY_P8` | Inhalt der `.p8`-Datei |
| `APPLE_TEAM_ID` | 10-stellige Team-ID |
| `MATCH_GIT_URL` | `https://github.com/<owner>/toni-certificates.git` |
| `MATCH_GIT_BASIC_AUTHORIZATION` | `base64("<github-user>:<PAT mit repo-Recht>")` |
| `MATCH_PASSWORD` | frei gewähltes Passwort zum Verschlüsseln der Zertifikate |

## Versionen

- `v1.4.0` ergibt die Versionsnummer `1.4.0`.
- Die Build-Nummer ist die GitHub-Run-Nummer + 100 und steigt damit automatisch.
