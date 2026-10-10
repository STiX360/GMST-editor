local core = require('openmw.core')
local storage = require('openmw.storage')
local ui = require('openmw.ui')
local util = require('openmw.util')
local async = require('openmw.async')
local I = require('openmw.interfaces')
local model = require('scripts.gmst_profiles.editor_model')
local overrides = storage.playerSection(model.overridesSection)
local baselines = {}
local watched = {}
local function watchSection(name)
    if watched[name] then return end
    local values = storage.playerSection(name)
    watched[name] = values
    values:subscribe(async:callback(function(_, key)
        -- The native group Reset changes values directly, outside the field renderer.
        if key and baselines[key] ~= nil then
            model.save(overrides, { id = key, value = baselines[key] }, tostring(values:get(key)))
        end
    end))
end
local function text(s)
    return { template = I.MWUI.templates.textNormal, props = { text = s } }
end
local function button(s, callback)
    return { template = I.MWUI.templates.box,
        content = ui.content { { template = I.MWUI.templates.padding, content = ui.content { text(s) } } },
        events = { mouseClick = async:callback(callback) } }
end
local function row(content)
    return { type = ui.TYPE.Flex, props = { horizontal = true }, content = ui.content(content) }
end
local function input(value, width, height, callback)
    return { template = I.MWUI.templates.box, content = ui.content {
        { template = height and I.MWUI.templates.textEditBox or I.MWUI.templates.textEditLine,
            props = { text = value, size = util.vector2(width, height or 24), autoSize = false },
            events = { textChanged = async:callback(callback) } },
    } }
end
local function renderValue(value, set, argument)
    baselines[argument.id] = argument.baseline
    watchSection(argument.section or model.valuesSection)
    local isString = type(argument.baseline) == 'string'
    local draft = model.format(value)
    local field = input(draft, isString and 230 or 100, isString and 48 or nil, function(s) draft = s end)
    field.events = { focusLoss = async:callback(function()
        local ok, result = model.save(overrides, { id = argument.id, value = argument.baseline }, draft)
        if ok then set(result) else ui.showMessage(result); set(value) end
    end) }
    -- focusLoss belongs to the TextEdit, not its border container.
    field.content[1].events.focusLoss = field.events.focusLoss
    field.events = nil
    return { type = ui.TYPE.Flex, content = ui.content {
        row { field, { template = I.MWUI.templates.interval }, button('Reset', function()
            overrides:set(argument.id, nil); set(argument.baseline)
        end) },
        text('Original: ' .. (isString and model.format(argument.baseline):gsub('[\r\n]', ' '):sub(1, 24)
            or model.format(argument.baseline))),
    } }
end
I.Settings.registerRenderer('gmstEditorNumber', renderValue)
I.Settings.registerRenderer('gmstEditorString', renderValue)
I.Settings.registerRenderer('gmstEditorAdvanced', function(value, set)
    local idDraft, valueDraft = value.id or '', value.text or ''
    local lookup = {}
    for _, r in ipairs(model.decode(core.getGMST(model.catalogId))) do lookup[r.id:lower()] = r end
    local function find() return lookup[idDraft:lower():match('^%s*(.-)%s*$')] end
    return { type = ui.TYPE.Flex, content = ui.content {
        text('GMST identifier'),
        input(idDraft, 230, nil, function(s) idDraft = s end),
        button('Read Value', function()
            local r = find()
            if not r then ui.showMessage('Unknown GMST identifier.'); return end
            local saved = overrides:get(r.id)
            set { id = r.id, text = model.format(saved ~= nil and saved or core.getGMST(r.id)) }
        end),
        text('New value'),
        input(valueDraft, 230, 48, function(s) valueDraft = s end),
        row {
            button('Save', function()
                local r = find()
                -- Require Read Value after changing the identifier to avoid applying a stale draft.
                if not r or r.id:lower() ~= (value.id or ''):lower() then
                    ui.showMessage('Read the record value first.'); return
                end
                local ok, result = model.save(overrides, r, valueDraft)
                if not ok then ui.showMessage(result); return end
                storage.playerSection(model.sectionFor(r.id)):set(r.id, result)
                set { id = r.id, text = model.format(result) }
                ui.showMessage('Saved for next launch.')
            end),
            { template = I.MWUI.templates.interval },
            button('Reset', function()
                local r = find()
                if not r then ui.showMessage('Unknown GMST identifier.'); return end
                overrides:set(r.id, nil)
                storage.playerSection(model.sectionFor(r.id)):set(r.id, r.value)
                set { id = r.id, text = model.format(r.value) }
            end),
        },
    } }
end)
return {}
