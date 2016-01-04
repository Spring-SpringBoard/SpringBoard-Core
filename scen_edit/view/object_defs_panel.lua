SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "grid_view.lua")

ObjectDefsPanel = GridView:extends{}

function ObjectDefsPanel:init(tbl)
    local defaults = {
        iconX = 64,
        iconY = 64,
        multiSelect = true,
    }
    tbl = table.merge(tbl, defaults)
    GridView.init(self, tbl)

    self.unitTerrainId = 1
    self.unitTypesId = 1
    self.teamID = 0
    self.search = ""
    self.objectDefIcons = {}

    -- Icon rotation
    self.drawIcons = {}
    self.scheduleDraw = false
    self.rotate = 0
    self.refresh = os.clock()

    self.control:DisableRealign()
    self:PopulateItems()
    self.control:EnableRealign()
    self:Refresh()
end

function ObjectDefsPanel:Refresh()
    self.control:DisableRealign()
    self.control:DeselectAll()

    self:FilterItems()

    self.control:EnableRealign()

    if self.control.parent then
        self.control.parent:RequestRealign()
    else
        self.control:UpdateLayout()
        self.control:Invalidate()
    end
end

function ObjectDefsPanel:FilterItems()
    self.control:ClearChildren()
    for _, item in pairs(self.items) do
        local objectDefID = item.objectDefID
        if self:FilterObject(objectDefID) then
            self.control:AddChild(item)
        end
    end
end

function ObjectDefsPanel:SelectTerrainId(unitTerrainId)
    self.unitTerrainId = unitTerrainId
    self:Refresh()
end

function ObjectDefsPanel:SelectUnitTypesId(unitTypesId)
    self.unitTypesId = unitTypesId
    self:Refresh()
end

function ObjectDefsPanel:SelectTeamID(teamID)
    self.teamID = teamID
--     self:Refresh()
end

function ObjectDefsPanel:SetSearchString(search)
    self.search = search
    self:Refresh()
end

function ObjectDefsPanel:GetObjectDefID(index)
    return self.control.children[index].objectDefID
end

function ObjectDefsPanel:AddDrawIcon(ctrl)
    local objectDefID = ctrl.objectDefID
    local drawIcon = {ctrl = ctrl, radius = self:GetObjectDefRadius(objectDefID)}
    self.drawIcons[objectDefID] = drawIcon
    SCEN_EDIT.delayGL(function()
        local tex = gl.CreateTexture(128, 128, {
            border = false,
            min_filter = GL.LINEAR,
            mag_filter = GL.LINEAR,
            wrap_s = GL.CLAMP_TO_EDGE,
            wrap_t = GL.CLAMP_TO_EDGE,
            fbo = true,
        })
        drawIcon.drawTex = tex
        ctrl.imgCtrl.file = drawIcon.drawTex
    end)
    if not self.scheduleDraw then
        self.scheduleDraw = true
        SCEN_EDIT.delayGL(function()
            self:DrawIcons()
        end)
    end
end

function ObjectDefsPanel:DrawIcons()
    self.rotate = self.rotate + 0.5
    local time = os.clock()
    if (time - self.refresh) >= 0.1 then
        self.refresh = time
    else
        SCEN_EDIT.delayGL(function()
            self:DrawIcons()
        end)
        return
    end
    gl.PushMatrix()
    --gl.Blending(false)
    gl.Blending("disable")
    gl.AlphaTest(false)
    gl.DepthTest(GL.LEQUAL)
    gl.DepthMask(true)
    for objectDefID, drawIcon in pairs(self.drawIcons) do
        if drawIcon.ctrl:IsInView() and drawIcon.drawTex ~= nil then
            self:PeriodicDraw(drawIcon.drawTex, objectDefID, self.bridge, self.rotate, drawIcon.radius)
            drawIcon.ctrl:Invalidate()
        end
    end
    gl.Blending("alpha")
    gl.Texture(false)
    gl.PopMatrix()
    SCEN_EDIT.delayGL(function()
        self:DrawIcons()
    end)
