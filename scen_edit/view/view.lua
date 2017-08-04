SB_VIEW_DIR = Path.Join(SB_DIR, "view/")

SB_VIEW_MAIN_WINDOW_DIR = Path.Join(SB_VIEW_DIR, "main_window/")
SB_VIEW_ACTIONS_DIR = Path.Join(SB_VIEW_DIR, "actions/")

SB_VIEW_OBJECT_DIR = Path.Join(SB_VIEW_DIR, "object/")
SB_VIEW_MAP_DIR = Path.Join(SB_VIEW_DIR, "map/")
SB_VIEW_TRIGGER_DIR = Path.Join(SB_VIEW_DIR, "trigger/")
SB_VIEW_GENERAL_DIR = Path.Join(SB_VIEW_DIR, "general/")
SB_VIEW_FLOATING_DIR = Path.Join(SB_VIEW_DIR, "floating/")
SB_VIEW_DIALOG_DIR = Path.Join(SB_VIEW_DIR, "dialog/")

View = LCS.class{}

function View:init()
    SB.IncludeDir(SB_VIEW_DIR)
	SB.Include(Path.Join(SB_VIEW_MAIN_WINDOW_DIR, "main_window_panel.lua"))
	SB.IncludeDir(SB_VIEW_MAIN_WINDOW_DIR)
	SB.Include(Path.Join(SB_VIEW_ACTIONS_DIR, "abstract_action.lua"))
	SB.IncludeDir(SB_VIEW_ACTIONS_DIR)

    SB.IncludeDir(SB_VIEW_OBJECT_DIR)
    SB.IncludeDir(SB_VIEW_MAP_DIR)
    SB.IncludeDir(SB_VIEW_TRIGGER_DIR)
    SB.IncludeDir(SB_VIEW_GENERAL_DIR)
    SB.IncludeDir(SB_VIEW_FLOATING_DIR)
    SB.IncludeDir(SB_VIEW_DIALOG_DIR)

    SB.clipboard = Clipboard()
    self.areaViews = {}
    self.selectionManager = SelectionManager()
    self.displayDevelop = true
	self.tabbedWindow = TabbedWindow()

    self.modelShaders = ModelShaders()

    self.bottomBar = BottomBar()
    self.teamSelector = TeamSelector()
    self.lobbyButton = LobbyButton()
    self.projectStatus = ProjectStatus()
end

function View:Update()
    if self.teamSelector then
		self.teamSelector:Update()
	end
    self.selectionManager:Update()

    self.bottomBar:Update()
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
        local vsx, vsy = Spring.GetViewGeometry()
        if not rotate then
            rotate = 0
            id = 0
        end
--         gl.PushMatrix()
--         gl.DepthTest(GL.LEQUAL)
--         gl.DepthMask(true)
--         local shaderObj = SB.view.modelShaders:GetShader()
--         gl.UseShader(shaderObj.shader)
--         gl.Uniform(shaderObj.timeID, os.clock())
--         --gl.Translate(100, Spring.GetGroundHeight(100, 100), 100)
--         gl.Translate(vsx / 2, 500, 50)
--         gl.Rotate(30, 1, -1, 0)
--         gl.Rotate(rotate, 0, 1, 0)
--         gl.Scale(5, 5, 5)
--         rotate = rotate + 5
--         if rotate % 360 == 0 then
--             id = id + 1
--         end
-- --         featureBridge.glObjectShapeTextures(id, true)
-- --         featureBridge.glObjectShape(id, 0, true)
-- --         featureBridge.glObjectShapeTextures(id, false)
--         unitBridge.glObjectShapeTextures(id, true)
--         unitBridge.glObjectShape(id, 0, true)
--         unitBridge.glObjectShapeTextures(id, false)
--         gl.UseShader(0)
--         gl.PopMatrix()

-- 		gl.PushMatrix()
-- 			local i = 1
-- 			local step = 200
-- 			for texType, shadingTex in pairs(SB.model.textureManager.shadingTextures) do
-- 				gl.Texture(shadingTex)
-- 				gl.TexRect(i * step, 1 * step, (i+1) * step, 2 * step)
-- 				i = i + 1
-- 			end
-- 			i = 1
-- 			local mapTex = SB.model.textureManager.mapFBOTextures[0][0]
-- 			if mapTex then
-- 				gl.Texture(mapTex.texture)
-- 				gl.TexRect(i * step, 1 * step, (i+1) * step, (1+1) * step)
-- 			end
-- 		gl.PopMatrix()
    gl.PopMatrix()
end
