"""Static checks, NOT proof that native device crashes are resolved."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
assert '-keep class org.videolan.** { *; }' in (root/'android/app/proguard-rules.pro').read_text()
base = root/'android/app/src/main/kotlin/com/xtreamplayer/xtream_player'
host = (base/'VlcPlayerHost.kt').read_text()
assert 'catch (error: LinkageError)' in host
assert 'catch (error: RuntimeException)' in host
assert 'result.error("VLC_NATIVE_LOAD"' in host
native = (base/'VlcTexturePlayer.kt').read_text()
assert native.index('LibVLC(context.applicationContext') < native.index('textureRegistry.createSurfaceTexture()')
page = (root/'lib/features/player/player_texture_page.dart').read_text()
assert "error.code == 'VLC_NATIVE_LOAD'" in page
print('OK: static JNI/R8 keep rules, initialization error guard and diagnostic UI')
