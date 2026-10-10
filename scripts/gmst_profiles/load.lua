local content = require('openmw.content')
local storage = require('openmw.storage')
local model = require('scripts.gmst_profiles.editor_model')
local function apply()
    local records, lookup = {}, {}
    for id, value in pairs(content.gameSettings.records) do
        id = tostring(id)
        if id:lower() ~= model.catalogId:lower() and id:lower() ~= model.appliedId:lower() then
            records[#records + 1] = { id = id, value = value }
            lookup[id] = value
        end
    end
    table.sort(records, function(a, b) return a.id:lower() < b.id:lower() end)
    content.gameSettings.records[model.catalogId] = model.encode(records)
    local enabled = storage.playerSection(model.settingsSection):get('enabled') ~= false
    local changed, rejected, applied = 0, 0, {}
    if enabled then
        for id, value in pairs(storage.playerSection(model.overridesSection):asTable()) do
            if lookup[id] ~= nil and model.valid(id, value, lookup[id]) then
                content.gameSettings.records[id] = value
                changed = changed + 1
                applied[#applied + 1] = { id = id, value = value }
            else
                rejected = rejected + 1
                print('[GMST Editor] ignored missing or invalid override: ' .. id)
            end
        end
    end
    content.gameSettings.records[model.appliedId] = model.encode(applied)
    print(('[GMST Editor] catalog=%d applied=%d rejected=%d enabled=%s'):format(
        #records, changed, rejected, tostring(enabled)))
end
return { engineHandlers = { onContentFilesLoaded = apply } }
