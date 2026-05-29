#!/usr/bin/env bash
# pubspec.yaml versiyasini ios/Flutter/Generated.xcconfig ga yozadi (Xcode Archive uchun).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUBSPEC="$ROOT/pubspec.yaml"
GEN="$ROOT/ios/Flutter/Generated.xcconfig"

if [ ! -f "$PUBSPEC" ]; then
  echo "error: pubspec.yaml topilmadi: $PUBSPEC" >&2
  exit 1
fi

VER=$(grep '^version:' "$PUBSPEC" | sed 's/version:[[:space:]]*//')
NAME="${VER%%+*}"
NUM="${VER#*+}"

if [ ! -f "$GEN" ]; then
  (cd "$ROOT" && flutter pub get)
fi

if [ ! -f "$GEN" ]; then
  echo "error: Generated.xcconfig yo'q. flutter pub get ishga tushiring." >&2
  exit 1
fi

TMP="${GEN}.tmp"
while IFS= read -r line; do
  case "$line" in
    FLUTTER_BUILD_NAME=*) echo "FLUTTER_BUILD_NAME=$NAME" ;;
    FLUTTER_BUILD_NUMBER=*) echo "FLUTTER_BUILD_NUMBER=$NUM" ;;
    *) echo "$line" ;;
  esac
done < "$GEN" > "$TMP"
mv "$TMP" "$GEN"

echo "iOS version sync: $NAME ($NUM)"
