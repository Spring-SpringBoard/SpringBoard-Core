
SCEN_EDIT_VIEW_DIR = SCEN_EDIT_DIR .. "view/"
SCEN_EDIT_VIEW_PANELS_DIR = SCEN_EDIT_VIEW_DIR .. "panels/"
SCEN_EDIT_VIEW_MAIN_WINDOW_DIR = SCEN_EDIT_VIEW_DIR .. "main_window/"
SCEN_EDIT_VIEW_ALLIANCE_DIR = SCEN_EDIT_VIEW_DIR .. "alliance/"
SCEN_EDIT_VIEW_ACTIONS_DIR = SCEN_EDIT_VIEW_DIR .. "actions/"

View = LCS.class{}

function View:init()
    SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "view_area_manager_listener.lua")
    SCEN_EDIT.IncludeDir(SCEN_EDIT_VIEW_DIR)
    SCEN_EDIT.Include(SCEN_EDIT_VIEW_PANELS_DIR .. "abstract_type_panel.lua")
    SCEN_EDIT.IncludeDir(SCEN_EDIT_VIEW_PANELS_DIR)
	SCEN_EDIT.Include(SCEN_EDIT_VIEW_MAIN_WINDOW_DIR .. "abstract_main_window_panel.lua")
	SCEN_EDIT.IncludeDir(SCEN_EDIT_VIEW_MAIN_WINDOW_DIR)
	SCEN_EDIT.IncludeDir(SCEN_EDIT_VIEW_ALLIANCE_DIR)
	SCEN_EDIT.Include(SCEN_EDIT_VIEW_ACTIONS_DIR .. "abstract_action.lua")
	SCEN_EDIT.IncludeDir(SCEN_EDIT_VIEW_ACTIONS_DIR)
    SCEN_EDIT.clipboard = Clipboard()
    self.areaViews = {}
    if devMode then
--          self.runtimeView = RuntimeView()
    end
    self.selectionManager = SelectionManager()
    self.displayDevelop = true
	self.tabbedWindow = TabbedWindow()
    self.commandWindow = CommandWindow()
	self.commandWindow.window:Hide()
    self.modelShaders = ModelShaders()

--     self.teamSelector = TeamSelector()
end

function View:Update()
    if self.teamSelector then
		self.teamSelector:Update()
	end
    self.selectionManager:Update()
end

function View:drawRect(x1, z1, x2, z2)
    if x1 < x2 then
        _x1 = x1
        _x2 = x2
    else
        _x1 = x2
        _x2 = x1
    end
    if z1 < z2 then
        _z1 = z1
        _z2 = z2
    else
        _z1 = z2
        _z2 = z1 
    end
    gl.DrawGroundQuad(_x1, _z1, _x2, _z2)
end

function View:drawRects()
    gl.PushMatrix()
    for _, areaView in pairs(self.areaViews) do
        areaView:Draw()
    end
    gl.PopMatrix()
end

function View:DrawWorld()
end

function View:DrawWorldPreUnit()
    if self.displayDevelop then
        self:drawRects()
    end
    self.selectionManager:DrawWorldPreUnit()
end

function View:DrawScreen()
    gl.PushMatrix()
        local w, h = Spring.GetScreenGeometry()
        local fontSize = 20
        if self.font == nil then
            local fontName = "FreeSansBold.otf"
            self.font = gl.LoadFont(fontName, fontSize)
        end

        local y = 10
        local text
        local x = w - 200
        if SCEN_EDIT.projectDir ~= nil then
            text = "Project:" .. SCEN_EDIT.projectDir
        else
            text = "Project not saved"
        end
        local x = w - self.font:GetTextWidth(text) * fontSize - 10
        self.font:Print(text, x, y, 20, 'o')
		
-- 		gl.PushMatrix()
-- 			local i = 1
-- 			local step = 200
-- 			for texType, shadingTex in pairs(SCEN_EDIT.model.textureManager.shadingTextures) do
-- 				gl.Texture(shadingTex)
-- 				gl.TexRect(i * step, 1 * step, (i+1) * step, 2 * step)
-- 				i = i + 1
-- 			end
-- 			i = 1
-- 			for _, tex in pairs(SCEN_EDIT.model.textureManager.shadingTextureNaming) do
-- 				gl.Texture("$" .. tex.engineName)
-- 				gl.TexRect(i * step, 2 * step, (i+1) * step, 3 * step)
-- 				i = i + 1
-- 			end
-- 			local mapTex = SCEN_EDIT.model.textureManager.mapFBOTextures[0][0]
-- 			if mapTex then
-- 				gl.Texture(mapTex.texture)
-- 				gl.TexRect(i * step, 1 * step, (i+1) * step, (1+1) * step)
-- 			end
-- 		gl.PopMatrix()
    gl.PopMatrix()
end

function View:SetMainPanel(panel)
	local mp = self.tabbedWindow.mainPanel

	-- initialize if needed
	if mp._hidden == nil then
		mp._hidden = {}
	end
	
	-- hide existing
	local existing = mp.children[1]
	if existing ~= nil then
		mp._hidden[existing] = existing
		existing:Hide()
	end

	-- add new or show hidden
	if mp._hidden[panel] == nil then
		mp:AddChild(panel)
	else
		mp._hidden[panel]:Show()
		mp._hidden[panel] = nil
	end
end
