from pathlib import Path
import shutil
import subprocess
import sys

import pytest

ROOT = Path(__file__).resolve().parents[1]
pytestmark = pytest.mark.skipif(sys.platform != 'win32', reason='PowerShell Windows launcher')


@pytest.fixture
def prepared_launcher(tmp_path):
    tools = tmp_path / 'tools'
    tools.mkdir()
    script = tools / 'start-test.ps1'
    shutil.copyfile(ROOT / 'tools/start-test.ps1', script)
    engine = tmp_path / 'engine/openmw.exe'
    engine.parent.mkdir()
    engine.touch()
    resources = engine.parent / 'resources'
    resources.mkdir()
    (resources / 'version').write_text('0.52.0\n')
    game = tmp_path / 'game'
    game.mkdir()
    for name in ('Morrowind.esm', 'Morrowind.bsa'):
        (game / name).touch()

    def prepare():
        result = subprocess.run([
            'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(script),
            '-Engine', str(engine), '-GameData', str(game), '-PrepareOnly',
        ], capture_output=True, text=True, timeout=30)
        assert result.returncode == 0, result.stdout + result.stderr

    return prepare, tmp_path / '.runtime/manual-profile/settings.cfg'


def test_fresh_profile_uses_readable_resolution(prepared_launcher):
    prepare, settings = prepared_launcher
    prepare()
    text = settings.read_text()
    assert 'resolution x = 1920' in text
    assert 'resolution y = 1080' in text
    assert 'fullscreen = false' in text


def test_prepare_preserves_chosen_display_settings(prepared_launcher):
    prepare, settings = prepared_launcher
    prepare()
    chosen = b'[Video]\nresolution x = 2560\nresolution y = 1440\nfullscreen = true\n'
    settings.write_bytes(chosen)
    prepare()
    assert settings.read_bytes() == chosen
