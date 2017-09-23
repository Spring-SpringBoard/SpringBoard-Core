--dir names
LIBS_DIR = "libs/"
LUAUI_DIR = "LuaUI/"

SB = {}
SB_DIR = "scen_edit/"
SB_COMMAND_DIR = SB_DIR .. "command/"
SB_IMG_DIR = LUAUI_DIR .. "images/scenedit/"

SB_ROOT = "springboard/"
SB_PROJECTS_DIR = SB_ROOT .. "projects/"
SB_ASSETS_DIR = SB_ROOT .. "assets/"
SB_EXTS_DIR = SB_ROOT .. "exts/"

--properties
SB_FILE_EXT = ".sdz"
SB_S11N_EXT = ".lua"
SB_MAP_INFO_FILE_EXT = ".lua"

SB_SCREENSHOT_FILE = "sb_screen.jpg"

SB_USE_PLAY_PAUSE = false

SB_IMG_EXTS = {'.jpg','.bmp','.png','.tga','.tif'}

--mod opts
local modOpts = Spring.GetModOptions()

SB.projectDir = modOpts.project_dir
hasScenarioFile = (tonumber(modOpts.has_scenario_file) or 0) ~= 0

local sb_gameMode = (tonumber(modOpts.sb_gameMode) or 0)
SB.SyncModel = Script.GetSynced() and sb_gameMode ~= "play"

SB.__populated = false

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
    Progressbar = Chili.Progressbar
    screen0 = Chili.Screen0
end

if WG then
    s11n = WG.s11n
	WG.SB = SB
elseif GG then
    s11n = GG.s11n
	GG.SB = SB
end
