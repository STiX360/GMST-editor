from pathlib import Path
import pytest
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture
def runtime():
    runner = LuaRuntime(unpack_returned_tuples=True)
    runner.execute('model = (function()\n' + (ROOT / 'scripts/gmst_profiles/editor_model.lua').read_text() + '\nend)()')
    return runner


def test_catalog_roundtrip_preserves_strings_and_float_precision(runtime):
    runtime.execute('''
        local records = {
            {id='sExample', value='quote " colon: newline\\n and \\0 null'},
            {id='fExample', value=0.123456789012345},
            {id='sEmpty', value=''},
        }
        local decoded = model.decode(model.encode(records))
        assert(#decoded == #records)
        for i, r in ipairs(records) do
            assert(decoded[i].id == r.id and decoded[i].value == r.value)
        end
    ''')


def test_numeric_validation_and_empty_strings(runtime):
    runtime.execute('''
        assert(model.parse('iExample', '2', 1) == 2)
        assert(model.parse('iExample', '2.5', 1) == nil)
        assert(model.parse('iExample', '2147483648', 1) == nil)
        assert(model.parse('iExample', '-2147483648', 1) == -2147483648)
        assert(model.parse('fExample', '0.123', 1) == 0.123)
        assert(model.parse('fExample', '1e999', 1) == nil)
        assert(model.parse('fExample', 'garbage', 1) == nil)
        assert(model.parse('sExample', '', 'yes') == '')
        assert(not model.valid('fExample', 'string', 1))
        assert(not model.valid('fExample', 0/0, 1))
        assert(not model.valid('fExample', math.huge, 1))
    ''')


def test_float_comparison_and_display(runtime):
    runtime.execute('''
        assert(model.format(0.30000001192093) == '0.3')
        assert(model.matches(0.123000003, 0.123))
        assert(not model.matches(0, 1e-8))
        assert(not model.matches(2000000000, 2000000001))
        assert(not model.matches('1', 1))
    ''')


def test_native_number_field_saves_on_blur_and_resets(runtime):
    runtime.execute('''
        local sections, renderers = {}, {}
        nativeRenderers = renderers
        local function section(name)
            if not sections[name] then
                local data, callback = {}, nil
                sections[name] = {
                    get=function(_, k) return data[k] end,
                    set=function(_, k, v) data[k]=v; if callback then callback(name, k) end end,
                    subscribe=function(_, fn) callback=fn end,
                }
            end
            return sections[name]
        end
        local templates = {box={}, padding={}, interval={}, textNormal={}, textParagraph={}, textEditBox={}, textEditLine={}}
        package.preload['scripts.gmst_profiles.editor_model'] = function() return model end
        package.preload['scripts.gmst_profiles.labels'] = function() return {} end
        package.preload['openmw.storage'] = function() return {playerSection=section} end
        package.preload['openmw.core'] = function() return {} end
        package.preload['openmw.ui'] = function() return {
            TYPE={Flex='Flex'}, content=function(t) return t end, showMessage=function() end,
        } end
        package.preload['openmw.util'] = function() return {vector2=function(x,y) return {x,y} end} end
        package.preload['openmw.async'] = function() return {callback=function(_,fn) return fn end} end
        package.preload['openmw.interfaces'] = function() return {
            MWUI={templates=templates}, Settings={registerRenderer=function(k,fn) renderers[k]=fn end},
        } end
    ''')
    runtime.execute((ROOT / 'scripts/gmst_profiles/menu.lua').read_text())
    runtime.execute('''
        local storage = require('openmw.storage')
        local overrides = storage.playerSection(model.overridesSection)
        local values = storage.playerSection(model.valuesSection)
        local id = 'fencumberedmoveeffect'
        local field = nativeRenderers.gmstEditorNumber(0.3, function(v) values:set(id,v) end,
            {id=id, baseline=0.3})
        local edit = field.content[1].content[1].content[1]
        edit.events.textChanged('0.123')
        assert(overrides:get(id) == nil)
        edit.events.focusLoss()
        assert(overrides:get(id) == 0.123 and values:get(id) == 0.123)
        field.content[1].content[3].events.mouseClick()
        assert(overrides:get(id) == nil and values:get(id) == 0.3)
        edit.events.textChanged('0.7')
        edit.events.focusLoss()
        assert(overrides:get(id) == 0.7)
        values:set(id, 0.3)
        assert(overrides:get(id) == nil)
        local stringId = 'sYes'
        local stringSection = model.sectionFor(stringId)
        local strings = storage.playerSection(stringSection)
        local stringField = nativeRenderers.gmstEditorString('Yes', function(v) strings:set(stringId,v) end,
            {id=stringId, baseline='Yes', section=stringSection})
        local stringEdit = stringField.content[1].content[1].content[1]
        stringEdit.events.textChanged('')
        stringEdit.events.focusLoss()
        assert(overrides:get(stringId) == '' and strings:get(stringId) == '')
        strings:set(stringId, 'Yes')
        assert(overrides:get(stringId) == nil)
        stringEdit.events.textChanged('New label')
        stringEdit.events.focusLoss()
        stringField.content[1].content[3].events.mouseClick()
        assert(overrides:get(stringId) == nil and strings:get(stringId) == 'Yes')
        require('openmw.core').getGMST = function(id)
            if id == model.catalogId then return model.encode({{id='sYes',value='Yes'}}) end
            return 'Yes'
        end
        local formValue = {id='',text=''}
        local function setForm(v) formValue=v end
        local form = nativeRenderers.gmstEditorAdvanced(formValue, setForm)
        form.content[2].content[1].events.textChanged('syes')
        form.content[3].events.mouseClick()
        assert(formValue.id == 'sYes' and formValue.text == 'Yes')
        form = nativeRenderers.gmstEditorAdvanced(formValue, setForm)
        form.content[5].content[1].events.textChanged('Test string')
        form.content[6].content[1].events.mouseClick()
        assert(overrides:get('sYes') == 'Test string')
        assert(strings:get('sYes') == 'Test string')
        form.content[2].content[1].events.textChanged('otherRecord')
        form.content[6].content[1].events.mouseClick()
        assert(overrides:get('sYes') == 'Test string')
        local searchValue = {query=''}
        local function setSearch(v) searchValue=v end
        local search = nativeRenderers.gmstEditorSearch({query='yes'}, setSearch,
            {records={{id='sYes',value='Yes'}, {id='fJumpHeight',value=2}}, limit=10})
        search.content[2].content[1].events.textChanged('jump')
        assert(searchValue.query == 'jump')
        local resultColumn = search.content[4].content[1].content[1]
        assert(resultColumn.type == 'Flex' and resultColumn.props.horizontal == false)
        assert(resultColumn.content[1].props.text == 'sYes')
        assert(resultColumn.content[3].props.text:find('sYes', 1, true))
        assert(resultColumn.content[1].template == require('openmw.interfaces').MWUI.templates.textParagraph)
        local resultValue = resultColumn.content[5]
        local resultEdit = resultValue.content[1].content[1].content[1]
        resultEdit.events.textChanged('Search string')
        resultEdit.events.focusLoss()
        assert(overrides:get('sYes') == 'Search string')
    ''')


