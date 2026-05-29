#!/usr/bin/env bash
# Archive dan OLDIN: pubspec.yaml → ios/Flutter/Generated.xcconfig (versiya/build).
set -euo pipefail
cd "$(dirname "$0")/.."
echo "pubspec: $(grep '^version:' pubspec.yaml)"
flutter pub get
flutter build ios --config-only
echo ""
echo "Generated.xcconfig:"
grep -E 'FLUTTER_BUILD_NAME|FLUTTER_BUILD_NUMBER' ios/Flutter/Generated.xcconfig
echo ""
echo "Keyin Xcode: Runner.xcworkspace → Product → Clean Build Folder → Archive"
