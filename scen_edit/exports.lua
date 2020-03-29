--dir names
if WG then
	LIBS_DIR = WG.SB_LIBS_DIR
	SB = WG.SB

	-- Scene = WG.Scene
else
	LIBS_DIR = GG.SB_LIBS_DIR
	SB = GG.SB
end

SB.DIRS = {
    IMG      = 'LuaUI/images/scenedit/',
    SRC      = 'scen_edit/',
    ROOT     = 'springboard/',
    PROJECTS = 'springboard/projects/',
    ASSETS   = 'springboard/assets/',
    EXTS     = 'springboard/exts/',
    EXPORTS  = 'springboard/exports/',
    TMP      = 'springboard/tmp/',
}

-- TODO: maybe some of these _sl_ modopts should be parsed into SL_ instead of SB_
-- that said, having both SB_ and SL_ would be error prone
local modOpts = Spring.GetModOptions()
local writePath = modOpts._sl_write_path
if writePath then
    -- luacheck: ignore
    if writePath:sub(-1) ~= '/' then
        writePath = writePath .. '/'
    end
    SB.DIRS.WRITE_PATH = writePath
    SB.DIRS.ROOT_ABS = SB.DIRS.WRITE_PATH .. "springboard/"
    SB.DIRS.PROJECTS_ABS = SB.DIRS.ROOT_ABS .. "projects/"
    SB.DIRS.ASSETS_ABS = SB.DIRS.ROOT_ABS .. "assets/"
    SB.DIRS.EXTS_ABS = SB.DIRS.ROOT_ABS .. "exts/"
end
SB_LAUNCHER_VERSION = modOpts._sl_launcher_version

SB_USE_PLAY_PAUSE = false

SB_IMG_EXTS = {'.jpg','.bmp','.png','.tga','.tif'}

--mod opts
local modOpts = Spring.GetModOptions()

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
