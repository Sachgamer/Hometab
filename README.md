# HomeView Tablette — Application Android (APK)

Application **HomeView** pour tablette de salle à manger / salon, au design **Apple Home Sombre** :
- **Planning & Tâches de la journée** : vue par jour, attribution de chaque tâche à un membre du foyer, personnalisation libre de l'emoji de chaque personne, filtres rapides en 1 clic et barre de progression quotidienne.
- **YouTube Music** : widget de contrôle musical avec ambiances pré-configurées, lecteur YouTube Music intégré et ouverture directe de l'application native Android YouTube Music (`com.google.android.apps.youtube.music`).
- **Mode Kiosque Tablette Natif** :
  - Orientation paysage automatique (`sensorLandscape`).
  - Maintien de l'écran allumé (`FLAG_KEEP_SCREEN_ON` & `WAKE_LOCK`).
  - Mode Plein Écran Immersif (`SYSTEM_UI_FLAG_IMMERSIVE_STICKY` / masquage des barres système Android).
  - Peut être défini comme **écran d'accueil par défaut (Launcher Home)** de la tablette.

---

## Architecture du projet Android

- [`app/src/main/AndroidManifest.xml`](app/src/main/AndroidManifest.xml) : Permissions Android, configuration paysage, mode plein écran et intent-filter `HOME` / `LAUNCHER`.
- [`app/src/main/java/com/maison/homeview/MainActivity.java`](app/src/main/java/com/maison/homeview/MainActivity.java) : Activité Android native en mode immersif avec WebView matériel accéléré, persistance `domStorage` et pont JavaScript natif `AndroidHomeView` vers l'application YouTube Music.
- [`app/src/main/assets/index.html`](app/src/main/assets/index.html) & [`index.html`](index.html) : Interface HomeView complète.
- [`.github/workflows/build-apk.yml`](.github/workflows/build-apk.yml) : Pipeline **GitHub Actions** qui compile automatiquement `HomeView-Tablet.apk` à chaque `git push` et publie l'APK directement dans l'onglet **Releases** de votre dépôt GitHub.

---

## Générer et télécharger l'APK

### Option 1 : Via GitHub Actions (Automatique à chaque push)
Dès que le code est poussé sur GitHub (branche `main`), l'action **Build HomeView Android APK** compile l'APK et crée une **Release GitHub** contenant le fichier téléchargeable `HomeView-Tablet.apk`.

### Option 2 : En local (via Podman / Docker ou Android SDK)
```bash
./build-apk.sh
```
Le fichier `HomeView-Tablet.apk` est généré à la racine du projet.
