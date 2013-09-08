SCEN_EDIT_VIEW_DIR = SCEN_EDIT_DIR .. "view/"
SCEN_EDIT_VIEW_PANELS_DIR = SCEN_EDIT_VIEW_DIR .. "panels/"
SCEN_EDIT_VIEW_MAIN_WINDOW_DIR = SCEN_EDIT_VIEW_DIR .. "main_window/"

View = LCS.class{}

function View:init()
    SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "view_area_manager_listener.lua")
    SCEN_EDIT.IncludeDir(SCEN_EDIT_VIEW_DIR)
    SCEN_EDIT.IncludeDir(SCEN_EDIT_VIEW_PANELS_DIR)
	SCEN_EDIT.Include(SCEN_EDIT_VIEW_MAIN_WINDOW_DIR .. "abstract_main_window_panel.lua")
	SCEN_EDIT.IncludeDir(SCEN_EDIT_VIEW_MAIN_WINDOW_DIR)	
    SCEN_EDIT.clipboard = Clipboard()
    self.areaViews = {}
    if devMode then
        self.runtimeView = RuntimeView()
    end
    self.selectionManager = SelectionManager()
    self.displayDevelop = true
    self.textureManager = TextureManager()
    --self.mainWindow = MainWindow()
	self.tabbedWindow = TabbedWindow()
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
--    x, y = gl.GetViewSizes()
--    Spring.Echo(#self.areaViews)
    for _, areaView in pairs(self.areaViews) do
        areaView:Draw()
    end
    --[[
    for i, rect in pairs(SCEN_EDIT.model.areaManager:getAllAreas()) do
        if selected ~= i then
            gl.DrawGroundQuad(rect[1], rect[2], rect[3], rect[4])
        end
    end--]]
    --[[
    if selected ~= nil then
        gl.Color(0, 127, 127, 0.2)
        rect = SCEN_EDIT.model.areaManaget:getArea(selected)
        self:DrawRect(rect[1], rect[2], rect[3], rect[4])
    end--]]
    gl.PopMatrix()
end

function View:DrawWorld()
    --self.textureManager:DrawWorld()
end

function View:DrawWorldPreUnit()
    if self.displayDevelop then
        self:drawRects()
    end
    local selType, items = self.selectionManager:GetSelection()
    if selType == "features" then
        for _, featureId in pairs(items) do
            if Spring.ValidFeatureID(featureId) then
                local bx, _, bz = Spring.GetFeaturePosition(featureId)
                local featureDef = FeatureDefs[Spring.GetFeatureDefID(featureId)]
                local minx, maxx = featureDef.minx or -10, featureDef.maxx or 10
                local minz, maxz = featureDef.minz or -10, featureDef.maxz or 10
                local x1, z1 = bx + minx - 5, bz + minz + 5
                local x2, z2 = bx + maxx - 5, bz + maxz + 5
                gl.BeginEnd(GL.LINE_STRIP, function()
                    gl.Color(0, 1, 0, 1)
                    gl.Vertex(x1, Spring.GetGroundHeight(x1, z1), z1)
                    gl.Vertex(x2, Spring.GetGroundHeight(x2, z1), z1)
                    gl.Vertex(x2, Spring.GetGroundHeight(x2, z2), z2)
                    gl.Vertex(x1, Spring.GetGroundHeight(x1, z2), z2)
                    gl.Vertex(x1, Spring.GetGroundHeight(x1, z1), z1)
                end)
            end
        end
    end
end

function View:GameFrame(frameNum)
    self.selectionManager:GameFrame(frameNum)
end
