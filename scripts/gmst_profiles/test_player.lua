local I = require('openmw.interfaces')
local ui = require('openmw.ui')
local core = require('openmw.core')
local self = require('openmw.self')
local types = require('openmw.types')
local started = false
local ready, setup, settle, place = false, false, false, false
local function readyCharacter()
    for key, value in pairs { strength = 100, agility = 100, luck = 100, speed = 50, endurance = 100 } do
        types.NPC.stats.attributes[key](self).base = value
    end
    for key, value in pairs { marksman = 100, athletics = 50, acrobatics = 50 } do
        types.NPC.stats.skills[key](self).base = value
    end
    types.Actor.stats.dynamic.health(self).base = 300
    types.Actor.stats.dynamic.health(self).current = 300
    types.Actor.stats.dynamic.fatigue(self).base = 500
    types.Actor.stats.dynamic.fatigue(self).current = 500
    types.Actor.setEquipment(self, {
        [types.Actor.EQUIPMENT_SLOT.CarriedRight] = 'long bow',
        [types.Actor.EQUIPMENT_SLOT.Ammunition] = 'iron arrow',
    })
    types.Actor.setStance(self, types.Actor.STANCE.Weapon)
    settle = true
end
local function status()
    local failures, count = 0, 0
    for _, r in ipairs(I.GmstEditor.records()) do
        count = count + 1
        if I.GmstEditor.pending(r.id) then failures = failures + 1; print('GMST_TEST_PENDING: ' .. r.id) end
    end
    print(('GMST_TEST_STATUS: %d records, %d pending relaunch'):format(count, failures))
    print(('GMST_TEST_CHARACTER: carry=%.1f/%.1f runSpeed=%.1f arrows=%d'):format(
        types.Actor.getEncumbrance(self), types.Actor.getCapacity(self), types.Actor.getRunSpeed(self),
        types.Actor.inventory(self):countOf('iron arrow')))
    return failures, count
end
return {
    interfaceName = 'GmstProfilesTest', interface = {
        status = status, isReady = function() return ready end,
        run = function(command)
            if command == 'ready' then setup = true
            elseif command == 'refill' or command == 'light' or command == 'heavy' or command == 'home' then
                core.sendGlobalEvent('GmstEditorKitAction', { player = self.object, command = command })
            else error('Unknown kit action: ' .. tostring(command)) end
        end,
    },
    eventHandlers = { GmstEditorKitReady = function(data) setup = true; place = data.newSession == true end },
    engineHandlers = { onFrame = function()
        if started then return end
        started = true
        status()
    end,
        onUpdate = function()
            if settle then
                settle = false; ready = true
                ui.showMessage('Test kit ready: bow equipped, 200 arrows, 300-weight ballast. Aim out over the water.')
            end
            if setup then
                setup = false; readyCharacter()
                if place then
                    place = false
                    I.UI.setMode(nil)
                    core.sendGlobalEvent('GmstEditorKitAction', { player = self.object, command = 'home' })
                end
            end
        end,
        onSave = function() return { ready = ready } end,
        onLoad = function(data)
            ready = type(data) == 'table' and data.ready == true
            setup, settle, place = false, false, false
        end,
    },
}
