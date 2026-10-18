# GMST Editor In-Game Test

Close OpenMW, then double-click `Test-GMST-Editor.cmd` in
`D:\Projects\Coding\GMST-editor`. It starts a fresh character
in Seyda Neen with only Morrowind.esm and GMSTProfilesTest.omwscripts. The test
manifest already includes production scripts; do not enable both manifests together.

The installed POTI OpenMW 0.52 executable is used without loading or modifying the
POTI modlist/profile. Settings/logs are in `.runtime/manual-profile`, and saves and
Lua storage are in `.runtime/manual-user-data`. Never load playthrough saves with
test scripts enabled. Existing manual editor settings persist across launches.
Fresh profiles default to 1920x1080; existing display settings are preserved.
Each launch refreshes a mod-only snapshot under `.runtime/manual-mod-data`.

## First Check

Each fresh launcher session supplies and equips a long bow and 200 iron arrows,
sets Marksman/Agility/Luck to 100, Strength to 100, and supplies a named 300-weight
ballast item. You start at the Seyda Neen dock facing south over the water. Wait for
the test-kit-ready message, then use the normal attack control to fully draw and
release shots. Aim away from NPCs. Compare Original projectile speed with 6000
after a full relaunch. The same supplies/stats are recreated on each fresh launch.

The test disables chargen actors in the starting exterior and marks chargen complete;
no name, race, class, or Census Office sequence should block gameplay.

For Weight slowdown, keep the ballast for the heavy test; drop
`GMST Test Ballast (300 weight)` from your inventory for a light comparison.
Keep it while comparing Original to 0 across relaunches. The supplied load is
substantial but below capacity. Normal swimming/jumping checks are available by the dock.

Optional Lua console helpers (`luap`, then close the console for actions to complete):

```lua
I.GmstProfilesTest.run('refill') -- restores arrows to 200, equips bow, restores stats
I.GmstProfilesTest.run('ready')  -- restores test stats and equips the bow
I.GmstProfilesTest.run('light')  -- drops the existing ballast at your feet
I.GmstProfilesTest.run('heavy')  -- retrieves the existing ballast without making another
I.GmstProfilesTest.run('home')   -- returns to the dock shooting position
```

Reloading a test save preserves its inventory and does not duplicate supplies.
The fixtures are only in the test manifest and test ZIP, never the production mod.

1. Open Options > Scripts > GMST Editor. Expect Application, Direct Edit, and
   Search GMSTs groups, with no Gameplay Values section. Search by identifier,
   label, type, or category and check that results update while the search field
   retains focus. Results include the former gameplay shortcuts.
2. Search for Weight slowdown, enter `0.123`, then click outside the field to save.
   Close and reopen Options: the edited field should remain `0.123`.
3. The current engine value should remain unchanged until relaunch (inspect it
   with the console command below). Quit normally, relaunch, and check for `0.123`.
4. Click the row's Reset, quit, and relaunch. The value should match Original again.
5. Search for Container respawn interval: `1.5` must be rejected; `2` can be saved. Reset afterwards.
6. Under Direct Edit, enter `sYes`, click Read Value, type a distinctive string in
   New value, and click Save. Relaunch and Read Value again to confirm. Reset afterwards.
   An empty string is valid. Changing the identifier requires Read Value before saving.
   Alternatively, search for `sYes`, edit the result directly, click outside
   its text field, and relaunch. Both forms must show the same saved value.
   Search also includes `fProjectileMinSpeed`; try `1` and relaunch
   to compare partially drawn shots, then Reset it. Full-draw shots also depend on
   the maximum speed setting; the existing maximum override is preserved.
7. Set Enabled to No, quit and relaunch: baselines load while saved edits remain.
   Set Enabled to Yes, quit and relaunch to reapply them.
8. Save and reload a test game. Check the page appears once and edited values remain.
   A save reload alone must not apply new edits.

Numerical inspection: open the console, enter `luap`, then:

```lua
I.GmstProfilesTest.status()
require('openmw.core').getGMST('fEncumberedMoveEffect')
```

Status reports record count and values pending relaunch. Enter `exit()` to leave
the Lua console. Advanced GMST identifiers are case insensitive.

