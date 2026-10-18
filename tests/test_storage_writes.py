"""Characterize storage setter calls independently of engine persistence costs."""
from test_editor import ROOT, runtime


def test_repeated_saves_call_set_even_when_override_is_unchanged(runtime):
    runtime.execute('''
        local data, calls = {}, 0
        local section = {
            get=function(_, k) return data[k] end,
            set=function(_, k, v) calls=calls+1; data[k]=v end,
        }
        for _, case in ipairs({
            {id='fExample', value=0.3, changed=0.7},
            {id='iExample', value=1, changed=2},
            {id='sExample', value='Yes', changed=''},
        }) do
            local before = calls
            assert(model.save(section, case, tostring(case.value)))
            assert(model.save(section, case, tostring(case.value)))
            assert(calls == before + 2 and data[case.id] == nil)
            assert(model.save(section, case, tostring(case.changed)))
            assert(model.save(section, case, tostring(case.changed)))
            assert(calls == before + 4 and data[case.id] == case.changed)
        end
        local before = calls
        assert(not model.save(section, {id='iExample', value=1}, '1.5'))
        assert(calls == before, 'Invalid input must not write storage')
    ''')


def test_player_reinitialization_rewrites_every_record(runtime):
    runtime.execute('''
        local records = {{id='fencumberedmoveeffect', value=0.3},
            {id='iMonthsToRespawn', value=2}, {id='sYes', value='Yes'}}
        writeCalls = 0
        package.preload['scripts.gmst_profiles.editor_model'] = function() return model end
        package.preload['openmw.core'] = function() return {getGMST=function(id)
            return model.encode(id == model.catalogId and records or {})
        end} end
        local sections = {}
        package.preload['openmw.storage'] = function() return {playerSection=function(name)
            if not sections[name] then
                local data = {}
                sections[name] = {get=function(_, k) return data[k] end,
                    set=function(_, k, v) writeCalls=writeCalls+1; data[k]=v end}
            end
            return sections[name]
        end} end
        package.preload['openmw.interfaces'] = function() return {Settings={
            registerPage=function() end, registerGroup=function() end,
        }} end
    ''')
    player = (ROOT / 'scripts/gmst_profiles/player.lua').read_text()
    runtime.execute('(function()\n' + player + '\nend)()')
    runtime.execute('assert(writeCalls == 3)')
    runtime.execute('(function()\n' + player + '\nend)()')
    runtime.execute('assert(writeCalls == 6)')
