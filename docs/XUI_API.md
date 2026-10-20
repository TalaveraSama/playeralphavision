# API de XUI.one usada por la app

La app habla con el API **Xtream Codes** que expone el panel XUI.one
(`player_api.php`). Todo es HTTP GET con el usuario y la contraseña en la query.

```
{base}/player_api.php?username=USER&password=PASS[&action=ACCION][&param=valor]
```

| acción | qué devuelve | modelo en `core` |
|---|---|---|
| *(sin acción)* | `user_info` + `server_info` | `LoginResult`, `UserInfo`, `ServerInfo` |
| `get_live_categories` | categorías de TV | `Category` |
| `get_live_streams` | canales (`&category_id=` opcional) | `LiveStream` |
| `get_vod_categories` | categorías de películas | `Category` |
| `get_vod_streams` | películas | `VodStream` |
| `get_vod_info&vod_id=` | sinopsis + extensión real | `VodDetail` |
| `get_series_categories` | categorías de series | `Category` |
| `get_series` | series | `Series` |
| `get_series_info&series_id=` | temporadas y episodios | `SeriesDetail`, `Episode` |
| `get_short_epg&stream_id=&limit=` | guía de un canal | `EpgEntry` |
| `get_simple_data_table&stream_id=` | guía completa | `EpgEntry` |

## Autenticación

`user_info.auth` es `1` si el login es correcto y `0` si no. En ese caso el panel
devuelve además `status` (`Active`, `Expired`, `Disabled`, `Banned`) y `exp_date`
(epoch en segundos; `null` = ilimitado). La app usa eso para decidir si entra o
muestra el error.

## URLs de reproducción

| tipo | plantilla |
|---|---|
| Live | `{base}/live/{user}/{pass}/{stream_id}.m3u8` |
| Película | `{base}/movie/{user}/{pass}/{stream_id}.{container_extension}` |
| Episodio | `{base}/series/{user}/{pass}/{episode.id}.{container_extension}` |
| Catch-up | `{base}/streaming/timeshift.php?username=&password=&stream=&start=&duration=` |
| Playlist M3U | `{base}/get.php?username=&password=&type=m3u_plus&output=ts` |
| EPG XMLTV | `{base}/xmltv.php?username=&password=` |

Detalles que suelen romper las apps hechas a mano:

1. **El episodio se reproduce con su propio `id`**, no con el `series_id`.
   `series_info` devuelve `episodes: {"1": [{"id": "9001", ...}]}`.
2. **La extensión no siempre es `mp4`**: viene en `container_extension` y puede
   ser `mkv`, `avi`, etc. Pedir `.mp4` a un `.mkv` da 404 o stream corrupto.
3. **El EPG viene en base64** (`title`, `description`). Hay que decodificarlo;
   si no, la guía muestra `UHJvZ3JhbWEgZW4gY3Vyc28=`.
4. **`stream_id` puede llegar como string o como número** según la versión del
   panel; el parser tolera ambos.
5. **Categorías vacías** devuelven `{}` en vez de `[]`; hay que tratarlo como
   lista vacía (si no, la app truena al parsear).
6. **`stream_icon`, `cover` y `backdrop_path`** a veces vienen como `"null"`
   (texto) o vacío: se descartan.
7. Los paneles en HTTP en claro siguen siendo la norma; por eso el
   `network_security_config` permite cleartext.

## Serie de pruebas (fixtures)

`mock_xui/server.py --dump mock_xui/fixtures` escribe respuestas reales del mock
para que las pruebas del cliente corran sin red:

```
mock_xui/fixtures/login_ok.json       login_fail.json
live_categories.json  live_streams.json
vod_categories.json   vod_streams.json  vod_info.json
series_categories.json  series.json  series_info.json
epg.json
```

## Probar el API a mano

```bash
tools/run_mock.sh --port 8099 --public-host 127.0.0.1
curl 'http://127.0.0.1:8099/player_api.php?username=demo&password=demo'
curl 'http://127.0.0.1:8099/player_api.php?username=demo&password=demo&action=get_live_streams'
curl 'http://127.0.0.1:8099/live/demo/demo/101.m3u8'
```
