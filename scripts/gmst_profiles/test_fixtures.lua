local world = require('openmw.world')
local types = require('openmw.types')
local util = require('openmw.util')
local done, ballast = false, nil
local dock = util.vector3(-9511.2, -72713.5, 300)
local function skipChargen(player)
    world.mwscript.getGlobalVariables().chargenstate = -1
    for _, switch in pairs(types.Player.CONTROL_SWITCH) do types.Player.setControlSwitch(player, switch, true) end
    -- Bypass mode doesn't disable the dock guard's independent race-menu script.
    for _, object in ipairs(world.getExteriorCell(-2, -9):getAll()) do
        if object.recordId:lower():sub(1, 7) == 'chargen' then object.enabled = false end
    end
end
local function supply(player, id, count)
    local inventory = types.Actor.inventory(player)
    local missing = count - inventory:countOf(id)
    if missing > 0 then world.createObject(id, missing):moveInto(inventory) end
end
local function home(player)
    skipChargen(player)
    player:teleport('Seyda Neen', dock, { onGround = true, rotation = util.transform.rotateZ(math.pi) })
end
return {
    engineHandlers = {
        onPlayerAdded = function(player)
            if done then return end
            skipChargen(player)
            assert(types.Weapon.record('long bow') and types.Weapon.record('iron arrow'), 'Missing bow test records')
            supply(player, 'long bow', 1)
            supply(player, 'iron arrow', 200)
            local record = world.createRecord(types.Miscellaneous.createRecordDraft {
                template = types.Miscellaneous.record('misc_com_bottle_01'),
                name = 'GMST Test Ballast (300 weight)', weight = 300, value = 0,
            })
            ballast = world.createObject(record.id)
            ballast:moveInto(types.Actor.inventory(player))
            done = true
            player:sendEvent('GmstEditorKitReady', { newSession = true })
            print('GMST_TEST_KIT: long bow, 200 iron arrows, 300-weight ballast; Seyda Neen dock')
        end,
        onSave = function() return { done = done, ballast = ballast } end,
        onLoad = function(data)
            -- Never inject supplies into a save that was not made with these fixtures.
            done = data == nil or type(data) == 'table' and data.done == true
            ballast = type(data) == 'table' and data.ballast or nil
        end,
    },
    eventHandlers = { GmstEditorKitAction = function(data)
        local player = data.player
        if not player or player.type ~= types.Player then return end
        if data.command == 'refill' then
            supply(player, 'long bow', 1); supply(player, 'iron arrow', 200)
            player:sendEvent('GmstEditorKitReady', {})
        elseif data.command == 'light' and ballast and ballast:isValid() then
            ballast:teleport(player.cell, player.position)
        elseif data.command == 'heavy' and ballast and ballast:isValid() then
            ballast:moveInto(types.Actor.inventory(player))
        elseif data.command == 'home' then home(player) end
    end },
}
