SCEN_EDIT_DIR = "scen_edit/"
SCEN_EDIT_COMMAND_DIR = SCEN_EDIT_DIR .. "command/"
LUAUI_DIR = "LuaUI/"
SCEN_EDIT_IMG_DIR = LUAUI_DIR .. "images/scenedit/"
local modOpts = Spring.GetModOptions()
scenarioFile = modOpts.scenario_file
devMode = modOpts.dev_mode

if WG and WG.Chili then
    -- setup Chili
    Chili = WG.Chili
    Checkbox = Chili.Checkbox
    Button = Chili.Button
    Label = Chili.Label
    EditBox = Chili.EditBox
    Window = Chili.Window
    ScrollPanel = Chili.ScrollPanel
    StackPanel = Chili.StackPanel
    Grid = Chili.Grid
    TextBox = Chili.TextBox
    Image = Chili.Image
    TreeView = Chili.TreeView
    Trackbar = Chili.Trackbar
    screen0 = Chili.Screen0
end
