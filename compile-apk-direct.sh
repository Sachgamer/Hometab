#!/usr/bin/env bash
set -e

TOOLCHAIN_DIR="/home/sachgamer/.gemini/antigravity/scratch/android-toolchain"
PROJECT_DIR="/home/sachgamer/.gemini/antigravity/scratch/homeview-tablet"
mkdir -p "$TOOLCHAIN_DIR"

# 1. Télécharger JDK 17 portable si absent
if [ ! -f "$TOOLCHAIN_DIR/jdk/bin/javac" ]; then
  echo "-> Téléchargement de OpenJDK 17 portable..."
  mkdir -p "$TOOLCHAIN_DIR/jdk"
  curl -fsSL "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse" -o "$TOOLCHAIN_DIR/jdk17.tar.gz"
  tar -xzf "$TOOLCHAIN_DIR/jdk17.tar.gz" -C "$TOOLCHAIN_DIR/jdk" --strip-components=1
  rm -f "$TOOLCHAIN_DIR/jdk17.tar.gz"
fi

export JAVA_HOME="$TOOLCHAIN_DIR/jdk"
export PATH="$JAVA_HOME/bin:$PATH"

# 2. Télécharger Android Command Line Tools si absent
ANDROID_SDK="$TOOLCHAIN_DIR/sdk"
if [ ! -f "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
  echo "-> Téléchargement des outils Android SDK..."
  mkdir -p "$ANDROID_SDK/cmdline-tools"
  curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -o "$TOOLCHAIN_DIR/cmdtools.zip"
  python3 -m zipfile -e "$TOOLCHAIN_DIR/cmdtools.zip" "$ANDROID_SDK/cmdline-tools"
  mv "$ANDROID_SDK/cmdline-tools/cmdline-tools" "$ANDROID_SDK/cmdline-tools/latest"
  chmod +x "$ANDROID_SDK/cmdline-tools/latest/bin/"*
  rm -f "$TOOLCHAIN_DIR/cmdtools.zip"
fi

# 3. Installer build-tools;34.0.0 et platforms;android-34
if [ ! -f "$ANDROID_SDK/platforms/android-34/android.jar" ]; then
  echo "-> Installation de Android SDK Platform 34 & Build-Tools 34.0.0..."
  yes | "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_SDK" --licenses > /dev/null 2>&1 || true
  "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_SDK" "platforms;android-34" "build-tools;34.0.0"
fi

BUILD_TOOLS="$ANDROID_SDK/build-tools/34.0.0"
ANDROID_JAR="$ANDROID_SDK/platforms/android-34/android.jar"
chmod +x "$BUILD_TOOLS/"* 2>/dev/null || true

# 4. Compiler l'APK HomeView-Tablet.apk
echo "-> Compilation de HomeView-Tablet.apk..."
cd "$PROJECT_DIR"
mkdir -p app/src/main/assets
cp index.html manifest.json app/src/main/assets/

WORK_DIR="$PROJECT_DIR/build/direct-apk"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/compiled_res" "$WORK_DIR/gen" "$WORK_DIR/classes" "$WORK_DIR/dex"

# 4a. Compiler les ressources avec aapt2
"$BUILD_TOOLS/aapt2" compile --dir app/src/main/res -o "$WORK_DIR/compiled_res/res.zip"

# 4b. Lier les ressources, le manifeste et les assets (index.html, manifest.json)
"$BUILD_TOOLS/aapt2" link \
  -I "$ANDROID_JAR" \
  --manifest app/src/main/AndroidManifest.xml \
  -A app/src/main/assets \
  --java "$WORK_DIR/gen" \
  --min-sdk-version 21 \
  --target-sdk-version 33 \
  --version-code 8 \
  --version-name "2.6.0" \
  -o "$WORK_DIR/unaligned.apk" \
  "$WORK_DIR/compiled_res/res.zip"

# 4c. Compiler le code Java (MainActivity.java + R.java) en bytecode Java 8 universel
javac -source 1.8 -target 1.8 \
  -classpath "$ANDROID_JAR" \
  -d "$WORK_DIR/classes" \
  "$WORK_DIR/gen/com/maison/homeview/R.java" \
  app/src/main/java/com/maison/homeview/MainActivity.java

# 4d. Convertir les classes Java en Dalvik bytecode (classes.dex) avec d8 (min-api 21)
CLASS_FILES=$(find "$WORK_DIR/classes" -name "*.class")
"$BUILD_TOOLS/d8" --lib "$ANDROID_JAR" --min-api 21 --output "$WORK_DIR/dex" $CLASS_FILES

# 4e. Ajouter classes.dex dans l'APK
python3 - << 'EOF'
import zipfile
apk_path = "/home/sachgamer/.gemini/antigravity/scratch/homeview-tablet/build/direct-apk/unaligned.apk"
dex_path = "/home/sachgamer/.gemini/antigravity/scratch/homeview-tablet/build/direct-apk/dex/classes.dex"
with zipfile.ZipFile(apk_path, 'a', compression=zipfile.ZIP_DEFLATED) as zf:
    zf.write(dex_path, "classes.dex")
EOF

# 4f. Aligner l'APK avec zipalign
"$BUILD_TOOLS/zipalign" -f -p 4 "$WORK_DIR/unaligned.apk" "$WORK_DIR/aligned.apk"

# 4g. Générer une clé de signature et signer l'APK avec TRIPLE SIGNATURE (v1 JAR + v2 + v3)
KEYSTORE="$TOOLCHAIN_DIR/release-key.jks"
if [ ! -f "$KEYSTORE" ]; then
  keytool -genkeypair \
    -keystore "$KEYSTORE" \
    -alias homeview \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -storepass homeview123 \
    -keypass homeview123 \
    -dname "CN=HomeView, OU=Home, O=Maison, L=Paris, S=IDF, C=FR"
fi

"$BUILD_TOOLS/apksigner" sign \
  --min-sdk-version 21 \
  --v1-signing-enabled true \
  --v2-signing-enabled true \
  --v3-signing-enabled true \
  --ks "$KEYSTORE" \
  --ks-key-alias homeview \
  --ks-pass pass:homeview123 \
  --key-pass pass:homeview123 \
  --out "$PROJECT_DIR/HomeView-Tablet.apk" \
  "$WORK_DIR/aligned.apk"

"$BUILD_TOOLS/apksigner" verify --verbose "$PROJECT_DIR/HomeView-Tablet.apk"
ls -lh "$PROJECT_DIR/HomeView-Tablet.apk"
echo "✅ APK compilé et signé avec succès : $PROJECT_DIR/HomeView-Tablet.apk"
