#!/usr/bin/env bash
set -e

echo "===================================================="
echo "  Compilation de l'APK Android : HomeView Tablette  "
echo "===================================================="

mkdir -p app/src/main/assets
cp index.html manifest.json app/src/main/assets/

if command -v gradle &> /dev/null && [ -n "$ANDROID_HOME" ]; then
  echo "-> Compilation directe avec Gradle & Android SDK local..."
  gradle assembleRelease
  cp app/build/outputs/apk/release/app-release.apk ./HomeView-Tablet.apk
  echo "✅ APK généré : ./HomeView-Tablet.apk"
elif command -v podman &> /dev/null || command -v docker &> /dev/null; then
  ENGINE=$(command -v podman || command -v docker)
  echo "-> Compilation de l'APK via conteneur Android SDK ($ENGINE)..."
  $ENGINE run --rm -v "$(pwd)":/project -w /project ghcr.io/cirruslabs/android-sdk:34 \
    bash -c "gradle assembleRelease && cp app/build/outputs/apk/release/app-release.apk /project/HomeView-Tablet.apk"
  echo "✅ APK généré : ./HomeView-Tablet.apk"
else
  echo "ℹ️ Pour compiler sans rien installer localement, poussez ce dépôt sur GitHub :"
  echo "   Le workflow .github/workflows/build-apk.yml génère et publie automatiquement HomeView-Tablet.apk dans l'onglet Releases & Actions !"
fi
