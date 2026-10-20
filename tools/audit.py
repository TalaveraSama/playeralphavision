#!/usr/bin/env python3
"""Auditoria de un APK decompilado con apktool.

Busca especificamente lo que "falta": clases referenciadas pero ausentes,
recursos sin resolver, librerias nativas faltantes, assets inexistentes,
codigo cargado por reflexion que no existe y senales de ofuscacion/recorte.

Solo stdlib. Uso:
    python3 tools/audit.py --root build/apktool [--apk build/Alpha-Vision.apk]
                           [--out AUDIT.md] [--json build/audit.json]
"""
from __future__ import annotations

import argparse
import collections
import functools
import json
import os
import re
import sys
import zipfile
from xml.etree import ElementTree as ET

ANDROID_NS = "{http://schemas.android.com/apk/res/android}"
# Prefijos que suelen venir de AAR/JAR de terceros: su ausencia no es "codigo robado".
THIRD_PARTY = (
    "android.", "androidx.", "android.support.", "java.", "javax.", "kotlin",
    "kotlinx.", "dalvik.", "org.intellij.", "org.jetbrains.",
)
RES_REF = re.compile(r"@(\+?)([a-zA-Z0-9_.]+)/([A-Za-z0-9_.]+)")
HEX_ID = re.compile(r"\b0x7f[0-9a-fA-F]{6}\b")
CLASS_DESC = re.compile(r"^L([\w$/]+);$")
FQN = re.compile(r"^[a-zA-Z_$][\w$]*(\.[a-zA-Z_$][\w$]*)+$")


@functools.lru_cache(maxsize=4096)
def read_smali(path: str) -> str:
    try:
        with open(path, "r", errors="ignore") as fh:
            return fh.read()
    except OSError:
        return ""


def is_third_party(fqcn: str) -> bool:
    return fqcn.startswith(THIRD_PARTY) or "androidx" in fqcn.split(".")[:3]


class Result:
    def __init__(self) -> None:
        self.findings: list[dict] = []
        self.stats: dict = {}
        self.info: dict = {}

    def add(self, sev: str, area: str, msg: str, detail: list[str] | None = None) -> None:
        self.findings.append(
            {"severity": sev, "area": area, "message": msg, "detail": (detail or [])[:40]}
        )


# --------------------------------------------------------------------------- #
# Indexado del arbol decompilado
# --------------------------------------------------------------------------- #
def index_smali(root: str) -> tuple[dict[str, str], list[str]]:
    """Devuelve {clase: ruta} y lista de dirs smali*."""
    classes: dict[str, str] = {}
    smali_dirs: list[str] = []
    for entry in sorted(os.listdir(root)):
        d = os.path.join(root, entry)
        if not os.path.isdir(d) or not (entry == "smali" or entry.startswith("smali_")):
            continue
        smali_dirs.append(entry)
        for dirpath, _dirnames, filenames in os.walk(d):
            for fn in filenames:
                if not fn.endswith(".smali"):
                    continue
                rel = os.path.relpath(os.path.join(dirpath, fn), d)[: -len(".smali")]
                cls = rel.replace(os.sep, ".")
                classes.setdefault(cls, os.path.relpath(os.path.join(dirpath, fn), root))
    return classes, smali_dirs


def parse_manifest(root: str) -> tuple[ET.Element | None, str | None]:
    path = os.path.join(root, "AndroidManifest.xml")
    if not os.path.isfile(path):
        return None, "AndroidManifest.xml no encontrado en la salida de apktool"
    try:
        return ET.parse(path).getroot(), None
    except ET.ParseError as e:
        return None, f"AndroidManifest.xml ilegible: {e}"


def attr(el: ET.Element, name: str) -> str | None:
    return el.get(ANDROID_NS + name) or el.get(name)


