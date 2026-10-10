local M = { overridesSection = 'GmstEditorOverrides', settingsSection = 'SettingsPlayerGmstEditor',
    catalogId = 'sOpenMWGmstEditorCatalog', appliedId = 'sOpenMWGmstEditorApplied',
    valuesSection = 'SettingsPlayerGmstEditorValues' }
M.commonOrder = { 'fencumberedmoveeffect', 'fswimrunbase', 'fswimrunathleticsmult',
    'fjumpencumbrancebase', 'fjumpencumbrancemultiplier', 'farrowspeedmult', 'fprojectilemaxspeed',
    'frepairmult', 'imonthstorespawn' }
M.common = {
    fencumberedmoveeffect = { 'Weight slowdown', 'Movement slowdown from carried weight. Lower values reduce the penalty.' },
    fswimrunbase = { 'Swimming speed: base', 'Base multiplier used when swimming at running speed.' },
    fswimrunathleticsmult = { 'Swimming: Athletics scaling', 'How strongly Athletics contributes to running swim speed.' },
    fjumpencumbrancebase = { 'Jumping: weight base', 'Base term in the jump-height formula for carried weight.' },
    fjumpencumbrancemultiplier = { 'Jumping: weight multiplier', 'Multiplier in the jump-height formula for carried weight.' },
    farrowspeedmult = { 'Arrow speed multiplier', 'Multiplier used for arrow projectile speed.' },
    fprojectilemaxspeed = { 'Projectile speed at full draw', 'Arrow and bolt launch speed at full attack strength. Higher values make fully drawn shots faster.' },
    frepairmult = { 'Repair effectiveness', 'Multiplier used in the repair calculation.' },
    imonthstorespawn = { 'Container respawn interval', 'Number of in-game months between eligible container respawns.' },
}
M.categoryNames = { movement = 'Movement and Fatigue', combat = 'Combat and Projectiles',
    magic = 'Magic and Enchanting', economy = 'Trading and Services', skills = 'Skills and Progression',
    ai = 'NPCs and AI', world = 'World and Time', other = 'Other Numbers',
    textAF = 'Text and Assets A-F', textGL = 'Text and Assets G-L', textMR = 'Text and Assets M-R',
    textSZ = 'Text and Assets S-Z' }
M.categoryOrder = { 'movement', 'combat', 'magic', 'economy', 'skills', 'ai', 'world', 'other',
    'textAF', 'textGL', 'textMR', 'textSZ' }
local categoryWords = {
    movement = { 'move', 'walk', 'run', 'swim', 'jump', 'fatigue', 'encumb', 'fall', 'acrobat' },
    combat = { 'combat', 'attack', 'damage', 'armor', 'weapon', 'projectile', 'arrow', 'block', 'knock', 'hit', 'dodge' },
    magic = { 'magic', 'spell', 'enchant', 'magicka', 'soul', 'alchemy', 'potion', 'effect', 'summon', 'cast' },
    economy = { 'barter', 'buy', 'sell', 'price', 'repair', 'merchant', 'service', 'gold', 'travel', 'train', 'bargain' },
    skills = { 'skill', 'level', 'attribute', 'experience', 'health', 'stat', 'class', 'race', 'luck' },
    ai = { 'ai', 'alarm', 'crime', 'disposition', 'persu', 'fight', 'flee', 'hello', 'sneak', 'steal', 'pick', 'npc', 'idle' },
    world = { 'time', 'day', 'month', 'year', 'respawn', 'weather', 'light', 'sun', 'moon', 'water', 'distance', 'cell' },
}
function M.category(id)
    id = id:lower()
    if id:sub(1, 1) ~= 'f' and id:sub(1, 1) ~= 'i' then
        local letter = id:sub(id:sub(1, 1) == 's' and 2 or 1, id:sub(1, 1) == 's' and 2 or 1)
        return letter <= 'f' and 'textAF' or letter <= 'l' and 'textGL' or letter <= 'r' and 'textMR' or 'textSZ'
    end
    for _, category in ipairs(M.categoryOrder) do
        for _, word in ipairs(categoryWords[category] or {}) do
            if id:find(word, 2, true) then return category end
        end
    end
    return 'other'
end
function M.sectionFor(id)
    return M.common[id:lower()] and M.valuesSection or M.valuesSection .. '_' .. M.category(id)
end
local function field(value)
    value = tostring(value)
    return tostring(#value) .. ':' .. value
end
-- Length-prefixed fields preserve arbitrary strings without evaluating code.
function M.encode(records)
    local out = { 'GMST1' }
    for _, r in ipairs(records) do
        out[#out + 1] = field(r.id)
        out[#out + 1] = field(type(r.value))
        out[#out + 1] = field(type(r.value) == 'number' and ('%.17g'):format(r.value) or r.value)
    end
    return table.concat(out)
end
function M.decode(data)
    if type(data) ~= 'string' or data:sub(1, 5) ~= 'GMST1' then return {} end
    local pos, records = 6, {}
    local function read()
        local colon = assert(data:find(':', pos, true), 'Truncated GMST catalog')
        local count = assert(tonumber(data:sub(pos, colon - 1)), 'Invalid GMST field length')
        assert(count >= 0 and count == math.floor(count) and colon + count <= #data, 'Invalid GMST field')
        local value = data:sub(colon + 1, colon + count)
        pos = colon + count + 1
        return value
    end
    while pos <= #data do
        local id, kind, value = read(), read(), read()
        assert(kind == 'number' or kind == 'string', 'Invalid GMST type')
        if kind == 'number' then value = assert(tonumber(value), 'Invalid numeric GMST') end
        records[#records + 1] = { id = id, value = value }
    end
    return records
end
function M.parse(id, text, baseline)
    if type(baseline) == 'string' then return text end
    local value = tonumber(text)
    if not value or value ~= value or math.abs(value) == math.huge then return nil, 'Enter a finite number.' end
    if id:sub(1, 1):lower() == 'i' then
        if math.floor(value) ~= value or value < -2147483648 or value > 2147483647 then
            return nil, 'Enter a whole number in the signed 32-bit range.'
        end
    elseif math.abs(value) > 2147483647 then
        -- The engine content setter converts through int32 even for floats.
        return nil, 'Value exceeds the supported numeric range.'
    end
    return value
end
function M.valid(id, value, baseline)
    return type(value) == type(baseline) and M.parse(id, tostring(value), baseline) ~= nil
end
function M.matches(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'number' then return a == b end
    if math.floor(a) == a and math.floor(b) == b then return a == b end
    return math.abs(a - b) <= 0.0000001 * math.max(1e-37, math.abs(a), math.abs(b))
end
function M.format(value)
    return type(value) == 'number' and ('%.7g'):format(value) or tostring(value)
end
function M.save(section, record, text)
    if not record then return false, 'Unknown GMST identifier.' end
    local value, err = M.parse(record.id, text, record.value)
    if value == nil then return false, err end
    if M.matches(value, record.value) then section:set(record.id, nil)
    else section:set(record.id, value) end
    return true, value
end
return M
