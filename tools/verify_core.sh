#!/usr/bin/env bash
# Compila y ejecuta las pruebas del módulo `core` (Kotlin puro, sin Android).
#
#   tools/verify_core.sh                    solo fixtures (offline)
#   tools/verify_core.sh http://127.0.0.1:8099   además integración contra el mock
#
# Requiere kotlinc en PATH o KOTLINC=/ruta/kotlinc (el JDK puede venir de jdk4py).
set -euo pipefail
cd "$(dirname "$0")/.."

KOTLINC="${KOTLINC:-kotlinc}"
if ! command -v "$KOTLINC" >/dev/null 2>&1; then
  for c in /tmp/kc/package/bin/kotlinc "$HOME/.local/kotlinc/bin/kotlinc"; do
    [[ -x "$c" ]] && KOTLINC="$c" && break
  done
fi
[[ -x "$KOTLINC" || -n "$(command -v "$KOTLINC" || true)" ]] || {
  echo "ERROR: falta kotlinc (exporta KOTLINC=/ruta/bin/kotlinc)" >&2; exit 1; }

if [[ -z "${JAVA_HOME:-}" ]]; then
  JAVA_HOME="$(ls -d /tmp/venv/lib/python*/site-packages/jdk4py/java-runtime 2>/dev/null | head -1)"
  [[ -n "$JAVA_HOME" ]] && export JAVA_HOME && export PATH="$JAVA_HOME/bin:$PATH"
fi

OUT="build/core-check.jar"
mkdir -p build

echo "== compilando core + arnés de pruebas"
"$KOTLINC" android/core/src/main/kotlin/com/alphavision/core/*.kt dev/CoreCheck.kt \
  -include-runtime -d "$OUT" 2>&1 | grep -v "^warning:" || true
[[ -f "$OUT" ]] || { echo "ERROR: no se generó $OUT" >&2; exit 1; }

echo "== pruebas offline (fixtures)"
"${JAVA_HOME:+$JAVA_HOME/bin/}java" -jar "$OUT" mock_xui/fixtures "${1:-}"