def index_resources(root: str) -> tuple[dict[tuple[str, str], str], dict[str, str]]:
    """(type,name)->fichero y {0x...: nombre} desde res/values/public.xml."""
    res: dict[tuple[str, str], str] = {}
    public_ids: dict[str, str] = {}
    resdir = os.path.join(root, "res")
    if not os.path.isdir(resdir):
        return res, public_ids
    for entry in os.listdir(resdir):
        p = os.path.join(resdir, entry)
        if not os.path.isdir(p):
            continue
        if entry.startswith("values"):
            for fn in os.listdir(p):
                if not fn.endswith(".xml"):
                    continue
                fpath = os.path.join(p, fn)
                try:
                    tree = ET.parse(fpath)
                except ET.ParseError:
                    continue
                for el in tree.getroot():
                    name = el.get("name")
                    if not name:
                        continue
                    if el.tag == "public" and el.get("type") and el.get("id"):
                        public_ids[el.get("id").lower()] = f"{el.get('type')}/{name}"
                        res.setdefault((el.get("type"), name), os.path.relpath(fpath, root))
                    else:
                        typ = el.get("type") if el.tag in ("item", "public") else el.tag
                        res.setdefault((typ or el.tag, name), os.path.relpath(fpath, root))
        else:
            rtype = entry.split("-")[0]
            for fn in os.listdir(p):
                res.setdefault((rtype, fn.split(".")[0]), os.path.relpath(os.path.join(p, fn), root))
    return res, public_ids


def iter_xml(path: str):
    try:
        for _ev, el in ET.iterparse(path, events=("start",)):
            yield el
    except ET.ParseError:
        return


# --------------------------------------------------------------------------- #
# Comprobaciones
# --------------------------------------------------------------------------- #
def check_manifest(res: Result, root: str, classes: dict[str, str]) -> None:
    man, err = parse_manifest(root)
    if man is None:
        res.add("CRITICO", "manifest", err or "manifest ausente")
        return
    pkg = man.get("package") or "?"
    res.info["package"] = pkg
    res.info["versionName"] = attr(man, "versionName")
    res.info["versionCode"] = attr(man, "versionCode")

    uses_sdk = man.find("uses-sdk")
    if uses_sdk is not None:
        res.info["minSdk"] = attr(uses_sdk, "minSdkVersion")
        res.info["targetSdk"] = attr(uses_sdk, "targetSdkVersion")
    app = man.find("application")
    if app is None:
        res.add("CRITICO", "manifest", "no hay <application>")
        return
    res.info["appLabel"] = attr(app, "label")
    res.info["allowBackup"] = attr(app, "allowBackup")
    res.info["debuggable"] = attr(app, "debuggable")
    res.info["usesCleartextTraffic"] = attr(app, "usesCleartextTraffic")
    res.info["networkSecurityConfig"] = attr(app, "networkSecurityConfig")

    sev_map = {"activity": "ALTO", "service": "ALTO", "receiver": "MEDIO", "provider": "ALTO"}
    comps: list[tuple[str, str, bool]] = []
    for tag, sev in sev_map.items():
        for el in app.findall(tag):
            name = attr(el, "name")
            if not name:
                continue
            exported = (attr(el, "exported") or "").lower() == "true"
            comps.append((tag, name, exported))
            fqcn = name if name.startswith(pkg) else (pkg + name if name.startswith(".") else (pkg + "." + name if "." not in name else name))
            if fqcn not in classes and not is_third_party(fqcn):
                res.add(sev, "clases faltantes", f"{tag} declarado pero sin smali: {fqcn}",
                        ["posible componente eliminado/renombrado o manifest sin actualizar"])
            if exported and tag in ("activity", "service", "receiver", "provider"):
                res.add("MEDIO", "superficie", f"{tag} exportado: {fqcn}",
                        ["verificar si necesita permiso/validacion"])
    res.stats["componentes"] = len(comps)
    res.stats["componentes_exportados"] = sum(1 for c in comps if c[2])

    if not classes:
        res.add("CRITICO", "codigo", "no hay directorios smali: el APK no trae DEX o apktool no los decodifico")
    else:
        main = None
        for tag in ("activity", "activity-alias"):
            for el in app.findall(tag):
                if (attr(el, "name") or "") in (".MainActivity", "MainActivity") or "launcher" in str(el.attrib):
                    main = attr(el, "name")
        if main and main not in (".MainActivity",):
            pass

    perms = [attr(p, "name") or "" for p in man.findall("uses-permission")]
    res.stats["permisos"] = len(perms)
    dangerous = [p for p in perms if p.split(".")[-1] in {
        "READ_SMS", "RECEIVE_SMS", "SEND_SMS", "READ_PHONE_STATE", "READ_CONTACTS",
        "ACCESS_FINE_LOCATION", "ACCESS_COARSE_LOCATION", "RECORD_AUDIO", "CAMERA",
        "READ_EXTERNAL_STORAGE", "WRITE_EXTERNAL_STORAGE", "MANAGE_EXTERNAL_STORAGE",
        "REQUEST_INSTALL_PACKAGES", "SYSTEM_ALERT_WINDOW", "QUERY_ALL_PACKAGES"}]
    if dangerous:
        res.add("MEDIO", "permisos", "permisos sensibles declarados", dangerous)