def test_search_and_direct_edit_keep_all_records_accessible_without_gameplay_group(runtime):
    runtime.execute('''
        local records = {
            {id='fencumberedmoveeffect',value=0.3}, {id='fprojectileminspeed',value=1000},
            {id='iDaysToRespawn',value=3}, {id='sYes',value='Yes'},
            {id='Blood_Model_0',value='BloodSplat.nif'}, {id='fCustomValue',value=7},
        }
        local sections, pages, groups = {}, {}, {}
        registeredRecords = records
        registeredPages = pages
        registeredGroups = groups
        testSections = sections
        package.preload['scripts.gmst_profiles.editor_model'] = function() return model end
        package.preload['openmw.core'] = function() return {getGMST=function(id)
            if id == model.catalogId then return model.encode(records) end
            if id == model.appliedId then return model.encode({}) end
            for _, r in ipairs(records) do if r.id == id then return r.value end end
        end} end
        package.preload['openmw.storage'] = function() return {playerSection=function(name)
            if not sections[name] then
                local data = {}
                sections[name] = {get=function(_,k) return data[k] end, set=function(_,k,v) data[k]=v end}
            end
            return sections[name]
        end} end
        package.preload['openmw.interfaces'] = function() return {Settings={
            registerPage=function(p) assert(not pages[p.key]); pages[p.key]=p end,
            registerGroup=function(g) assert(not groups[g.key]); assert(pages[g.page]); groups[g.key]=g end,
        }} end
        require('openmw.storage').playerSection(model.overridesSection):set('sYes', 'Saved label')
        require('openmw.storage').playerSection(model.overridesSection):set('fencumberedmoveeffect', 0.7)
    ''')
    runtime.execute('player = (function()\n' + (ROOT / 'scripts/gmst_profiles/player.lua').read_text() + '\nend)()')
    runtime.execute('''
        local pageCount = 0
        for _ in pairs(registeredPages) do pageCount = pageCount + 1 end
        assert(pageCount == 1 and registeredPages.GmstEditor)
        assert(player.interface.exposedCount() == #registeredRecords)
        assert(registeredGroups[model.valuesSection] == nil, 'Gameplay group must not be registered')
        assert(testSections[model.valuesSection]:get('fencumberedmoveeffect') == 0.7,
            'Removing the Gameplay group must preserve its saved override')
        local groupCount = 0
        for _ in pairs(registeredGroups) do groupCount = groupCount + 1 end
        assert(groupCount == 3)
        local direct = registeredGroups.SettingsPlayerGmstEditorAdvanced
        assert(direct and direct.page == 'GmstEditor')
        assert(direct.settings[1].renderer == 'gmstEditorAdvanced')
        local search = registeredGroups.SettingsPlayerGmstEditorSearch
        assert(search and search.page == 'GmstEditor')
        assert(search.settings[1].renderer == 'gmstEditorSearch')
        assert(#search.settings[1].argument.records == #registeredRecords)
        local results = model.search(search.settings[1].argument.records, {}, 'Weight slowdown')
        assert(#results == 1 and results[1].id == 'fencumberedmoveeffect')
        for _, record in ipairs(registeredRecords) do
            local section = testSections[model.sectionFor(record.id)]
            assert(section:get(record.id) ~= nil)
        end
        local strings = testSections[model.sectionFor('sYes')]
        assert(strings:get('sYes') == 'Saved label')
        assert(player.interface.set('syes', 'Changed'))
        assert(strings:get('sYes') == 'Changed')
        assert(player.interface.reset('syes'))
        assert(strings:get('sYes') == 'Yes')
        local numbers = testSections[model.sectionFor('fprojectileminspeed')]
        assert(player.interface.set('fprojectileminspeed', '5'))
        assert(numbers:get('fprojectileminspeed') == 5)
        assert(player.interface.reset('fprojectileminspeed'))
        assert(numbers:get('fprojectileminspeed') == 1000)
        assert(player.interface.set('fencumberedmoveeffect', '0.5'))
        assert(testSections[model.valuesSection]:get('fencumberedmoveeffect') == 0.5)
        assert(player.interface.reset('fencumberedmoveeffect'))
        assert(testSections[model.valuesSection]:get('fencumberedmoveeffect') == 0.3)
    ''')
