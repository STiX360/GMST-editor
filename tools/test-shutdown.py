"""Measure native quit latency in disposable profiles; never uses real saves."""
import argparse
import hashlib
import json
from pathlib import Path
import statistics
import shutil
import subprocess
import time
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, default=Path(r'C:\Modlists\POTI\.OpenMW\openmw.exe'))
    parser.add_argument('--game-data', type=Path, default=Path(r'D:\Steam\steamapps\common\Morrowind\Data Files'))
    parser.add_argument('--repeats', type=int, default=3)
    parser.add_argument('--mod-archive', type=Path, help='Test a packaged release instead of working source')
    parser.add_argument('--interactive', action='store_true', help='Launch one isolated session for manual UI checks')
    parser.add_argument('--width-probe', action='store_true', help='Include the test-only settings width probe')
    parser.add_argument('--enable-sound', action='store_true', help='Enable audio for sound-related background tests')
    args = parser.parse_args()
    if args.width_probe and not args.interactive:
        parser.error('--width-probe requires --interactive')
    root = Path(__file__).resolve().parents[1]
    resources = args.engine.parent / 'resources'
    output = root / '.runtime' / ('shutdown-' + time.strftime('%Y%m%d-%H%M%S'))
    output.mkdir(parents=True)
    mod = output / 'mod'
    shutil.copytree(root / 'scripts', mod / 'scripts')
    shutil.copytree(root / 'l10n', mod / 'l10n')
    manifest_text = (root / 'GMSTProfiles.omwscripts').read_text()
    if args.mod_archive:
        with zipfile.ZipFile(args.mod_archive) as archive:
            manifest_text = archive.read('GMSTProfiles.omwscripts').decode()
            for name in archive.namelist():
                relative = Path(name)
                if relative.is_absolute() or '..' in relative.parts:
                    raise ValueError('Unsafe archive path: ' + name)
                if not name.endswith('/') and relative.parts[0] in ('scripts', 'l10n'):
                    target = mod / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(archive.read(name))
    (output / 'metadata.json').write_text(json.dumps({
        'engine': str(args.engine), 'version': (resources / 'version').read_text().strip(),
        'mod_archive': str(args.mod_archive) if args.mod_archive else None,
        'poll_seconds': 0.005,
        'quit_method': 'manual' if args.interactive else 'core.quit from player onFrame after 5 seconds',
        'interactive': args.interactive, 'menu_opened': None if args.interactive else False,
        'sound_disabled_by_runner': not args.interactive and not args.enable_sound,
    }, indent=2))
    rows = []
    for iteration in range(1 if args.interactive else args.repeats):
        for scenario in (('idle',) if args.interactive else ('absent', 'idle', 'unchanged', 'changed')):
            case = output / scenario
            profile, user, data = case / 'profile', case / 'user', case / 'data'
            for directory in (profile, user, data / 'scripts'):
                directory.mkdir(parents=True, exist_ok=True)
            (data / 'scripts/gmst_exit_case.lua').write_text("return '" + scenario + "'\n")
            manifest = [] if scenario == 'absent' else manifest_text.splitlines()
            manifest += ['GLOBAL: scripts/gmst_profiles/test_fixtures.lua']
            if not args.interactive:
                manifest += ['PLAYER: scripts/gmst_profiles/test_shutdown.lua']
            else:
                manifest += ['PLAYER: scripts/gmst_profiles/test_search_layout.lua']
            if args.width_probe:
                manifest += ['MENU: scripts/gmst_profiles/test_settings_width.lua']
            (data / 'ShutdownTest.omwscripts').write_text('\n'.join(manifest) + '\n')
            config = ['replace=config', 'replace=data', 'replace=content', 'replace=groundcover',
                      'replace=fallback-archive', f'resources="{resources.as_posix()}"',
                      f'data="{resources.as_posix()}/vfs-mw"', f'data="{args.game_data.as_posix()}"',
                      f'data="{mod.as_posix()}"', f'data="{data.as_posix()}"',
                      f'data-local="{(user / "data").as_posix()}"', 'content=Morrowind.esm',
                      'fallback-archive=Morrowind.bsa', 'content=ShutdownTest.omwscripts']
            for archive in ('Tribunal.bsa', 'Bloodmoon.bsa'):
                if (args.game_data / archive).exists():
                    config.append('fallback-archive=' + archive)
            (user / 'data').mkdir(exist_ok=True)
            (profile / 'openmw.cfg').write_text('\n'.join(config) + '\n')
            settings = profile / 'settings.cfg'
            if not settings.exists():
                size = (1280, 720) if args.interactive else (640, 480)
                settings.write_text(f'[Video]\nresolution x = {size[0]}\nresolution y = {size[1]}\nfullscreen = false\n[Sound]\nmusic volume = 0\n')
            log = profile / 'openmw.log'
            # Remove only the previous test log, so a warm run cannot see an old marker.
            if log.exists():
                log.unlink()
            started = time.perf_counter()
            marker = None
            startup = subprocess.STARTUPINFO()
            startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startup.wShowWindow = 1 if args.interactive else 0
            with (case / f'run-{iteration}.stdout.log').open('w') as stdout, \
                    (case / f'run-{iteration}.stderr.log').open('w') as stderr:
                process = subprocess.Popen([str(args.engine), '--replace', 'config', '--config', str(profile),
                                            '--user-data', str(user), '--skip-menu', '--new-game=0',
                                            '--start', 'Seyda Neen', '--no-grab']
                                           + ([] if args.interactive or args.enable_sound else ['--no-sound']),
                                           cwd=args.engine.parent, stdout=stdout, stderr=stderr,
                                           startupinfo=startup)
                if args.interactive:
                    print(f'Interactive test PID {process.pid}; profile: {profile}', flush=True)
                    return
                while True:
                    text = log.read_text(errors='replace') if log.exists() else ''
                    if marker is None and 'GMST_EXIT_REQUEST:' in text:
                        marker = time.perf_counter()
                    code = process.poll()
                    if code is not None:
                        finished = time.perf_counter()
                        break
                    if time.perf_counter() - started > 60:
                        process.kill()
                        process.wait()
                        raise RuntimeError(f'Timeout: {scenario}; logs: {case}')
                    time.sleep(0.005)
            text = log.read_text(errors='replace')
            (case / f'run-{iteration}.openmw.log').write_text(text)
            if code != 0 or marker is None or 'GMST_EXIT_FAIL:' in text or ' E]' in text:
                raise RuntimeError(f'Failed: {scenario}, exit={code}; logs: {case}')
            row = dict(scenario=scenario, iteration=iteration, exit_code=code,
                       shutdown_seconds=round(finished - marker, 4),
                       total_seconds=round(finished - started, 4),
                       storage_bytes=(profile / 'player_storage.bin').stat().st_size
                       if (profile / 'player_storage.bin').exists() else 0)
            rows.append(row)
            storage = profile / 'player_storage.bin'
            if storage.exists():
                row['storage_sha256'] = hashlib.sha256(storage.read_bytes()).hexdigest()
                row['storage_mtime_ns'] = storage.stat().st_mtime_ns
                shutil.copy2(storage, case / f'run-{iteration}.player_storage.bin')
            (output / 'results.json').write_text(json.dumps(rows, indent=2))
            print(json.dumps(row), flush=True)
    for scenario in ('absent', 'idle', 'unchanged', 'changed'):
        values = [row['shutdown_seconds'] for row in rows if row['scenario'] == scenario]
        print(f'{scenario}: median={statistics.median(values):.4f}s max={max(values):.4f}s', flush=True)
    print(f'Evidence: {output}', flush=True)


if __name__ == '__main__':
    main()
