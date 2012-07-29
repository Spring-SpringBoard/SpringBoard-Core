local SCEN_EDIT_COMMON_DIR = "scen_edit/common/"
local SCEN_EDIT_VIEW_DIR = SCEN_EDIT_COMMON_DIR .. "view/"

View = LCS.class{}

function View:init()
    VFS.Include(SCEN_EDIT_VIEW_DIR .. "view_area_manager_listener.lua")
    local files = VFS.DirList(SCEN_EDIT_VIEW_DIR)
    for i = 1, #files do
        local file = files[i]
        if not file:find("view_area_manager_listener.lua") then
            VFS.Include(file)
        end
    end
    self.areaViews = {}
    self.runtimeView = RuntimeView()
    self.displayDevelop = true
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
    gl.Color(0, 1, 0, 0.2)
--    x, y = gl.GetViewSizes()
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

function View:draw()
    if self.displayDevelop then
        self:drawRects()
    end
end
