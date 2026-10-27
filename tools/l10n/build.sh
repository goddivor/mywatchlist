#!/usr/bin/env bash
# build.sh — regenerate the S localization class from the ARB sources.
#
#   tools/heavy.sh tools/l10n/build.sh [--force]
#
# Merges the base ARBs (lib/l10n/intl_<locale>.arb) with every unit fragment
# (lib/l10n/units/<unit-id>/intl_<locale>.arb), validates them (duplicate keys, missing English,
# unknown locale, bad key) and writes lib/generated/l10n.dart + lib/generated/intl/.
# The merged ARBs (.dart_tool/mwl_l10n/) and the generated files are build outputs, git-ignored.
# Skips the work when no source changed since the last run (--force regenerates anyway).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TOOL="$ROOT/tools/l10n"
STAMP="$ROOT/.dart_tool/mwl_l10n.stamp"
cd "$ROOT"

sources_hash() {
  {
    find lib/l10n -type f -name '*.arb' -print0 | sort -z | xargs -0 sha256sum
    sha256sum "$TOOL/bin/build.dart" "$TOOL/pubspec.yaml" "$TOOL/pubspec.lock" 2>/dev/null || true
  } | sha256sum | cut -d' ' -f1
}

HASH="$(sources_hash)"
if [ "${1:-}" != "--force" ] && [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$HASH" ] \
  && [ -f lib/generated/l10n.dart ] && [ -f lib/generated/intl/messages_all.dart ]; then
  echo "[l10n] up to date"
  exit 0
fi

(cd "$TOOL" && dart pub get >/dev/null)
(cd "$TOOL" && dart run bin/build.dart "$ROOT")
mkdir -p "$(dirname "$STAMP")"
sources_hash >"$STAMP"
