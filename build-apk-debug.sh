#!/usr/bin/env bash
# Build APK debug offline (VM Hatch: repo Maven lokal + IPv4 JVM).
# Pemakaian: ./build-apk-debug.sh [debug|release]
set -e
MODE="${1:-debug}"
export PATH=~/workspace/tools/flutter/bin:$PATH
export JAVA_HOME=~/workspace/tools/jdk-21
export ANDROID_SDK_ROOT=~/workspace/tools/android-sdk
export GRADLE_USER_HOME=~/workspace/tools/gradle-home
export GRADLE_OPTS="-Djava.net.preferIPv4Stack=true"
export JAVA_TOOL_OPTIONS="-Djava.net.preferIPv4Stack=true"
export LOCAL_MAVEN_REPO=~/workspace/tools/gradle-offline/maven-repo
cd ~/workspace/ecommerce-mobile
flutter build apk --"$MODE" --dart-define API_BASE_URL=https://api.alikmakanmie.my.id/api/v1

# Verifikasi pasca-build (WAJIB): MainActivity harus ada di salah satu dex.
# Bug 6 Nov 2026: MainActivity.kt di package salah
# (com.slaras.foodlab.slaras_nusa_foodlab) -> manifest minta
# com.slaras.foodlab.MainActivity -> R8 membuang kelas tak-terpakai itu ->
# ClassNotFoundException di SETIAP launch. Jangan kirim APK tanpa cek ini.
APK="build/app/outputs/flutter-apk/app-$MODE.apk"
DEXDUMP=$(ls -d ~/workspace/tools/android-sdk/build-tools/*/dexdump 2>/dev/null | sort -V | tail -1)
if [ -n "$DEXDUMP" ] && [ -f "$APK" ]; then
  TMPD=$(mktemp -d)
  unzip -o -q "$APK" "classes*.dex" -d "$TMPD"
  if ! { for d in "$TMPD"/classes*.dex; do "$DEXDUMP" "$d" 2>/dev/null; done; } | grep -q "Lcom/slaras/foodlab/MainActivity;"; then
    echo "VERIFIKASI GAGAL: MainActivity tidak ada di dex $APK — JANGAN KIRIM" >&2
    rm -rf "$TMPD"
    exit 1
  fi
  echo "Verifikasi dex OK: MainActivity ada di $APK"
  rm -rf "$TMPD"
else
  echo "PERINGATAN: dexdump/APK tidak ditemukan, verifikasi dex dilewati" >&2
fi
