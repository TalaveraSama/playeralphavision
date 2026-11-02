"""Historical command: now validates VLC as the IPTV default."""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name('check_vlc_default.py')), run_name='__main__')
