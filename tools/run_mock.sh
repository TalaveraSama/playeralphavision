#!/usr/bin/env bash
# Levanta el mock del API XUI (genera media de prueba si falta).
#   tools/run_mock.sh [--port 8099] [--public-host 192.168.1.50]
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -f mock_xui/media/live/index.m3u8 ]]; then
  echo "== generando media de prueba"
  FFMPEG="${FFMPEG:-ffmpeg}" mock_xui/make_media.sh
fi
exec python3 mock_xui/server.py "$@"
