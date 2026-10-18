# Settings Page Width Assessment

Assessed 2026-10-18 against installed OpenMW 0.52.0, revision
73765c58a21ee72400a3d8f5cb78b6eaa4cd68a5. This is a mod-side UI assessment,
not a change to the user's installed engine or POTI profile.

## Findings

| Requirement | Evidence | Status |
| --- | --- | --- |
| Resize the native Options window | Native window was widened and narrowed during the probe | Behavior-tested |
| Have a Lua settings page inherit that width | Root `relativeSize.x=1` did not stretch a 400-pixel page when Options widened | Unsupported by the documented root contract; native result agrees |
| Change an embedded page's explicit width | Button changed the page from 400 to 700 pixels and the child line expanded immediately | Behavior-tested |
| Handle a page wider than Options | Narrowing Options around the 700-pixel page produced horizontal scrolling | Behavior-tested |
| Obtain Options panel dimensions in Lua | No supported getter found in the examined UI API; `screenSize()` reports the game viewport | No supported route found |
| Receive Options resize events in Lua | Native widget event declarations do not expose the enclosing Options window's resize event | No supported route found |

The native probe kept `screenSize()` at (1280, 720) while Options was resized.
Explicit page size and available panel width are independent. Relative sizes
still work for children within the explicitly sized page, as shown by the probe
line expanding when its parent changed from 400 to 700 pixels.

The built-in Settings Lua implementation creates an intrinsically sized page
root and fixed-width descriptions. Our renderers add their own fixed-width
controls. Both contribute to the narrow column. Making a child stretch cannot
by itself connect that page root to the native Options panel.

## Options

1. **Keep the editor in Options with width presets.** Add Compact, Standard, and
   Wide modes that change the renderer's intrinsic width and wrapping. This is
   the recommended incremental step: it uses stock OpenMW and preserves the
   current workflow. It requires deliberate width selection; shrinking Options
   below the selected width can introduce horizontal scrolling. The mechanism
   for updating explicit size is tested; integration into the production
   Settings renderer remains to be implemented.
2. **Use a dedicated resizable editor window.** Own the window dimensions and
   reflow the search/results/editor within them. This offers automatic layout
   relative to that editor's own size, at the cost of a separate window and more
   UI work. This architecture has not been prototyped in this investigation.
3. **Extend OpenMW's settings-page API.** Expose the available content size or a
   resize callback, then explicitly update page width. This is the direct route
   to following Options exactly, but requires an engine change and distribution
   or upstream adoption. No custom engine was built here.

Screen-width heuristics alone do not solve Options resizing and are not
recommended as an exact substitute. Font size should remain independent of the
chosen layout width.

## Reproduction

```powershell
python tools/test-shutdown.py --interactive --width-probe
```

Open Options > Scripts > GMST Width Probe. Widen Options and observe that the
400-pixel line stays fixed. Toggle the page to 700 pixels and observe the line
expand. Narrow Options to observe horizontal scrolling. The test-only manifest
includes the probe; the production packaging allowlist excludes it.

Evidence: `.runtime/shutdown-20261018-145901/idle/profile/openmw.log`.
The same session also verified that Application is followed by Direct Edit,
with no Gameplay Values group. The seven unit tests pass, including searchable
former shortcuts, exact-ID editing, and preservation of storage section keys.
The original ctypes Lua harness emitted a Windows exception diagnostic during
passing tests; the canonical repository uses portable Lupa instead. The native
width-probe run has no error-level log entries.

## Sources

- [UI API at the installed engine revision](https://github.com/OpenMW/openmw/blob/73765c58a21ee72400a3d8f5cb78b6eaa4cd68a5/files/lua_api/openmw/ui.lua): settings page root ignores relativeSize; screenSize describes the game window.
- [Installed-revision widget implementation](https://github.com/OpenMW/openmw/blob/73765c58a21ee72400a3d8f5cb78b6eaa4cd68a5/components/lua_ui/widget.cpp).
- Installed `resources/vfs/scripts/omw/settings/menu.lua`: page root and setting/group layout construction.
- [Current widget event reference](https://openmw.readthedocs.io/en/latest/reference/lua-scripting/widgets/widget.html): reviewed as supplementary documentation, not proof of installed-version API availability.

The probe exercises behavior beyond a member-presence check. It does not prove
that no private or future engine workaround could exist.
