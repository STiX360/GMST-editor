# GMST Editor In-Game Test

Close OpenMW, then double-click `Test-GMST-Editor.cmd` in the repository root.
It starts a fresh character
in Seyda Neen with only Morrowind.esm and GMSTProfilesTest.omwscripts. The test
manifest already includes production scripts; do not enable both manifests together.

The installed POTI OpenMW 0.52 executable is used without loading or modifying the
POTI modlist/profile. Settings/logs are in `.runtime/manual-profile`, and saves and
Lua storage are in `.runtime/manual-user-data`. Never load playthrough saves with
test scripts enabled. Existing manual editor settings persist across launches.

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

1. Open Options > Scripts > GMST Editor. Expect Application, Gameplay Values,
   and Other GMSTs groups. Gameplay rows have an explanation, small number field,
   Original value, and Reset. There is no search or selected-record panel.
   Additional GMST pages expose all other loaded values, grouped by topic for
   numbers and alphabetically for text/assets. Rows show their identifier and type.
2. In Weight slowdown, enter `0.123`, then click outside the field to save.
   Close and reopen Options: the edited field should remain `0.123`.
3. The current engine value should remain unchanged until relaunch (inspect it
   with the console command below). Quit normally, relaunch, and check for `0.123`.
4. Click the row's Reset, quit, and relaunch. The value should match Original again.
5. In Container respawn interval, `1.5` must be rejected; `2` can be saved. Reset afterwards.
6. Under Other GMSTs, enter `sYes`, click Read Value, type a distinctive string in
   New value, and click Save. Relaunch and Read Value again to confirm. Reset afterwards.
   An empty string is valid. Changing the identifier requires Read Value before saving.
   Alternatively, edit `sYes` directly on GMST: Text and Assets S-Z, click outside
   its text field, and relaunch. Both forms must show the same saved value.
   GMST: Combat and Projectiles includes `fProjectileMinSpeed`; try `1` and relaunch
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

Install requirements-dev.txt before running unit tests. They use Lupa's Lua 5.1
runtime and do not require OpenMW or licensed game data.
Launcher paths can be overridden with `-Engine 'C:\Path\openmw.exe'` and
`-GameData 'D:\Path\Data Files'`.

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

## User Acceptance

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