def check_native(res: Result, root: str, classes: dict[str, str]) -> None:
    libdir = os.path.join(root, "lib")
    abis: dict[str, set[str]] = {}
    if os.path.isdir(libdir):
        for abi in sorted(os.listdir(libdir)):
            p = os.path.join(libdir, abi)
            if os.path.isdir(p):
                abis[abi] = {f for f in os.listdir(p) if f.endswith(".so")}
    res.stats["abis"] = {k: len(v) for k, v in abis.items()}
    res.info["abis"] = sorted(abis)
    if not abis:
        return
    base = max(abis, key=lambda a: len(abis[a]))
    for abi, libs in abis.items():
        missing = abis[base] - libs
        if missing:
            res.add("ALTO", "nativas", f"faltan .so en {abi} que si estan en {base}", sorted(missing))

    lib_re = re.compile(
        r'const-string(?:/jumbo)?\s+[vp]\d+,\s*"([^"]+)"[^\n]*\n(?:\s*[^\n]*\n){0,2}?[^\n]*loadLibrary',
        re.MULTILINE,
    )
    wanted: collections.Counter[str] = collections.Counter()
    for cls, relpath in classes.items():
        text = read_smali(os.path.join(root, relpath))
        if "loadLibrary" not in text:
            continue
        for m in lib_re.finditer(text):
            wanted[m.group(1)] += 1
    allso = set().union(*abis.values()) if abis else set()
    for name in wanted:
        so = f"lib{name}.so"
        if so not in allso:
            res.add("ALTO", "nativas", f'System.loadLibrary("{name}") sin lib/{so}',
                    ["el codigo java existe pero la libreria nativa no: crash UnsatisfiedLinkError"])


def check_resources(res: Result, root: str, classes: dict[str, str]) -> None:
    resmap, public_ids = index_resources(root)
    res.stats["recursos"] = len(resmap)
    res.stats["ids_publicos"] = len(public_ids)
    missing: collections.Counter[str] = collections.Counter()
    scanned = 0
    for base, _dirs, files in os.walk(root):
        if os.path.basename(base) in ("smali", "assets", "lib"):
            continue
        if not (base == root or base.startswith(os.path.join(root, "res"))):
            continue
        for fn in files:
            if not fn.endswith(".xml"):
                continue
            scanned += 1
            for _el in iter_xml(os.path.join(base, fn)):
                # todos los atributos, con o sin namespace, no solo una lista fija
                for key, val in _el.attrib.items():
                    if not val or "@" not in val:
                        continue
                    for m in RES_REF.finditer(val):
                        typ, name = m.group(2), m.group(3)
                        if typ == "android":
                            continue
                        if (typ, name) not in resmap:
                            missing[f"@{typ}/{name}"] += 1
                if _el.text and "@" in _el.text:
                    for m in RES_REF.finditer(_el.text):
                        typ, name = m.group(2), m.group(3)
                        if typ != "android" and (typ, name) not in resmap:
                            missing[f"@{typ}/{name}"] += 1
    res.stats["xml_escaneados"] = scanned
    if missing:
        res.add("ALTO", "recursos", f"{len(missing)} referencias a recursos inexistentes",
                [f"{k} (x{v})" for k, v in missing.most_common(40)])

    if public_ids:
        unresolved: collections.Counter[str] = collections.Counter()
        total = 0
        for cls, relpath in classes.items():
            text = read_smali(os.path.join(root, relpath))
            for m in HEX_ID.finditer(text):
                # descarta mascaras/sentinelas (0x7f000000, 0x7f7fffff...) que no son recursos
                val = int(m.group(0), 16)
                type_id = (val >> 16) & 0xFF
                if not 1 <= type_id <= 0x1E or val & 0xFFFF == 0:
                    continue
                total += 1
                if m.group(0).lower() not in public_ids:
                    unresolved[m.group(0).lower()] += 1
        res.stats["ids_referenciados_smali"] = total
        if unresolved:
            res.add("MEDIO", "recursos",
                    f"{len(unresolved)} IDs (0x7f....) usados en smali que no existen en public.xml",
                    [f"{k} (x{v})" for k, v in unresolved.most_common(30)])


