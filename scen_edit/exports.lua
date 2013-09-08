--dir names
SCEN_EDIT_DIR = "scen_edit/"
LIBS_DIR = "libs/"
SCEN_EDIT_COMMAND_DIR = SCEN_EDIT_DIR .. "command/"
LUAUI_DIR = "LuaUI/"
SCEN_EDIT_IMG_DIR = LUAUI_DIR .. "images/scenedit/"
--FIXME: don't assume path, find it programatically
TOOLBOX_DIR = "games/ToolBox.sdd/"
SCEN_EDIT_EXAMPLE_DIR_RAW_FS = TOOLBOX_DIR .. "examples/"

--properties
SCEN_EDIT_FILE_EXT = ".sea"

--mod opts
local modOpts = Spring.GetModOptions()
scenarioFile = modOpts.scenario_file
devMode = not modOpts.play_mode
if devMode then
    Spring.Echo("Scenario Editor mode: dev")
else
    Spring.Echo("Scenario Editor mode: play")
end

--chili export
if WG and WG.Chili then
    -- setup Chili
    Chili = WG.Chili
    Checkbox = Chili.Checkbox
    Control = Chili.Control
    ComboBox = Chili.ComboBox
    Button = Chili.Button
    Label = Chili.Label
    EditBox = Chili.EditBox
    Window = Chili.Window
    ScrollPanel = Chili.ScrollPanel
    LayoutPanel = Chili.LayoutPanel
    StackPanel = Chili.StackPanel
    Grid = Chili.Grid
    TextBox = Chili.TextBox
    Image = Chili.Image
    ImageListView = Chili.ImageListView
    TreeView = Chili.TreeView
    Trackbar = Chili.Trackbar
	TabBar = Chili.TabBar
	TabPanel = Chili.TabPanel
    screen0 = Chili.Screen0
end
