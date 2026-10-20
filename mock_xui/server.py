#!/usr/bin/env python3
"""Mock del API de XUI.one (Xtream Codes) para desarrollar y probar el player.

Implementa los endpoints reales que usa la app:
  GET /player_api.php?username&password[&action=...]
  GET /get.php                     playlist M3U
  GET /xmltv.php                   EPG XMLTV
  GET /live/{user}/{pass}/{id}.m3u8
  GET /live/{user}/{pass}/segNNN.ts
  GET /movie/{user}/{pass}/{id}.{ext}
  GET /series/{user}/{pass}/{episodeId}.{ext}

Uso:
  python3 mock_xui/server.py --port 8099 [--user demo --pass demo] [--dump fixtures/]
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import posixpath
import re
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(HERE, "media")

STATE = {"user": "demo", "password": "demo", "host": "127.0.0.1", "port": 8099}

SECONDS_DAY = 86_400
NOW = int(time.time())


def b64(text: str) -> str:
    """Xtream manda título/descripción de EPG en base64."""
    return base64.b64encode(text.encode()).decode()


# --------------------------------------------------------------------------- #
# Datos de ejemplo
# --------------------------------------------------------------------------- #
LIVE_CATEGORIES = [
    {"category_id": "1", "category_name": "Deportes", "parent_id": 0},
    {"category_id": "2", "category_name": "Noticias", "parent_id": 0},
    {"category_id": "3", "category_name": "Cine", "parent_id": 0},
]

LIVE_STREAMS = [
    {"num": 1, "name": "ESPN HD", "stream_type": "live", "stream_id": 101, "stream_icon": "",
     "epg_channel_id": "espn.hd", "added": "1700000000", "category_id": "1", "custom_sid": "", "tv_archive": 1,
     "direct_source": "", "tv_archive_duration": 7},
    {"num": 2, "name": "Fox Sports", "stream_type": "live", "stream_id": 102, "stream_icon": "",
     "epg_channel_id": "fox.sports", "added": "1700000000", "category_id": "1", "custom_sid": "", "tv_archive": 0,
     "direct_source": "", "tv_archive_duration": 0},
    {"num": 3, "name": "CNN en Español", "stream_type": "live", "stream_id": 103, "stream_icon": "",
     "epg_channel_id": "cnn.es", "added": "1700000000", "category_id": "2", "custom_sid": "", "tv_archive": 0,
     "direct_source": "", "tv_archive_duration": 0},
    {"num": 4, "name": "TVE Internacional", "stream_type": "live", "stream_id": 104, "stream_icon": "",
     "epg_channel_id": "tve.int", "added": "1700000000", "category_id": "2", "custom_sid": "", "tv_archive": 1,
     "direct_source": "", "tv_archive_duration": 7},
    {"num": 5, "name": "Cine Clásico", "stream_type": "live", "stream_id": 105, "stream_icon": "",
     "epg_channel_id": "cine.clasico", "added": "1700000000", "category_id": "3", "custom_sid": "", "tv_archive": 0,
     "direct_source": "", "tv_archive_duration": 0},
    {"num": 6, "name": "Canal 6 Nicaragua", "stream_type": "live", "stream_id": 106, "stream_icon": "",
     "epg_channel_id": "canal6.ni", "added": "1700000000", "category_id": "2", "custom_sid": "", "tv_archive": 0,
     "direct_source": "", "tv_archive_duration": 0},
]

VOD_CATEGORIES = [
    {"category_id": "10", "category_name": "Acción", "parent_id": 0},
    {"category_id": "11", "category_name": "Comedia", "parent_id": 0},
]

VOD_STREAMS = [
    {"num": 1, "name": "El Último Guardián", "stream_type": "movie", "stream_id": 201,
     "stream_icon": "", "rating": "7.4", "rating_5based": 3.7, "added": "1710000000", "is_adult": "0",
     "category_id": "10", "container_extension": "mp4", "custom_sid": "", "direct_source": ""},
    {"num": 2, "name": "Risa Sin Fin", "stream_type": "movie", "stream_id": 202,
     "stream_icon": "", "rating": "6.1", "rating_5based": 3.0, "added": "1710000000", "is_adult": "0",
     "category_id": "11", "container_extension": "mp4", "custom_sid": "", "direct_source": ""},
]

SERIES_CATEGORIES = [{"category_id": "20", "category_name": "Drama", "parent_id": 0}]

SERIES_LIST = [
    {"num": 1, "name": "Nicaragua Salvaje", "series_id": 301, "cover": "", "plot": "Documental.",
     "cast": "Varios", "director": "Anónimo", "genre": "Documental", "releaseDate": "2024-01-15",
     "last_modified": "1710000000", "rating": "8.2", "rating_5based": 4.1, "backdrop_path": [],
     "youtube_trailer": "", "episode_run_time": "45", "category_id": "20"},
    {"num": 2, "name": "La Finca", "series_id": 302, "cover": "", "plot": "Serie rural.",
     "cast": "Varios", "director": "Anónimo", "genre": "Drama", "releaseDate": "2023-06-01",
     "last_modified": "1710000000", "rating": "7.0", "rating_5based": 3.5, "backdrop_path": [],
     "youtube_trailer": "", "episode_run_time": "30", "category_id": "20"},
]

EPISODES = {
    "301": {
        "1": [{"id": "9001", "episode_num": 1, "title": "El río", "container_extension": "mp4",
               "info": {"plot": "Arranca el documental.", "duration": "45 min", "movie_image": ""}},
              {"id": "9002", "episode_num": 2, "title": "La selva", "container_extension": "mp4",
               "info": {"plot": "Selva tropical.", "duration": "45 min", "movie_image": ""}}],
        "2": [{"id": "9003", "episode_num": 1, "title": "Volcanes", "container_extension": "mp4",
               "info": {"plot": "Temporada 2.", "duration": "45 min", "movie_image": ""}}],
    },
    "302": {
        "1": [{"id": "9010", "episode_num": 1, "title": "La cosecha", "container_extension": "mp4",
               "info": {"plot": "Primer capítulo.", "duration": "30 min", "movie_image": ""}}],
    },
}


def epg_listings(stream_id: int):
    """Dos programas por canal, con el formato exacto de Xtream (título en base64)."""
    base = NOW - NOW % 3600  # inicio de la hora actual
    return [
        {"id": f"{stream_id}0001", "epg_id": stream_id, "title": b64("Programa en curso"),
         "lang": "es", "start": time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(base)),
         "end": time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(base + 3600)),
         "description": b64("Transmisión en directo de prueba."),
         "channel_id": f"ch{stream_id}", "start_timestamp": str(base), "stop_timestamp": str(base + 3600),
         "now_playing": 1, "has_archive": 1},
        {"id": f"{stream_id}0002", "epg_id": stream_id, "title": b64("Próximo programa"),
         "lang": "es", "start": time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(base + 3600)),
         "end": time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(base + 7200)),
         "description": b64("Programa siguiente."),
         "channel_id": f"ch{stream_id}", "start_timestamp": str(base + 3600), "stop_timestamp": str(base + 7200),
         "now_playing": 0, "has_archive": 0},
    ]


def user_info(authed: bool):
    info = {
        "username": STATE["user"] if authed else "",
        "password": STATE["password"] if authed else "",
        "message": "" if authed else "Invalid username or password",
        "auth": 1 if authed else 0,
        "status": "Active" if authed else "Disabled",
        "exp_date": str(NOW + 365 * SECONDS_DAY) if authed else None,
        "is_trial": "0",
        "active_cons": "1",
        "created_at": str(NOW - 30 * SECONDS_DAY),
        "max_connections": "2",
        "allowed_output_formats": ["m3u8", "ts"],
    }
    server = {
        "url": STATE["host"], "port": str(STATE["port"]), "https_port": "",
        "server_protocol": "http", "rtmp_port": "25462",
        "timezone": "America/Managua", "timestamp_now": NOW,
        "time_now": time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(NOW)),
        "process": True,
    }
    return {"user_info": info, "server_info": server}


def handle_action(action: str, q: dict):
    """Devuelve (payload, tipo) donde tipo es 'json' o 'text'."""
    cat = q.get("category_id", [None])[0]
    if action == "get_live_categories":
        return LIVE_CATEGORIES, "json"
    if action == "get_vod_categories":
        return VOD_CATEGORIES, "json"
    if action == "get_series_categories":
        return SERIES_CATEGORIES, "json"
    if action == "get_live_streams":
        rows = LIVE_STREAMS if not cat else [s for s in LIVE_STREAMS if s["category_id"] == cat]
        return rows, "json"
    if action == "get_vod_streams":
        rows = VOD_STREAMS if not cat else [s for s in VOD_STREAMS if s["category_id"] == cat]
        return rows, "json"
    if action == "get_series":
        rows = SERIES_LIST if not cat else [s for s in SERIES_LIST if s["category_id"] == cat]
        return rows, "json"
    if action == "get_series_info":
        sid = q.get("series_id", [""])[0]
        if sid not in EPISODES:
            return {}, "json"
        info = next((s for s in SERIES_LIST if str(s["series_id"]) == sid), {})
        return {"seasons": [], "info": info, "episodes": EPISODES[sid]}, "json"
    if action == "get_vod_info":
        vid = q.get("vod_id", [""])[0]
        movie = next((m for m in VOD_STREAMS if str(m["stream_id"]) == vid), None)
        if movie is None:
            return {}, "json"
        return {"info": {"movie_image": movie["stream_icon"], "plot": "Sinopsis de prueba.",
                         "cast": "Reparto", "director": "Director", "genre": "Acción",
                         "releasedate": "2024-05-01", "rating": movie["rating"], "duration": "1h 45min",
                         "backdrop_path": "", "youtube_trailer": ""},
                "movie_data": movie}, "json"
    if action == "get_short_epg":
        sid = int(q.get("stream_id", ["0"])[0] or 0)
        return {"epg_listings": epg_listings(sid)}, "json"
    if action == "get_simple_data_table":
        sid = int(q.get("stream_id", ["0"])[0] or 0)
        return {"epg_listings": epg_listings(sid)}, "json"
    return [], "json"


def m3u_playlist() -> str:
    base = f"http://{STATE['host']}:{STATE['port']}"
    u, p = STATE["user"], STATE["password"]
    lines = ["#EXTM3U"]
    for s in LIVE_STREAMS:
        lines.append(f'#EXTINF:-1 tvg-id="{s["epg_channel_id"]}" tvg-name="{s["name"]}" '
                     f'group-title="{next(c["category_name"] for c in LIVE_CATEGORIES if c["category_id"] == s["category_id"])}",'
                     f'{s["name"]}')
        lines.append(f"{base}/live/{u}/{p}/{s['stream_id']}.m3u8")
    for m in VOD_STREAMS:
        lines.append(f'#EXTINF:-1 tvg-name="{m["name"]}" group-title="Peliculas",{m["name"]}')
        lines.append(f"{base}/movie/{u}/{p}/{m['stream_id']}.mp4")
    return "\n".join(lines) + "\n"


def xmltv() -> str:
    base = NOW - NOW % 3600
    out = ['<?xml version="1.0" encoding="UTF-8"?>', '<tv generator-info-name="mock-xui">']
    for s in LIVE_STREAMS:
        out.append(f'  <channel id="{s["epg_channel_id"]}"><display-name>{s["name"]}</display-name></channel>')
    for s in LIVE_STREAMS:
        for e in epg_listings(s["stream_id"]):
            out.append(f'  <programme start="{time.strftime("%Y%m%d%H%M%S", time.gmtime(base))} +0000" '
                       f'stop="{time.strftime("%Y%m%d%H%M%S", time.gmtime(base + 3600))} +0000" '
                       f'channel="{s["epg_channel_id"]}"><title>{base64.b64decode(e["title"]).decode()}</title></programme>')
    out.append("</tv>")
    return "\n".join(out)


# --------------------------------------------------------------------------- #
# HTTP
# --------------------------------------------------------------------------- #
class Handler(BaseHTTPRequestHandler):
    server_version = "MockXUI/1.0"

    def log_message(self, fmt, *args):  # silencioso salvo errores
        if args and str(args[1]).startswith(("4", "5")):
            sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    # -- helpers ----------------------------------------------------------- #
    def _send(self, code: int, body: bytes, ctype: str, extra: dict | None = None):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def _json(self, payload, code: int = 200):
        self._send(code, json.dumps(payload, ensure_ascii=False).encode(), "application/json; charset=utf-8")

    def _file(self, path: str, ctype: str, range_header: str | None):
        if not os.path.isfile(path):
            return self._json({"error": "not found"}, 404)
        size = os.path.getsize(path)
        if range_header:
            m = re.match(r"bytes=(\d*)-(\d*)", range_header)
            if m:
                start = int(m.group(1) or 0)
                end = int(m.group(2) or size - 1)
                end = min(end, size - 1)
                with open(path, "rb") as fh:
                    fh.seek(start)
                    chunk = fh.read(end - start + 1)
                self.send_response(206)
                self.send_header("Content-Type", ctype)
                self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
                self.send_header("Accept-Ranges", "bytes")
                self.send_header("Content-Length", str(len(chunk)))
                self.end_headers()
                self.wfile.write(chunk)
                return
        with open(path, "rb") as fh:
            body = fh.read()
        self._send(200, body, ctype, {"Accept-Ranges": "bytes"})

    # -- rutas ------------------------------------------------------------- #
    def do_HEAD(self):
        self.do_GET()

    def do_GET(self):
        url = urlparse(self.path)
        q = parse_qs(url.query)
        path = url.path
        rng = self.headers.get("Range")

        if path.endswith("player_api.php"):
            user = q.get("username", [""])[0]
            pwd = q.get("password", [""])[0]
            if user != STATE["user"] or pwd != STATE["password"]:
                return self._json(user_info(False))
            action = q.get("action", [""])[0]
            if not action:
                return self._json(user_info(True))
            payload, _ = handle_action(action, q)
            return self._json(payload)

        if path.endswith("get.php"):
            if q.get("username", [""])[0] != STATE["user"]:
                return self._send(401, b"unauthorized", "text/plain")
            return self._send(200, m3u_playlist().encode(), "audio/x-mpegurl")

        if path.endswith("xmltv.php"):
            return self._send(200, xmltv().encode(), "application/xml")

        if path.endswith("timeshift.php"):
            return self._file(os.path.join(MEDIA, "movies", "sample.mp4"), "video/mp4", rng)

        # /live/{u}/{p}/{file}
        m = re.match(r"^/live/([^/]+)/([^/]+)/(.+)$", path)
        if m:
            if (m.group(1), m.group(2)) != (STATE["user"], STATE["password"]):
                return self._send(403, b"forbidden", "text/plain")
            name = posixpath.basename(m.group(3))
            if name.endswith(".m3u8"):
                return self._file(os.path.join(MEDIA, "live", "index.m3u8"), "application/vnd.apple.mpegurl", rng)
            if name.endswith(".ts"):
                return self._file(os.path.join(MEDIA, "live", name), "video/mp2t", rng)
            return self._json({"error": "unsupported"}, 404)

        # /movie/{u}/{p}/{id}.{ext}  y  /series/{u}/{p}/{ep}.{ext}
        m = re.match(r"^/(movie|series)/([^/]+)/([^/]+)/([^/]+)\.(\w+)$", path)
        if m:
            if (m.group(2), m.group(3)) != (STATE["user"], STATE["password"]):
                return self._send(403, b"forbidden", "text/plain")
            return self._file(os.path.join(MEDIA, "movies", "sample.mp4"), "video/mp4", rng)

        if path in ("/", "/health"):
            return self._send(200, b"mock xui ok", "text/plain")

        return self._json({"error": "not found", "path": path}, 404)


def dump_fixtures(directory: str):
    """Guarda respuestas de ejemplo para tests offline del cliente Kotlin."""
    os.makedirs(directory, exist_ok=True)
    samples = {
        "login_ok.json": user_info(True),
        "login_fail.json": user_info(False),
        "live_categories.json": LIVE_CATEGORIES,
        "live_streams.json": LIVE_STREAMS,
        "vod_categories.json": VOD_CATEGORIES,
        "vod_streams.json": VOD_STREAMS,
        "series_categories.json": SERIES_CATEGORIES,
        "series.json": SERIES_LIST,
        "series_info.json": {"seasons": [], "info": SERIES_LIST[0], "episodes": EPISODES["301"]},
        "epg.json": {"epg_listings": epg_listings(101)},
        "vod_info.json": {"info": {"plot": "Sinopsis de prueba.", "duration": "1h 45min",
                                   "rating": "7.4", "genre": "Acción", "releasedate": "2024-05-01"},
                          "movie_data": VOD_STREAMS[0]},
    }
    for name, payload in samples.items():
        with open(os.path.join(directory, name), "w", encoding="utf-8") as fh:
            json.dump(payload, fh, ensure_ascii=False, indent=2)
    print(f"fixtures escritos en {directory}/ ({len(samples)} archivos)")


def main() -> int:
    ap = argparse.ArgumentParser(description="Mock del API de XUI.one")
    ap.add_argument("--port", type=int, default=8099)
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--public-host", default="127.0.0.1",
                    help="host que se anuncia en las URLs de los streams (IP de tu PC en la LAN)")
    ap.add_argument("--user", default="demo")
    ap.add_argument("--pass", dest="password", default="demo")
    ap.add_argument("--dump", metavar="DIR", help="escribe fixtures JSON y sale")
    a = ap.parse_args()

    STATE.update(user=a.user, password=a.password, host=a.public_host, port=a.port)

    if a.dump:
        dump_fixtures(a.dump)
        return 0

    if not os.path.isfile(os.path.join(MEDIA, "live", "index.m3u8")):
        print("AVISO: falta media/. Ejecuta mock_xui/make_media.sh", file=sys.stderr)

    httpd = ThreadingHTTPServer((a.host, a.port), Handler)
    print(f"Mock XUI escuchando en http://{a.host}:{a.port}")
    print(f"  usuario: {a.user}  contraseña: {a.password}")
    print(f"  URL para la app: http://{a.public_host}:{a.port}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nbye")
    return 0


if __name__ == "__main__":
    sys.exit(main())
