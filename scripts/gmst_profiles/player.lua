local core = require('openmw.core')
local storage = require('openmw.storage')
local I = require('openmw.interfaces')
local model = require('scripts.gmst_profiles.editor_model')
local labels = require('scripts.gmst_profiles.labels')
local overrides = storage.playerSection(model.overridesSection)
local settings = storage.playerSection(model.settingsSection)
local records = model.decode(core.getGMST(model.catalogId))
local lookup, applied = {}, {}
for _, r in ipairs(records) do lookup[r.id:lower()] = r end
for _, r in ipairs(model.decode(core.getGMST(model.appliedId))) do applied[r.id] = r.value end
local function find(id) return type(id) == 'string' and lookup[id:lower()] or nil end
local function setValue(id, text)
    local r = find(id)
    local ok, value = model.save(overrides, r, text)
    if ok then storage.playerSection(model.sectionFor(r.id)):set(r.id, value) end
    return ok, value
end
local function reset(id)
    local r = find(id)
    if not r then return false end
    overrides:set(r.id, nil)
    storage.playerSection(model.sectionFor(r.id)):set(r.id, r.value)
    return true
end

I.Settings.registerPage { key = 'GmstEditor', l10n = 'GmstProfiles', name = 'PageName', description = 'Relaunch' }
I.Settings.registerGroup {
    key = model.settingsSection, page = 'GmstEditor', l10n = 'GmstProfiles', name = 'Controls',
    permanentStorage = true, order = 0,
    settings = { { key = 'enabled', name = 'Enabled', renderer = 'checkbox', default = true } },
}
local fields = {}
local exposed = 0
local function field(r, name, description)
    local section = model.sectionFor(r.id)
    local saved = overrides:get(r.id)
    if not model.valid(r.id, saved, r.value) then saved = nil end
    storage.playerSection(section):set(r.id, saved ~= nil and saved or r.value)
    exposed = exposed + 1
    return { key = r.id, name = name, description = description,
        renderer = type(r.value) == 'string' and 'gmstEditorString' or 'gmstEditorNumber',
        default = r.value, argument = { id = r.id, baseline = r.value, section = section } }
end
for _, id in ipairs(model.commonOrder) do
    local r = lookup[id]
    if r then
        fields[#fields + 1] = field(r, model.common[id][1], model.common[id][2])
    end
end
I.Settings.registerGroup {
    key = model.valuesSection, page = 'GmstEditor', l10n = 'GmstProfiles', name = 'Gameplay',
    permanentStorage = true, order = 1, settings = fields,
}
I.Settings.registerGroup {
    key = 'SettingsPlayerGmstEditorAdvanced', page = 'GmstEditor', l10n = 'GmstProfiles', name = 'Advanced',
    description = 'AdvancedDescription', permanentStorage = true, order = 2,
    settings = { { key = 'record', name = 'Record', renderer = 'gmstEditorAdvanced', default = { id = '', text = '' } } },
}
local categories = {}
for _, category in ipairs(model.categoryOrder) do categories[category] = {} end
for _, r in ipairs(records) do
    if not model.common[r.id:lower()] then
        local category = categories[model.category(r.id)]
        local kind = type(r.value) == 'string' and 'string' or r.id:sub(1, 1):lower() == 'i' and 'integer' or 'float'
        category[#category + 1] = field(r, labels[r.id:lower()] or r.id, r.id .. ' (' .. kind .. ')')
    end
end
for _, category in ipairs(model.categoryOrder) do
    local group = categories[category]
    if #group > 0 then
        table.sort(group, function(a, b) return a.key:lower() < b.key:lower() end)
        local page = 'GmstEditor_' .. category
        I.Settings.registerPage { key = page, l10n = 'GmstProfiles',
            name = 'GMST: ' .. model.categoryNames[category], description = 'Relaunch' }
        I.Settings.registerGroup { key = model.valuesSection .. '_' .. category, page = page,
            l10n = 'GmstProfiles', name = model.categoryNames[category],
            permanentStorage = true, settings = group }
    end
end
return {
    interfaceName = 'GmstEditor',
    interface = {
        set = setValue, reset = reset, records = function() return records end,
        exposedCount = function() return exposed end,
        baseline = function(id) local r = find(id); return r and r.value end,
        pending = function(id)
            local r = find(id)
            if not r or overrides:get(r.id) == nil and applied[r.id] == nil then return false end
            local target = settings:get('enabled') ~= false and overrides:get(r.id) or nil
            if target == nil then target = r.value end
            return not model.matches(core.getGMST(r.id), target)
        end,
    },
}