end

function ObjectDefsPanel:PeriodicDraw(tex, objectDefID, bridge, rotation, radius)
    local objectDef = bridge.ObjectDefs[objectDefID]
    local scale = -1.2 / radius--math.sqrt(radius)
    gl.Texture("LuaUI/images/scenedit/background.png")
    gl.RenderToTexture(tex, function()
        gl.TexRect(-1,-1, 1, 1, 0, 0, 1, 1)
--                     gl.TexRect(-1, -1, 1, 1)
        gl.Translate(0, 0.5, 0)
        gl.Rotate(60, -1, 1, -0.5)
        gl.Rotate(rotation, 0, 1, 0)
--         gl.Scale(-0.01, -0.01, -0.01)
        gl.Scale(scale, scale, scale)
        bridge.glObjectShapeTextures(objectDefID, true)
        bridge.glObjectShape(objectDefID, self.teamID, true)
        bridge.glObjectShapeTextures(objectDefID, false)
--                     gl.Texture(0, "-%" .. ctrl.objectDefID .. ":0")
--                     featureBridge.DrawObject(ctrl.objectDefID, 0)
    end)
end

-- UNIT PANEL

UnitDefsPanel = ObjectDefsPanel:extends{}
function UnitDefsPanel:init(tbl)
    self.bridge = unitBridge
    ObjectDefsPanel.init(self, tbl)
end
function UnitDefsPanel:FilterObject(objectDefID)
    local unitDef = UnitDefs[objectDefID]
    local correctType = self.unitTypesId == 2 and unitDef.isBuilding or
            self.unitTypesId == 1 and not unitDef.isBuilding or
            self.unitTypesId == 3

    local correctTerrain = self.unitTerrainId == 1 and (not unitDef.canFly and
    not unitDef.floatOnWater and not unitDef.canSubmerge and unitDef.waterline == 0 and unitDef.minWaterDepth <= 0) or
            self.unitTerrainId == 2 and unitDef.canFly or
        self.unitTerrainId == 3 and (unitDef.canHover or unitDef.floatOnWater or unitDef.waterline > 0 or unitDef.minWaterDepth > 0) or
        self.unitTerrainId == 4
    return correctType and correctTerrain and unitDef.humanName:lower():find(self.search:lower():trim())
end
function UnitDefsPanel:PopulateItems()
    local items = {}
    for id, unitDef in pairs(UnitDefs) do
        table.insert(items, {unitDef.humanName:trim(), "#" .. unitDef.id, unitDef.humanName:trim() .. "\ndefName: " .. tostring(unitDef.name), unitDef.id})
    end
    table.sort(items, function(a, b) return a[1]:lower() < b[1]:lower() end)

    for i = 1, #items do
        local item = items[i]
        local ctrl = self:AddItem(item[1], item[2], item[3])
        ctrl.objectDefID = item[4]
--         Spring.Echo(item[2])
        if item[2] == "" or true then
            self:AddDrawIcon(ctrl)
        end
    end
end
function UnitDefsPanel:GetObjectDefRadius(objectDefID)
    local radius = 10
    local dims = Spring.GetUnitDefDimensions(objectDefID)
    radius = math.max(10, dims.radius)
    return radius
end

-- FEATURE PANEL

FeatureDefsPanel = ObjectDefsPanel:extends{}
function FeatureDefsPanel:init(tbl)
    self.bridge = featureBridge
    ObjectDefsPanel.init(self, tbl)
    self.featureTypeId = 1
end
function FeatureDefsPanel:getUnitDefBuildPic(unitDef)
    unitImagePath = "unitpics/" .. unitDef.buildpicname
    local fileExists = VFS.FileExists(unitImagePath)
    if not fileExists then
        unitImagePath = "buildicons/_1to1_128x128/" .. unitDef.name .. ".png"
    end
    return unitImagePath