def check_reflection(res: Result, root: str, classes: dict[str, str]) -> None:
    forname = re.compile(r'Class;->forName\(Ljava/lang/String;\)|Class;->forName\(Ljava/lang/String;Z\)')
    strconst = re.compile(r'const-string\s+[vp]\d+,\s*"([^"]{4,})"')
    missing: collections.Counter[str] = collections.Counter()
    files = 0
    for cls, relpath in classes.items():
        text = read_smali(os.path.join(root, relpath))
        if not forname.search(text):
            continue
        files += 1
        for m in strconst.finditer(text):
            cand = m.group(1)
            if not FQN.match(cand) or cand.startswith(THIRD_PARTY):
                continue
            if cand in classes:
                continue
            # descarta nombres que no parecen clases (dumps, hosts, mime, etc.)
            if "/" in cand or " " in cand or cand.count(".") == 1 and len(cand.split(".")[-1]) < 3:
                continue
            missing[cand] += 1
    res.stats["clases_por_reflexion"] = files
    if missing:
        res.add("MEDIO", "reflexion",
                f"{len(missing)} clases cargadas por reflexion que no existen en el APK",
                [f"{k} (x{v})" for k, v in missing.most_common(30)])


def check_assets(res: Result, root: str, classes: dict[str, str]) -> None:
    adir = os.path.join(root, "assets")
    present: set[str] = set()
    if os.path.isdir(adir):
        for base, _d, files in os.walk(adir):
            for fn in files:
                present.add(os.path.relpath(os.path.join(base, fn), adir).replace(os.sep, "/"))
    res.stats["assets"] = len(present)
    ref = re.compile(r'const-string\s+[vp]\d+,\s*"([^"]+\.(?:json|html|js|css|txt|xml|dat|db|svg|png|jpg|mp3|ttf))"')
    wanted: collections.Counter[str] = collections.Counter()
    for cls, relpath in classes.items():
        text = read_smali(os.path.join(root, relpath))
        if "assets" not in text:
            continue
        for m in ref.finditer(text):
            cand = m.group(1).lstrip("/")
            if cand.startswith("assets/"):
                cand = cand[len("assets/"):]
            if cand in present:
                continue
            if "/" in cand and not re.match(r"^[a-z0-9_.\-/]+$", cand):
                continue
            wanted[cand] += 1
    if wanted:
        res.add("MEDIO", "assets", f"{len(wanted)} assets referenciados que no existen",
                [f"{k} (x{v})" for k, v in wanted.most_common(25)])


def check_obfuscation(res: Result, classes: dict[str, str]) -> None:
    if not classes:
        return
    obf = 0
    pkgs = collections.Counter()
    for cls in classes:
        parts = cls.split(".")
        if any(len(p) <= 2 for p in parts[-2:]):
            obf += 1
        pkgs[".".join(parts[:2])] += 1
    pct = 100.0 * obf / len(classes)
    res.stats["clases"] = len(classes)
    res.stats["clases_ofuscadas_pct"] = round(pct, 1)
    res.info["top_paquetes"] = [f"{k} ({v})" for k, v in pkgs.most_common(15)]
    if pct > 40:
        res.add("INFO", "ofuscacion", f"{pct:.1f}% de clases con nombres de 1-2 letras (ofuscado/optimizado)",
                ["nombres cortos = R8/ProGuard: el codigo esta, pero ilegible"])


def check_apk_zip(res: Result, apk: str | None) -> None:
    if not apk or not os.path.isfile(apk):
        return
    try:
        with zipfile.ZipFile(apk) as z:
            names = z.namelist()
            dex = [n for n in names if re.match(r"^classes\d*\.dex$", n)]
            res.stats["dex"] = len(dex)
            res.stats["dex_tam"] = {n: z.getinfo(n).file_size for n in dex}
            res.stats["entradas_zip"] = len(names)
            if len(dex) == 0:
                res.add("CRITICO", "codigo", "el APK no contiene classes.dex")
            if "META-INF/MANIFEST.MF" in names or any(n.startswith("META-INF/") and n.endswith((".RSA", ".SF")) for n in names):
                res.add("INFO", "firma", "APK firmado (v1/META-INF presente)")
    except Exception as e:  # noqa: BLE001
        res.add("CRITICO", "apk", f"no se pudo abrir el APK: {e}")


