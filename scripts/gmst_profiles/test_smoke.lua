local core = require('openmw.core')
local storage = require('openmw.storage')
local I = require('openmw.interfaces')
local self = require('openmw.self')
local types = require('openmw.types')
local model = require('scripts.gmst_profiles.editor_model')
local test = storage.playerSection('GmstEditorSmoke')
local done = false
local elapsed = 0
local function run()
    assert(I.UI.getMode() == nil, 'A startup menu blocked gameplay')
    assert(types.Player.getControlSwitch(self, types.Player.CONTROL_SWITCH.Controls), 'Movement is blocked')
    assert(types.Player.getControlSwitch(self, types.Player.CONTROL_SWITCH.Fighting), 'Fighting is blocked')
    assert(I.GmstProfilesTest.isReady(), 'Test character not ready')
    local inventory = types.Actor.inventory(self)
    assert(inventory:countOf('long bow') == 1 and inventory:countOf('iron arrow') == 200, 'Projectile supplies missing')
    local equipment = types.Actor.getEquipment(self)
    assert(equipment[types.Actor.EQUIPMENT_SLOT.CarriedRight].recordId == 'long bow', 'Bow not equipped')
    assert(equipment[types.Actor.EQUIPMENT_SLOT.Ammunition].recordId == 'iron arrow', 'Arrows not equipped')
    assert(types.NPC.stats.skills.marksman(self).base == 100, 'Marksman setup failed')
    assert(types.Actor.getEncumbrance(self) > 300 and types.Actor.getEncumbrance(self) < types.Actor.getCapacity(self),
        'Ballast missing or actor over capacity')
    -- Allow a little collision settling on the dock after the initial teleport.
    assert(self.cell.isExterior and math.abs(self.position.x + 9511.2) < 10
        and math.abs(self.position.y + 72713.5) < 10 and self.position.z > 60,
        'Dock setup failed: ' .. tostring(self.position))
    local editor = assert(I.GmstEditor, 'Editor interface missing')
    assert(#editor.records() > 1000, 'Loaded GMST catalog missing')
    assert(editor.exposedCount() == #editor.records(), 'Some loaded GMSTs have no native editing row')
    local function id(name)
        for _, r in ipairs(editor.records()) do if r.id:lower() == name:lower() then return r.id end end
        error('Missing record ' .. name)
    end
    local float, integer, stringId = id('fEncumberedMoveEffect'), id('iMonthsToRespawn'), id('sYes')
    local stage = test:get('stage') or 0
    if stage == 0 then
        local pending = I.GmstProfilesTest.status()
        assert(pending == 0, 'Untouched engine-internal strings counted as pending edits')
        assert(not pcall(model.decode, 'GMST199:truncated'), 'Malformed catalog accepted')
        assert(not editor.set(float, 'nan'), 'NaN accepted')
        assert(not editor.set(integer, '1.5'), 'Fractional integer accepted')
        assert(not editor.set('unknownGMST', '1'), 'Unknown ID accepted')
        assert(editor.set(float, '0.123'))
        assert(editor.set(integer, '2'))
        assert(editor.set(stringId, 'Editor smoke: yes'))
        assert(editor.pending(float) and editor.pending(stringId), 'Edits applied without relaunch')
        test:set('stage', 1)
    elseif stage == 1 then
        assert(model.matches(core.getGMST(float), 0.123), 'Float not applied on relaunch')
        assert(core.getGMST(integer) == 2, 'Integer not applied on relaunch')
        assert(core.getGMST(stringId) == 'Editor smoke: yes', 'String not applied on relaunch')
        assert(not editor.pending(float), 'Applied edit still marked pending')
        storage.playerSection(model.settingsSection):set('enabled', false)
        test:set('stage', 2)
    elseif stage == 2 then
        assert(model.matches(core.getGMST(float), editor.baseline(float)), 'Disable did not restore baseline')
        assert(core.getGMST(stringId) == editor.baseline(stringId), 'Disable did not restore string')
        assert(storage.playerSection(model.overridesSection):get(float) ~= nil, 'Disable erased overrides')
        storage.playerSection(model.settingsSection):set('enabled', true)
        assert(editor.reset(float) and editor.reset(integer) and editor.reset(stringId))
        test:set('stage', 3)
    elseif stage == 3 then
        assert(model.matches(core.getGMST(float), editor.baseline(float)), 'Reset did not restore float')
        assert(core.getGMST(integer) == editor.baseline(integer), 'Reset did not restore integer')
        assert(core.getGMST(stringId) == editor.baseline(stringId), 'Reset did not restore string')
        test:set('stage', nil)
    else error('Unexpected smoke stage') end
    print('GMST_EDITOR_SMOKE_PASS: stage=' .. stage .. ' records=' .. #editor.records())
end
return { engineHandlers = { onFrame = function(dt)
    if done then return end
    elapsed = elapsed + dt
    if elapsed < 5 then return end
    done = true
    local ok, err = pcall(run)
    if not ok then print('GMST_EDITOR_SMOKE_FAIL: ' .. tostring(err)) end
    core.quit()
end } }
