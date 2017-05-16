--dir names
LIBS_DIR = "libs/"
LUAUI_DIR = "LuaUI/"

SCEN_EDIT = {}
SCEN_EDIT_DIR = "scen_edit/"
SCEN_EDIT_COMMAND_DIR = SCEN_EDIT_DIR .. "command/"
SCEN_EDIT_IMG_DIR = LUAUI_DIR .. "images/scenedit/"

--FIXME: don't assume path, find it programatically
--FIXME: not used now
-- SCENARIO_EDITOR_DIR = "games/ToolBox.sdd/"

SB_ROOT = "springboard/"
SB_PROJECTS_DIR = SB_ROOT .. "projects/"
SB_ASSETS_DIR   = SB_ROOT .. "assets/"

--properties
SCEN_EDIT_FILE_EXT = ".sdz"
SCEN_EDIT_FEATURE_PLACER_FILE_EXT = ".lua"

--mod opts
local modOpts = Spring.GetModOptions()

SCEN_EDIT.projectDir = modOpts.project_dir
hasScenarioFile = (tonumber(modOpts.has_scenario_file) or 0) ~= 0

--chili export
if WG and WG.SBChili then
    -- setup Chili
    Chili = WG.SBChili
    Checkbox = Chili.Checkbox
    Control = Chili.Control
    ComboBox = Chili.ComboBox
    Colorbars = Chili.Colorbars
    Button = Chili.Button
    Label = Chili.Label
    Line = Chili.Line
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

if WG then
    s11n = WG.s11n
	WG.SCEN_EDIT = SCEN_EDIT
elseif GG then
    s11n = GG.s11n
	GG.SCEN_EDIT = SCEN_EDIT
end
