local core = require('openmw.core')
local I = require('openmw.interfaces')
local scenario = require('scripts.gmst_exit_case')
local elapsed, done = 0, false

return { engineHandlers = { onFrame = function(dt)
    if done then return end
    elapsed = elapsed + dt
    if elapsed < 5 then return end
    done = true
    local ok, err = pcall(function()
        local editor = I.GmstEditor
        if scenario == 'absent' then
            assert(not editor, 'Editor unexpectedly loaded')
        else
            assert(editor and #editor.records() > 1000, 'Editor catalog missing')
            if scenario == 'unchanged' then
                for _, record in ipairs(editor.records()) do
                    assert(editor.set(record.id, tostring(record.value)))
                end
            elseif scenario == 'changed' then
                assert(editor.set('fEncumberedMoveEffect', '0.123'))
                assert(editor.set('iMonthsToRespawn', '2'))
                assert(editor.set('sYes', 'Shutdown test'))
            end
            print('GMST_EXIT_RECORDS: ' .. #editor.records())
        end
    end)
    if not ok then print('GMST_EXIT_FAIL: ' .. tostring(err)) end
    print('GMST_EXIT_REQUEST: ' .. scenario)
    core.quit()
end } }