## Automated Checks

```powershell
python -m pip install -r requirements-dev.txt
python -m pytest .\tests -p no:cacheprovider
.\tools\start-test.ps1 -PrepareOnly
.\tools\start-test.ps1 -SmokeTest
```

Unit tests use Lupa's portable Lua 5.1 runtime and do not require OpenMW or game
data. The engine DLL harness described in historical results is no longer used.
Launcher paths can be overridden with `-Engine 'C:\Path\openmw.exe'` and
`-GameData 'D:\Path\Data Files'`.

Background smoke and shutdown tests disable all audio with `--no-sound` by
default. Use `-EnableSound` for the PowerShell smoke runner or `--enable-sound`
for the Python runner only when audio is relevant to the test. Interactive
launches retain the selected profile's sound settings.

The smoke test uses separate profile/storage directories and four process launches.
It checks float/integer/string persistence, deferred application, disabling, resetting,
native editing-row coverage for every loaded record, invalid-input rejection, supplies, equipment, carrying
capacity, Marksman setup, and dock placement. The last run restores
its edits. A failed smoke run leaves its stage for diagnosis; its storage is separate
from manual testing. Logs are `.runtime/smoke-profile/stage-0.log` through `stage-3.log`.

Verified: OpenMW 0.52.0, catalog of 1,947 GMSTs, all four stages pass without
error-level entries. UI rendering/input and gameplay effects remain manual checks.
Report the relevant GMST, entered value, launch/reload sequence, and any errors from
`.runtime/manual-profile/openmw.log`.

## Shutdown Investigation (2026-10-18)

Run the repeatable native comparison from the mod directory:

```powershell
python tools/test-shutdown.py
python tools/test-shutdown.py --mod-archive dist/GMST-Editor-OpenMW-0.4.0.zip
python -m pytest -p no:cacheprovider tests/test_storage_writes.py
```

The native harness copies runtime files into a disposable data directory, runs
Morrowind.esm with the same global test fixture in every case, and requests
`core.quit()` after five seconds of player frames. It polls the quit log marker
and process completion every 5 ms. These are approximate quit-to-process-exit
times, excluding startup/loading. Each case runs three times, retaining its own
storage between launches; the editor menu is never opened interactively.
No POTI profile, install files, or playthrough saves are changed.

OpenMW 0.52.0, revision 73765c58a21ee72400a3d8f5cb78b6eaa4cd68a5;
1,947 GMST records. Median shutdown seconds:

| Case | Archived 0.4.0 ZIP | Working single-page search |
| --- | ---: | ---: |
| Mod absent | 0.198 | 0.192 |
| Enabled, no edits | 1.211 | 0.200 |
| Every baseline value submitted again | 3.237 | 0.204 |
| Three overrides submitted | 1.729 | 0.212 |

The baseline-submission case is a stress test: it submits all records immediately
before quitting, rather than simulating a normal individual field edit. The
three overrides are fEncumberedMoveEffect=0.123, iMonthsToRespawn=2, and
sYes="Shutdown test"; later launches resubmit those same overrides.

The archived build exhibits a repeatable shutdown delay even without opening the
menu or making edits. This supports the reported slowdown on 0.52; no indefinite
hang was reproduced. The working search version is much faster in these tests,
but both builds still perform redundant storage setter calls. This comparison
does not isolate serialization, settings subscriptions, or UI teardown as the
cause. OpenMW 0.51, the reporter's exact mod version/modlist, long sessions,
interactive editing, and migration of old editor storage remain untested.

Storage characterization tests cover repeated baseline and override submissions
for float, integer, and string values (including empty strings), invalid input
without writes, and player initialization repeated against existing storage.
They confirm setter calls, not physical disk I/O per call. OpenMW's native logs
also show storage serialization at exit in the untouched cases. Player storage
is about 304 KB for the archived editor versus 182 KB for the current editor.
The two new tests pass; the existing five also pass, though the existing ctypes
Lua DLL harness prints a Windows exception diagnostic during one passing test.
No production Lua behavior was changed for this investigation.

Evidence, including clean mod snapshots and per-run engine logs:

- Working source: `.runtime/shutdown-20261018-143742/results.json`.
- Archived ZIP: `.runtime/shutdown-20261018-143910/results.json`.

Two earlier harness setup attempts were rejected before collecting valid samples:
one hit inaccessible pytest cache directories while scanning the project root;
one used a fixture that assumed the editor existed in the absent-mod control.
The valid runs use a clean runtime snapshot and a shared global-only fixture.

## Search Layout Verification (2026-10-18)

The initial search result border contained three sibling widgets in a plain
container, causing the title, description, and value editor to overlap. Each
result now contains a vertical Flex layout, wrapped title/description text, and
spacing before the editable value. The native renderer test checks that layout
and still verifies string editing through a search result.

Run `python tools/test-shutdown.py --interactive` for an isolated 1280x720 visual
test. Its test-only player fixture preloads the `dialo` query and opens the main
menu. Select Options > Scripts > GMST Editor, then scroll to Search GMSTs.
Unlike the timing runs, this mode waits for a manual quit.

Verified in the native OpenMW 0.52.0 Settings page: `dialo` produces 16 results,
titles/descriptions wrap onto separate lines, and text fields, Reset buttons, and
Original previews no longer overlap. Scrolling between the first several rows
was checked. The production manifest excludes the layout fixture.

## User Acceptance

2026-10-18: The user tested the migrated single-page search build and reported
"Okay, this is working." This confirms acceptance of the current editor workflow,
not automatic width scaling, which is explicitly outside the 0.5.0 feature set.

2026-10-18: Removed the separate Gameplay Values group and renamed Other GMSTs
to Direct Edit. Tests confirm that former shortcuts remain searchable/editable
and their existing storage section keys are retained. Native inspection shows
Application followed by Direct Edit. See [UI-WIDTH.md](UI-WIDTH.md) for the
native Options-resize experiment and recommendations; no automatic width policy
was introduced by this investigation.

2026-10-10: After the chargen-blocking fix, the user reported "It appears to be
working." This confirms a usable test environment at that point. The report did
not specify which GMST values were changed or confirm projectile-speed and
weight-slowdown comparisons, save/reload behavior, or full-modlist compatibility.

2026-10-10: The user set projectile speed to `1`, saved, reloaded, and reported
that it was working. This confirms a user-observed gameplay effect from that
projectile GMST edit. The report does not distinguish a save reload from a full
process relaunch; live application or save-reload-only application is not established.
Weight slowdown, other GMSTs, and full-modlist compatibility remain unconfirmed.

## Repository Migration

The runtime scripts and production manifest were preserved when adopting the
release workflow. The portable Lua 5.1 and packaging suites cover the migrated
repository; previous native smoke and gameplay evidence above applies to the
unchanged implementation, not a new full-modlist compatibility claim.
The migrated launcher can be checked with `tools/start-test.ps1 -PrepareOnly`.
GitHub Actions execution and live GitHub/Nexus uploads remain unverified.

2026-10-10 migration checks: 19 portable Lua/release tests passed; the deterministic
production ZIP and companions passed verification; the relocated test launcher
passed PrepareOnly without launching OpenMW. All seven production runtime,
manifest, and localization files match the previously tested implementation after
line-ending normalization. Native smoke testing was not rerun during migration.

2026-10-18: Search, result-layout fixes, Direct Edit naming, and removal of the
Gameplay Values group were merged into `D:\Projects\Coding\GMST-editor`.
The existing release tooling, portable Lua runner, display defaults, and local
profile storage were retained. Legacy launchers in `D:\Projects\Morrowind`
now use this repository's test launcher. Width presets remain a recommendation,
not an implemented feature.

Migration validation: all 25 portable Lua, launcher, and release tests passed.
PrepareOnly succeeded, and all four native smoke stages passed from the new
repository on OpenMW 0.52.0. The existing manual profile's chosen resolution
was preserved. Git ignore checks confirm that runtime snapshots, environments,
publishing files, logs, caches, and build outputs stay outside the source diff.
The latest native smoke logs are `.runtime/smoke-profile/stage-0.log` through
`stage-3.log`. Interactive acceptance of this migrated build remains for the user.
