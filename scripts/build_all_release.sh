#!/usr/bin/env bash
# AlfaPOS — barcha platformalar uchun release build (macOS host).
# Windows .exe bu mashinada yig'ilmaydi — GitHub Actions orqali.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VER=$(grep '^version:' pubspec.yaml | sed 's/version:[[:space:]]*//')
NAME="${VER%%+*}"
BUILD="${VER#*+}"
RELEASE_DIR="$ROOT/release"
STAMP=$(date +%Y%m%d-%H%M)

echo ">> AlfaPOS release build: $VER"
mkdir -p "$RELEASE_DIR"

echo ">> flutter pub get..."
flutter pub get

echo ">> iOS versiya sync..."
bash scripts/sync_ios_flutter_version.sh

echo ">> Android APK..."
flutter build apk --release
APK_SRC="build/app/outputs/flutter-apk/app-release.apk"
APK_DST="$RELEASE_DIR/alfapos-app-${VER}-release.apk"
cp -f "$APK_SRC" "$APK_DST"
echo "   $APK_DST"

echo ">> Android App Bundle (Google Play)..."
flutter build appbundle --release
AAB_SRC="build/app/outputs/bundle/release/app-release.aab"
AAB_DST="$RELEASE_DIR/alfapos-app-${VER}-release.aab"
cp -f "$AAB_SRC" "$AAB_DST"
echo "   $AAB_DST"

echo ">> iOS (Release, codesign)..."
flutter build ipa --release --export-method app-store 2>/dev/null || \
  flutter build ipa --release --export-method development 2>/dev/null || \
  flutter build ios --release --no-codesign

if compgen -G "build/ios/ipa/*.ipa" > /dev/null; then
  IPA_SRC=$(compgen -G "build/ios/ipa/*.ipa" | sed -n '1p')
  IPA_DST="$RELEASE_DIR/alfapos-app-${VER}-release.ipa"
  cp -f "$IPA_SRC" "$IPA_DST"
  echo "   $IPA_DST"
elif [ -d build/ios/iphoneos/Runner.app ]; then
  echo "   iOS .app tayyor (Archive uchun Xcode: Product → Archive)"
fi

# Windows faqat Windows OS yoki GitHub Actions da yig'iladi
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  echo ">> Windows build (GitHub Actions)..."
  gh workflow run build-windows.yml
  echo "   Workflow ishga tushdi — Actions → alfapos-windows-release artifact"
else
  echo ">> Windows: macOS da yig'ilmaydi."
  echo "   Windows PC: .\\scripts\\build_windows_installer.ps1"
  echo "   yoki: gh auth login && gh workflow run build-windows.yml"
fi

echo ""
echo "=========================================="
echo "Tayyor: $VER ($STAMP)"
echo "  APK: $APK_DST"
echo "  AAB: $AAB_DST"
echo ""
echo "Windows EXE (setup): GitHub Actions → build-windows.yml"
echo "  gh workflow run build-windows.yml"
echo "  yoki Windowsda: .\\scripts\\build_windows_installer.ps1"
echo "=========================================="
