#!/usr/bin/env bash
# Genera media de prueba (HLS para live + MP4 para VOD/series) con ffmpeg.
# Uso: mock_xui/make_media.sh   (requiere ffmpeg en PATH o FFMPEG=/ruta/ffmpeg)
set -euo pipefail
cd "$(dirname "$0")"
FF="${FFMPEG:-ffmpeg}"
command -v "$FF" >/dev/null 2>&1 || { echo "ERROR: falta ffmpeg (o exporta FFMPEG=/ruta/ffmpeg)" >&2; exit 1; }

mkdir -p media/live media/movies
echo "== HLS (live)"
rm -f media/live/*.ts media/live/index.m3u8
"$FF" -hide_banner -loglevel error -y \
  -f lavfi -i "testsrc2=size=640x360:rate=25" \
  -f lavfi -i "sine=frequency=440:sample_rate=44100" \
  -t 24 -c:v libx264 -preset veryfast -g 50 -pix_fmt yuv420p -c:a aac -b:a 96k -shortest \
  -f hls -hls_time 4 -hls_list_size 0 -hls_playlist_type vod \
  -hls_segment_filename 'media/live/seg%03d.ts' media/live/index.m3u8

echo "== MP4 (VOD / series)"
"$FF" -hide_banner -loglevel error -y \
  -f lavfi -i "testsrc2=size=640x360:rate=25" \
  -f lavfi -i "sine=frequency=660:sample_rate=44100" \
  -t 20 -c:v libx264 -preset veryfast -pix_fmt yuv420p -c:a aac -b:a 96k -shortest \
  -movflags +faststart media/movies/sample.mp4

echo "OK:"
ls -la media/live | head -5
ls -la media/movies
