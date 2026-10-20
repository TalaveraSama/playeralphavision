#!/usr/bin/env bash
# Decompila Alpha-Vision APK desde las partes subidas a Google Drive.
#
# Uso:
#   tools/decompile.sh [--out DIR] [--parts DIR]
#
# Espera encontrar en --parts (por defecto ./parts):
#   Alpha-Vision-1.2.21.apk.001 + .002   (7-Zip "Dividir archivo", split)
#   *.z01 *.z02 *.zip                    (ZIP multivolumen: WinRAR/ZArchiver)
#   o el .apk completo.
#
# Requiere: java, apktool.jar (APKTOOL_JAR), python3.
set -euo pipefail

OUT=build/apktool
PARTS=parts
EXPECTED_SIZE=146949715

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)   OUT="$2"; shift 2 ;;
    --parts) PARTS="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "arg desconocido: $1" >&2; exit 2 ;;
  esac
done

# localizar java (PATH, o el JDK de jdk4py)
if [[ -z "${JAVA:-}" ]]; then
  if command -v java >/dev/null 2>&1; then JAVA=java
  else
    JAVA=$(ls /tmp/venv/lib/python*/site-packages/jdk4py/java-runtime/bin/java 2>/dev/null | head -1)
  fi
fi
# localizar apktool.jar (2.9+ recomendado; 2.4 falla con recursos modernos)
if [[ -z "${APKTOOL_JAR:-}" ]]; then
  for c in "$HOME/.local/apktool/apktool.jar" /opt/apktool/apktool.jar "$(dirname "$0")/apktool.jar"; do
    [[ -f "$c" ]] && APKTOOL_JAR="$c" && break
  done
fi
WORK=build
mkdir -p "$WORK"

APK="$WORK/Alpha-Vision.apk"

echo "== 1/4 Reconstruyendo APK desde $PARTS"
if [[ -f "$PARTS/Alpha-Vision-1.2.21.apk" ]]; then
  cp "$PARTS/Alpha-Vision-1.2.21.apk" "$APK"
elif compgen -G "$PARTS/*.001" >/dev/null; then
  cat "$PARTS"/*.0[0-9][0-9] > "$APK"
  echo "   unidas $(compgen -G "$PARTS/*.0[0-9][0-9]" | wc -l) partes (.001...)"
elif compgen -G "$PARTS/*.zip" >/dev/null; then
  # ZIP multivolumen: el .zip es la ultima parte, hay que concatenar en orden.
  for f in "$PARTS"/*.z0[0-9] "$PARTS"/*.zip; do [[ -e "$f" ]] && cat "$f" >> "$APK"; done
  echo "   unidas partes de ZIP multivolumen"
else
  echo "ERROR: no encuentro partes en $PARTS/" >&2; exit 1
fi

SIZE=$(stat -c %s "$APK")
echo "   tamano: $SIZE bytes"
if [[ "$SIZE" != "$EXPECTED_SIZE" ]]; then
  echo "   AVISO: esperaba $EXPECTED_SIZE bytes (diferencia $((SIZE-EXPECTED_SIZE)))" >&2
fi

echo "== 2/4 Verificando ZIP"
python3 - "$APK" <<'PY'
import sys, zipfile
apk = sys.argv[1]
try:
    z = zipfile.ZipFile(apk)
except Exception as e:
    sys.exit(f"ERROR: no es un ZIP valido: {e}")
bad = z.testzip()
if bad:
    sys.exit(f"ERROR: entrada corrupta: {bad}")
names = z.namelist()
print(f"   OK: {len(names)} entradas, testzip limpio")
for key in ("AndroidManifest.xml", "resources.arsc"):
    print(f"   {'OK ' if key in names else 'FALTA'} {key}")
dex = sorted(n for n in names if n.startswith("classes") and n.endswith(".dex"))
libs = [n for n in names if n.startswith("lib/")]
print(f"   dex: {len(dex)} -> {', '.join(dex)}")
print(f"   .so: {len(libs)}")
PY

echo "== 3/4 apktool d"
if [[ -z "${JAVA:-}" || ! -x "$JAVA" ]]; then
  echo "ERROR: no hay java. Instala un JDK o exporta JAVA=/ruta/bin/java" >&2; exit 1
fi
if [[ -z "${APKTOOL_JAR:-}" || ! -f "$APKTOOL_JAR" ]]; then
  echo "ERROR: no encuentro apktool.jar. Exporta APKTOOL_JAR=/ruta/apktool.jar" >&2; exit 1
fi
echo "   java: $JAVA"
echo "   apktool: $APKTOOL_JAR ($("$JAVA" -jar "$APKTOOL_JAR" --version 2>/dev/null))"
rm -rf "$OUT"
if ! "$JAVA" -Xmx3g -jar "$APKTOOL_JAR" d "$APK" -o "$OUT" -f --no-debug-info > "$WORK/apktool.log" 2>&1; then
  tail -30 "$WORK/apktool.log" >&2
  echo "ERROR: apktool fallo. Log completo: $WORK/apktool.log" >&2
  echo "       Prueba: APKTOOL_JAR=/ruta/apktool_2.9.3.jar tools/decompile.sh ..." >&2
  exit 1
fi
tail -12 "$WORK/apktool.log"
echo "   salida: $OUT"

echo "== 4/4 Auditoria"
python3 tools/audit.py --root "$OUT" --apk "$APK" --out AUDIT.md --json build/audit.json \
  || echo "AVISO: audit.py devolvio codigo != 0 (ver salida)"

echo
echo "Listo. Informe: AUDIT.md"
