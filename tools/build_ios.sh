#!/usr/bin/env bash
# Compile on macOS; default is UNSIGNED, not an installable IPA.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'iPhone requires macOS + Xcode. Windows/Linux cannot build this iOS app.' >&2
  exit 1
fi
CONFIG="${1:-admin_panel/config.json}"
MODE="${2:---no-codesign}"
if [[ "$MODE" != --no-codesign && "$MODE" != --ipa ]]; then
  echo 'Usage: bash tools/build_ios.sh [config.json] [--no-codesign|--ipa]' >&2
  exit 2
fi
for tool in flutter xcodebuild pod python3; do
  command -v "$tool" >/dev/null || { echo "Missing tool: $tool" >&2; exit 1; }
done
xcodebuild -version
mkdir -p build/ios-config-backup
python3 - "$CONFIG" <<'PY'
import json, pathlib, plistlib, shutil, sys
config = pathlib.Path(sys.argv[1]).expanduser().resolve()
data = json.loads(config.read_text(encoding='utf-8-sig'))
if not isinstance(data, dict):
    raise SystemExit('Configuration must be a JSON object')
branding = data.get('branding', {})
if not isinstance(branding, dict):
    raise SystemExit('branding must be a JSON object')
name = branding.get('appName', 'Alpha Vision')
if not isinstance(name, str) or not name.strip():
    raise SystemExit('branding.appName must be a non-empty string')
assets = pathlib.Path('assets/config.json')
info = pathlib.Path('ios/Runner/Info.plist')
backup = pathlib.Path('build/ios-config-backup')
for src, name in [(assets, 'config-before-build.json'), (info, 'Info-before-build.plist')]:
    if not (backup / name).exists():
        shutil.copy2(src, backup / name)
if config != assets.resolve():
    shutil.copy2(config, assets)
plist = plistlib.loads(info.read_bytes())
plist['CFBundleDisplayName'] = name
info.write_bytes(plistlib.dumps(plist, sort_keys=False))
print('iOS brand:', name)
print('Configuration copied. Bundle ID and signing Team are configured in Xcode.')
PY
flutter pub get
flutter precache --ios
(cd ios && pod install)
if [[ "$MODE" == --ipa ]]; then
  echo 'Signed archive: configure Bundle Identifier and Apple Team in Xcode first.'
  flutter build ipa --release
else
  flutter build ios --release --no-codesign
  echo 'Unsigned .app at build/ios/iphoneos. NOT directly installable on iPhone.'
  echo 'For installation use Xcode signing, or TestFlight with Apple Developer.'
fi
