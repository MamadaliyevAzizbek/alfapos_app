#!/usr/bin/env bash
# Xcode → Archive dan oldin ishga tushiring: pubspec.yaml versiyasi Generated.xcconfig ga yoziladi.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "pubspec: $(grep '^version:' pubspec.yaml)"
flutter pub get
flutter build ios --release --no-codesign
echo "Generated.xcconfig:"
grep -E 'FLUTTER_BUILD_NAME|FLUTTER_BUILD_NUMBER' ios/Flutter/Generated.xcconfig
echo "Endi Xcode: Product → Archive"