def check_meta(res: Result, root: str) -> None:
    meta = os.path.join(root, "apktool.yml")
    if os.path.isfile(meta):
        vals = {}
        for line in open(meta, errors="ignore"):
            if ":" in line and not line.strip().startswith("-"):
                k, v = line.split(":", 1)
                if len(v.strip()) < 60:
                    vals[k.strip()] = v.strip()
        res.info["apktool_yml"] = {k: v for k, v in vals.items() if k in (
            "minSdkVersion", "targetSdkVersion", "versionName", "versionCode", "apkFileName")}
    for f in ("res/values/public.xml", "res/values/strings.xml"):
        if not os.path.exists(os.path.join(root, f)):
            res.add("BAJO", "recursos", f"no existe {f}", ["recursos no decodificados o eliminados"])


# --------------------------------------------------------------------------- #
def render(res: Result, root: str, apk: str | None) -> str:
    order = {"CRITICO": 0, "ALTO": 1, "MEDIO": 2, "BAJO": 3, "INFO": 4}
    icon = {"CRITICO": "🟥", "ALTO": "🟧", "MEDIO": "🟨", "BAJO": "🟦", "INFO": "ℹ️"}
    out = ["# Auditoría de código — Alpha-Vision", ""]
    out.append(f"- Raíz decompilada: `{root}`")
    if apk:
        out.append(f"- APK: `{apk}`")
    for k in ("package", "versionName", "versionCode", "minSdk", "targetSdk", "appLabel"):
        if res.info.get(k):
            out.append(f"- {k}: `{res.info[k]}`")
    out.append("")
    out.append("## Resumen")
    out.append("")
    counts = collections.Counter(f["severity"] for f in res.findings)
    if not res.findings:
        out.append("Sin hallazgos: el árbol decompilado es coherente con el manifest.")
    for sev in sorted(counts, key=lambda s: order.get(s, 9)):
        out.append(f"- {icon.get(sev,'•')} **{sev}**: {counts[sev]}")
    out.append("")
    out.append("## Estadísticas")
    out.append("")
    out.append("| métrica | valor |")
    out.append("|---|---|")
    for k, v in res.stats.items():
        out.append(f"| {k} | `{v}` |")
    out.append("")
    out.append("## Hallazgos")
    for sev in sorted(counts, key=lambda s: order.get(s, 9)):
        for f in res.findings:
            if f["severity"] != sev:
                continue
            out.append("")
            out.append(f"### {icon.get(sev,'•')} [{sev}] {f['area']}: {f['message']}")
            for d in f["detail"]:
                out.append(f"- `{d}`")
    if res.info.get("top_paquetes"):
        out += ["", "## Paquetes principales", ""] + [f"- `{p}`" for p in res.info["top_paquetes"]]
    return "\n".join(out) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--apk")
    ap.add_argument("--out")
    ap.add_argument("--json")
    a = ap.parse_args()
    if not os.path.isdir(a.root):
        print(f"ERROR: no existe {a.root}", file=sys.stderr)
        return 2
    res = Result()
    classes, smali_dirs = index_smali(a.root)
    res.stats["dirs_smali"] = smali_dirs
    try:
        check_apk_zip(res, a.apk)
        check_meta(res, a.root)
        check_manifest(res, a.root, classes)
        check_native(res, a.root, classes)
        check_resources(res, a.root, classes)
        check_reflection(res, a.root, classes)
        check_assets(res, a.root, classes)
        check_obfuscation(res, classes)
    except Exception as e:  # noqa: BLE001
        res.add("CRITICO", "auditoria", f"fallo inesperado: {type(e).__name__}: {e}")
    report = render(res, a.root, a.apk)
    print(report)
    if a.out:
        with open(a.out, "w") as fh:
            fh.write(report)
    if a.json:
        os.makedirs(os.path.dirname(a.json) or ".", exist_ok=True)
        with open(a.json, "w") as fh:
            json.dump({"findings": res.findings, "stats": res.stats, "info": res.info}, fh, indent=2, ensure_ascii=False)
    crit = any(f["severity"] == "CRITICO" for f in res.findings)
    return 1 if crit else 0


if __name__ == "__main__":
    sys.exit(main())
