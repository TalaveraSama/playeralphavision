# playeralphavision

Espacio de trabajo para **decompilar y auditar** `Alpha-Vision-1.2.21.apk` (app del
usuario, ~140 MiB).

- Código decompilado: se publicará en `decompiled/` cuando el APK esté disponible.
- Informe de lo que le falta al código: `AUDIT.md`.

## Estado

| paso | estado |
|---|---|
| Toolchain (Java 25 + apktool 2.9.3 + androguard 4.1.4) | ✅ |
| Pipeline de decompilación y auditoría | ✅ probado con APK real |
| APK recibido | ⏳ pendiente (Drive rechaza >100 MiB; se sube en 2 partes) |

## Cómo se ejecuta

```bash
# 1. Deja las partes en ./parts/
#    Alpha-Vision-1.2.21.apk.001 + .002   (7-Zip "Dividir archivo")
#    o *.z01 *.z02 *.zip                  (ZIP multivolumen)
# o el APK completo: parts/Alpha-Vision-1.2.21.apk

# 2. Decompilar + auditar
APKTOOL_JAR=/ruta/apktool.jar tools/decompile.sh --parts parts --out decompiled/apktool
```

Genera:

- `decompiled/apktool/` — smali, `res/`, `AndroidManifest.xml`, `assets/`, `lib/`
- `AUDIT.md` — informe legible
- `build/audit.json` — hallazgos en JSON

Variables: `JAVA`, `APKTOOL_JAR` (se autodetectan en `~/.local/apktool/`,
`/opt/apktool/` o junto al script).

## Qué busca la auditoría (`tools/audit.py`)

Detección de **código que falta o está roto**, no solo estilo:

| área | qué comprueba |
|---|---|
| `clases faltantes` | actividades/servicios/receivers/providers declarados en el manifest sin `.smali` (componente borrado o manifest desincronizado) |
| `nativas` | `System.loadLibrary("x")` sin `lib/libx.so` → crash `UnsatisfiedLinkError`; `.so` presentes solo en algunas ABIs |
| `recursos` | `@string/…`, `@drawable/…`, `@layout/…` referenciados en XML que no existen; IDs `0x7f……` usados en smali que no están en `public.xml` |
| `reflexion` | `Class.forName("…")` sobre clases del propio APK que no existen (módulos eliminados, licencias/paywalls quitados) |
| `assets` | ficheros (`config.json`, `.html`, `.dat`, …) referenciados en el código pero ausentes en `assets/` |
| `ofuscación` | % de clases con nombres de 1–2 letras (R8/ProGuard: el código está, pero ilegible) |
| `superficie` | componentes exportados y permisos sensibles |
| `apk` | DEX presentes, integridad del ZIP, firma v1 |

Código de salida `1` si hay algún hallazgo `CRITICO`.

## Requisitos

- JDK 17+ (probado con Temurin 25)
- `apktool.jar` 2.9+ (2.4 falla con `resources.arsc` modernos)
- Python 3.9+ (solo stdlib para la auditoría)

Opcional, como respaldo si apktool falla: `pip install androguard falcon`.