end
function FeatureDefsPanel:FilterObject(objectDefID)
    local featureDef = FeatureDefs[objectDefID]
    local correctType = false
    local correctUnit = true
    local unitDef = nil
    if self.featureTypeId == 3 then
        correctType = true
    else
        local isWreck = false
        if featureDef.tooltip and type(featureDef.tooltip) == "string" then
            local defName = featureDef.name:gsub("_heap", ""):gsub("_dead", "")
            unitDef = UnitDefNames[defName]
            if unitDef then
                isWreck = true
            end
        end
        correctType = isWreck == (self.featureTypeId == 2)
        if correctType and isWreck then
            correctUnit = false
            local unitTerrainId = self.unitTerrainId
            local unitTypesId = self.unitTypesId
            local correctUnitType = false
            correctUnitType = unitTypesId == 2 and unitDef.isBuilding or
            unitTypesId == 1 and not unitDef.isBuilding or
            unitTypesId == 3

            correctTerrain = unitTerrainId == 1 and (not unitDef.canFly and
            not unitDef.floatOnWater and not unitDef.canSubmerge and unitDef.waterline == 0 and unitDef.minWaterDepth <= 0) or
            unitTerrainId == 2 and unitDef.canFly or
            unitTerrainId == 3 and (unitDef.canHover or unitDef.floatOnWater or unitDef.waterline > 0 or unitDef.minWaterDepth > 0) or
            unitTerrainId == 4
            if correctUnitType and correctTerrain then
                correctUnit = true
            end
        end
    end
    local name = featureDef.humanName or featureDef.tooltip or featureDef.name
    return correctType and correctUnit and name:lower():find(self.search:lower():trim())
end
function FeatureDefsPanel:PopulateItems()
    local featureTypeId = self.featureTypeId
    --TODO create a default picture for features
    local defaultPicture = nil
    for id, unitDef in pairs(UnitDefs) do
        defaultPicture = "unitpics/" .. unitDef.buildpicname
        break
    end
    local items = {}
    for id, featureDef in pairs(FeatureDefs) do
        if featureDef.tooltip and type(featureDef.tooltip) == "string" then
            local defName = featureDef.name:gsub("_heap", ""):gsub("_dead", "")
            unitDef = UnitDefNames[defName]
            if unitDef then
                isWreck = true
            end
        end
        --unitImagePath = "buildicons/_1to1_128x128/" .. "feature_" .. featureDef.name .. ".png"
        unitImagePath = "unitpics/featureplacer/" .. featureDef.name .. "_unit.png"
        local fileExists = VFS.FileExists(unitImagePath, VFS.MOD)
        if not fileExists then
            if unitDef then
                unitImagePath = self:getUnitDefBuildPic(unitDef)
            end
            if unitImagePath == nil or not VFS.FileExists(unitImagePath, VFS.MOD) then
                unitImagePath = ""
--                 unitImagePath = "%-" .. featureDef.id
            end
        end
        local name = featureDef.humanName or featureDef.tooltip or featureDef.name
        table.insert(items, {name:trim(), unitImagePath, name:trim() .. "\ndefName: " .. tostring(featureDef.name), featureDef.id})
    end
    table.sort(items, function(a, b) return a[1]:lower() < b[1]:lower() end)

    for i = 1, #items do
        local item = items[i]
        local ctrl = self:AddItem(item[1], item[2], item[3])
        ctrl.objectDefID = item[4]
--         if item[2] == "" then
            self:AddDrawIcon(ctrl)
--         end
    end
end
function FeatureDefsPanel:SelectFeatureTypesId(featureTypeId)
    self.featureTypeId = featureTypeId
    self:Refresh()
end
function FeatureDefsPanel:GetObjectDefRadius(objectDefID)
    local objectDef = self.bridge.ObjectDefs[objectDefID]
    local radius = 10
    local dx = objectDef.model.maxx - objectDef.model.minx
    local dy = objectDef.model.maxy - objectDef.model.miny
    local dz = objectDef.model.maxz - objectDef.model.minz
    -- magic
    radius = math.max(dx, dy, dz) / 2 * math.sqrt(2) * 1.2
    return radius
end