# GMST Editor for OpenMW 0.4.0

An in-game editor inspired by GMST Menu (Nexus Morrowind mod 46428), with the
full relaunch requirement. Open Options > Scripts > GMST Editor,
edit a value directly in its native settings row, then click outside
the field to save. Each row has a Reset button.
Quit OpenMW normally and relaunch to apply changes. Loading a save or starting
a new game within the same process does not apply pending changes.

No gameplay presets are applied automatically. Existing editor storage and the
GMSTProfiles manifest identity are retained for compatibility.

## Install

Add this folder as an OpenMW data directory and enable `GMSTProfiles.omwscripts`.
Place its content entry after other load-script mods that change GMSTs, so its
baseline reflects their changes. Requires the OpenMW 0.52 load-script API;
verified with the installed 0.52.0 engine. No custom executable is required.
No source code or assets from the original MWSE mod are distributed.

## Editing

Original and Reset use your current modlist's baseline, not hardcoded vanilla
values. This baseline is captured from OpenMW's loaded GMSTs each launch, before
this editor applies saved edits; it includes ESM/ESP load-order changes and any
earlier load-script changes.

- Gameplay Values uses native settings rows with readable names, explanations, and
  compact number fields. Click outside a field to save its value. Original shows
  the loaded modlist baseline; Reset removes the override for next launch.
- Projectile speed at full draw is the arrow/bolt launch-speed term at full attack
  strength. Its default in the isolated test is 3000; increasing it makes fully drawn
  shots faster. It is a speed value, not a generic multiplier for every projectile.
- Other GMSTs accepts an exact identifier (case insensitive). Enter it, click Read
  Value, edit New value, then click Save. Reset removes that record's override.
- Every loaded GMST now has a direct-edit row. Additional Scripts pages beginning
  with GMST group numbers by topic and text/asset records alphabetically.
  Their descriptions show the exact identifier and type; titles are expanded
  from known identifiers where available, not claims about engine behavior.
- Text fields support empty strings and multiline values. Original previews are
  abbreviated for long strings; Reset restores the full baseline value.
- Search, browsing pages, and the separate selection panel have been removed.
- Float, integer, and string records are supported. Invalid numeric input is rejected.
- Reset removes that record's override. Relaunch restores the loaded modlist baseline.
- Enabled controls application on next launch; disabling retains saved edits.
- Overrides persist in this OpenMW profile's player Lua storage, independently of saves.
  They apply to every game launched in that profile while enabled.

The catalog is read from loaded records at startup, including content-file GMSTs.
String values can be edited directly on the text/asset pages or through Other GMSTs.
Categories are identifier-based navigation aids. Some loaded GMSTs are unused by
OpenMW or only read in specific circumstances; exposing a value does not guarantee
an observable gameplay effect. Asset strings must reference valid existing assets.
Extreme numbers or blank interface strings can make the game difficult to use;
test changes in the isolated profile and use Reset to undo them.
Missing IDs and invalid stored values are skipped and reported in openmw.log.
OpenMW fallback configuration settings are outside the GMST catalog.

## Testing

Double-click `Test-GMST-Editor.cmd` in a source checkout for an isolated fresh Seyda Neen session.
The test supplies an equipped bow, 200 arrows, high Marksman, and a 300-weight
ballast item for movement comparisons, starting on the dock facing open water.
Chargen actors are disabled in the test starting cell so the dock guard cannot
launch race selection or lock controls. This applies only to the test manifest.
The source repository includes TESTING.md for a short manual check.
Test files are not included in the production download.

Engine smoke verification covers three value types across four full launches:
save without immediate application, apply after relaunch, disable without erasing,
then reset to baseline. Catalog construction and Lua UI creation pass with no
error-level log entries. The base test catalog contains 1,947 records.
The 0.4.0 four-launch smoke test checks that all 1,947 records have editing rows.
Five unit tests cover numeric/text save on focus loss, native Reset behavior,
full row registration, and synchronization with the exact-identifier editor.
Menu appearance, mouse/keyboard editing, save reload, and a full modlist remain manual checks.

## Development and Releases

Stock runtime Lua exposes GMST reads; content scripts can write only during startup.
This mod uses those supported APIs and requires a full relaunch to apply edits.

In a source checkout, install requirements-dev.txt and run:

```sh
python -m pytest tests -q -p no:cacheprovider
python tools/release.py package
python tools/release.py verify
```

Production archives contain only the manifest, runtime scripts, localization, and
this README. Release setup is documented in PUBLISHING.md in the source repository.
The separate test kit is built with `tools/package-test.ps1` and is not a release asset.
