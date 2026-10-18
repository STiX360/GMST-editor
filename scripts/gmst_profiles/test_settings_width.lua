local ui = require('openmw.ui')
local util = require('openmw.util')
local async = require('openmw.async')
local I = require('openmw.interfaces')
local width = 400
local element
local label = { template = I.MWUI.templates.textNormal,
    props = { position = util.vector2(10, 10), text = 'Page: 400 px; relative width: 100%' } }
element = ui.create {
    type = ui.TYPE.Widget,
    props = { size = util.vector2(width, 120), relativeSize = util.vector2(1, 0) },
    content = ui.content {
        label,
        { template = I.MWUI.templates.horizontalLine,
            props = { position = util.vector2(0, 50), relativeSize = util.vector2(1, 0) } },
        { template = I.MWUI.templates.box,
            props = { position = util.vector2(10, 70) },
            content = ui.content { { template = I.MWUI.templates.padding,
                content = ui.content { { template = I.MWUI.templates.textNormal,
                    props = { text = 'Toggle page width 400 / 700' } } } } },
            events = { mouseClick = async:callback(function()
                width = width == 400 and 700 or 400
                label.props.text = 'Page: ' .. width .. ' px; relative width: 100%'
                element.layout.props.size = util.vector2(width, 120)
                element:update()
                print('GMST_WIDTH_PROBE: explicit=' .. width .. ' screen=' .. tostring(ui.screenSize()))
            end) },
        },
    },
}
ui.registerSettingsPage { name = 'GMST Width Probe', element = element }
print('GMST_WIDTH_PROBE: registered fixed=400 relative=1 screen=' .. tostring(ui.screenSize()))
for key in pairs(ui) do
    if key:lower():find('size') or key:lower():find('window') or key:lower():find('setting') then
        print('GMST_WIDTH_API: ' .. key)
    end
end
return {}
