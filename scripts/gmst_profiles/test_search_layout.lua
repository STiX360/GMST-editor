local I = require('openmw.interfaces')
local storage = require('openmw.storage')
local done, elapsed = false, 0
return { engineHandlers = { onFrame = function(dt)
    if done then return end
    elapsed = elapsed + dt
    if elapsed < 3 then return end
    done = true
    storage.playerSection('SettingsPlayerGmstEditorSearch'):set('query', { query = 'dialo' })
    I.UI.setMode(I.UI.MODE.MainMenu)
end } }
