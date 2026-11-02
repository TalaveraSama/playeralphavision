"""Static guards; runtime lifecycle behavior still needs Android testing."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
base = root / 'android/app/src/main/kotlin/com/xtreamplayer/xtream_player'
activity = (base / 'MainActivity.kt').read_text()
host = (base / 'VlcPlayerHost.kt').read_text()
player = (base / 'VlcTexturePlayer.kt').read_text()
for marker in ['override fun onStop()', 'vlcHost?.suspendAll()',
               'override fun onDestroy()', 'override fun cleanUpFlutterEngine', 'vlcHost?.dispose()']:
    assert marker in activity, marker
assert 'players.clear()' in host
assert 'if (released) return' in player
assert 'player.stop()' in player
assert 'channel.setMethodCallHandler(null)' in player
assert 'if (suspended || !visible) resumeWhenVisible = true' in player
layout = (root / 'lib/widgets/nova/nova3_live_layout.dart').read_text()
for marker in ['ScrollController()', 'itemExtent: _rowExtent', '_scroll.jumpTo(offset)',
               'focus.requestFocus()', 'oldWidget.index != widget.index']:
    assert marker in layout, marker
focus = (root / 'lib/widgets/nova/nova_ui.dart').read_text()
assert 'widget.focusNode ?? _ownedNode' in focus
assert '_ownedNode.dispose()' in focus
page = (root / 'lib/features/player/player_texture_page.dart').read_text()
assert "_channel?.setMethodCallHandler(null)" in page
assert 'version != _loadVersion || !_foreground' in page
assert '_autoSwitchTimer?.cancel();\n    setState(() => _index' in page
print('OK: native stop/cleanup, idempotent release, pending-load guards and selected-channel scroll/focus')
