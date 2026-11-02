"""Validate the shared token pattern; not a Windows cmd/PowerShell execution."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
s = (root / 'tools/flutter_logged.ps1').read_text()
pattern = re.search(r"\$argument -notmatch '([^']+)'", s).group(1).replace(r"\z", r"\Z")
for good in ('--version', 'build', 'apk', '--release', '--target-platform', 'android-arm,android-arm64,android-x64'):
    assert re.fullmatch(pattern, good), good
for bad in ('', 'a&whoami', 'a|whoami', 'a>file', 'a%PATH%', 'a;whoami', '$(whoami)', 'a,,b', 'a, b', ',a', 'a,', 'a\nb', 'a\n', 'a"b'):
    assert not re.fullmatch(pattern, bad), bad
test = (root / 'tools/test_build_logging.ps1').read_text()
assert "'android-arm,android-arm64,android-x64'" in test
assert 'Platform list was not passed intact' in test
assert 'Unsafe or malformed token accepted' in test
print('OK: comma-separated Flutter platform tokens accepted, shell syntax rejected (static/pattern checks)')
