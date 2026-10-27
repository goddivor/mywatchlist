#!/usr/bin/env bash
# verify.sh — the full merge gate of MyWatchList (exit 0 = green).
# Run from the repository root (or a unit worktree).
set -euo pipefail
cd "$(dirname "$0")/.."

# Gradle 8.13 rejects the Java 25 JBR bundled with Android Studio; pin JDK 21 when it exists.
if [ -d /usr/lib/jvm/java-21-openjdk-amd64 ]; then
  export GRADLE_OPTS="${GRADLE_OPTS:-} -Dorg.gradle.java.home=/usr/lib/jvm/java-21-openjdk-amd64"
fi

echo "== flutter pub get"
flutter pub get >/dev/null

echo "== flutter analyze"
flutter analyze

echo "== flutter test"
flutter test

echo "== dart analyze mwl-api"
(cd mwl-api && dart pub get >/dev/null && dart analyze --fatal-infos=false .)

if [ "${MAB_BUILD_APK:-0}" = 1 ]; then
  echo "== flutter build apk --debug"
  flutter build apk --debug
fi

echo "VERIFY OK"
