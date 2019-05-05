--dir names
if WG then
	LIBS_DIR = WG.SB_LIBS_DIR
	SB = WG.SB

	-- Scene = WG.Scene
else
	LIBS_DIR = GG.SB_LIBS_DIR
	SB = GG.SB
end
LUAUI_DIR = "LuaUI/"

SB_DIR = "scen_edit/"
SB_COMMAND_DIR = SB_DIR .. "command/"
SB_IMG_DIR = LUAUI_DIR .. "images/scenedit/"

SB_ROOT = "springboard/"
SB_PROJECTS_DIR = SB_ROOT .. "projects/"
SB_ASSETS_DIR = SB_ROOT .. "assets/"
SB_EXTS_DIR = SB_ROOT .. "exts/"
SB_EXPORTS_DIR = SB_ROOT .. "exports/"

-- TODO: maybe some of these _sl_ modopts should be parsed into SL_ instead of SB_
-- that said, having both SB_ and SL_ would be error prone
local modOpts = Spring.GetModOptions()
local writePath = modOpts._sl_write_path
if writePath then
    -- luacheck: ignore
    if writePath:sub(-1) ~= '/' then
        writePath = writePath .. '/'
    end
    SB_WRITE_PATH = writePath
    SB_ROOT_ABS = SB_WRITE_PATH .. "springboard/"
    SB_PROJECTS_ABS_DIR = SB_ROOT_ABS .. "projects/"
    SB_ASSETS_ABS_DIR = SB_ROOT_ABS .. "assets/"
    SB_EXTS_ABS_DIR = SB_ROOT_ABS .. "exts/"
end
SB_LAUNCHER_VERSION = modOpts._sl_launcher_version

--properties
SB_FILE_EXT = ".sdz"
SB_S11N_EXT = ".lua"
SB_MAP_INFO_FILE_EXT = ".lua"

SB_SCREENSHOT_FILE = "sb_screen.jpg"

SB_USE_PLAY_PAUSE = false

SB_IMG_EXTS = {'.jpg','.bmp','.png','.tga','.tif'}

--mod opts
local modOpts = Spring.GetModOptions()

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
    -- Colorbars = Chili.Colorbars
    Button = Chili.Button
    Label = Chili.Label
    Line = Chili.Line
    EditBox = Chili.EditBox
    Window = Chili.Window
    ScrollPanel = Chili.ScrollPanel
    LayoutPanel = Chili.LayoutPanel
    StackPanel = Chili.StackPanel
    -- Grid = Chili.Grid
    TextBox = Chili.TextBox
    Image = Chili.Image
    ImageListView = Chili.ImageListView
    TreeView = Chili.TreeView
    Trackbar = Chili.Trackbar
    -- TabBar = Chili.TabBar
    -- TabPanel = Chili.TabPanel
    Progressbar = Chili.Progressbar
    screen0 = Chili.Screen0
end

s11n = SB.s11n
