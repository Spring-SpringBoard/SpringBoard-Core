SB.Include(Path.Join(SB_VIEW_DIR, "grid_view.lua"))

ObjectDefsPanel = GridView:extends{}

function ObjectDefsPanel:init(tbl)
    local defaults = {
        itemWidth = 76,
        itemHeight = 76,
        multiSelect = true,
    }
    tbl = Table.Merge(tbl, defaults)
    GridView.init(self, tbl)

    self.unitTerrainID = 1
    self.unitTypesID = 1
    self.teamID = 0
    self.search = ""
    self.objectDefIcons = {}

    self.selectedObjectDefIDs = {}

    -- Icon rotation
    self.drawIcons = {}
    self.scheduleDraw = false
    self.rotate = 0
    self.refresh = os.clock()

    self:StartMultiModify()
    self:PopulateItems()
    self:Refresh()
end

function ObjectDefsPanel:Refresh()
    self:StartMultiModify()
    self:FilterItems()
    self:EndMultiModify()
end

function ObjectDefsPanel:FilterItems()
    self.layoutPanel:DeselectAll()
    self.layoutPanel:ClearChildren()
    for _, item in pairs(self.items) do
        local objectDefID = item.objectDefID
        if self:FilterObject(objectDefID) then
            self.layoutPanel:AddChild(item)
        end
    end
end

function ObjectDefsPanel:_UnselectItem(objectDefID)
    for i = 1, #self.selectedObjectDefIDs do
        if self.selectedObjectDefIDs[i] == objectDefID then
            table.remove(self.selectedObjectDefIDs, i)
            break
        end
    end
end

function ObjectDefsPanel:SelectTerrainID(unitTerrainID)
    self.unitTerrainID = unitTerrainID
    self:Refresh()
end

function ObjectDefsPanel:SelectUnitTypesID(unitTypesID)
    self.unitTypesID = unitTypesID
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
    local item = self.layoutPanel.children[index]
    if item then
        return item.objectDefID
    else
        return nil
    end
end

function ObjectDefsPanel:_OnValidateSelectItem(obj, itemIdx, selected)
    local item = self:super("_OnValidateSelectItem", obj, itemIdx, selected)
    if item and item.objectDefID then
        return item
    end
end

function ObjectDefsPanel:_OnSelectItem(obj, itemIdx, selected)
	local item = self:_OnValidateSelectItem(obj, itemIdx, selected)
    if not item then
        return
    end

    local objectDefID = item.objectDefID

    local currentState = SB.stateManager:GetCurrentState()
    -- always block calls if current state is object selection
    if currentState.SelectObjectType then
        -- even if we don't want the current item
        if selected then
            currentState:SelectObjectType(objectDefID)
        end
        return
    end

    if not selected then
        self:_UnselectItem(objectDefID)
    else
        table.insert(self.selectedObjectDefIDs, objectDefID)
    end
    CallListeners(self.OnSelectItem, item, selected)
end

function ObjectDefsPanel:AddSelectListener(listener)
    table.insert(self.selectListeners, listener)
end

function ObjectDefsPanel:GetSelectedObjectDefs()
    return self.selectedObjectDefIDs
end

function ObjectDefsPanel:AddDrawIcon(ctrl)
    local objectDefID = ctrl.objectDefID
    local drawIcon = {ctrl = ctrl, radius = self:GetObjectDefRadius(objectDefID)}
    self.drawIcons[objectDefID] = drawIcon
    SB.Delay("DrawScreen", function()
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
        SB.Delay("DrawScreen", function()
            self:DrawIcons()
        end)
    end
end

function ObjectDefsPanel:DrawIcons()
    self.rotate = self.rotate + 0.5
    local time = os.clock()
    if (time - self.refresh) >= 1.1 then
        self.refresh = time
    else
        SB.Delay("DrawScreen", function()
            self:DrawIcons()
        end)
        return
    end
    gl.PushMatrix()
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
    SB.Delay("DrawScreen", function()
        self:DrawIcons()
    end)
end

function ObjectDefsPanel:PeriodicDraw(tex, objectDefID, bridge, rotation, radius)
    local objectDef = bridge.ObjectDefs[objectDefID]
    local scale = -1 / radius--math.sqrt(radius)
    gl.Texture("LuaUI/images/scenedit/background.png")
    gl.RenderToTexture(tex, function()
        gl.Color(0.2, 0.3, 0.3, 1)
        gl.TexRect(-1,-1, 1, 1, 0, 0, 1, 1)
--                     gl.TexRect(-1, -1, 1, 1)
        gl.Translate(0, 0.5, 0)
        local shaderObj = SB.view.modelShaders:GetDefaultShader()
        gl.UseShader(shaderObj.shader)
        gl.Uniform(shaderObj.teamColorID, Spring.GetTeamColor(self.teamID))
        gl.Rotate(60, -1, 1, -0.5)
        gl.Rotate(rotation, 0, 1, 0)
--         gl.Scale(-0.01, -0.01, -0.01)
        gl.Scale(scale, scale, scale)
        bridge.glObjectShapeTextures(objectDefID, true)
        bridge.glObjectShape(objectDefID, self.teamID, true)
        bridge.glObjectShapeTextures(objectDefID, false)
        gl.UseShader(0)
--                     gl.Texture(0, "-%" .. ctrl.objectDefID .. ":0")
--                     featureBridge.DrawObject(ctrl.objectDefID, 0)
    end)
end

function ObjectDefsPanel:_GetDefHumanName(def)
    local name

    name = def.humanName
    if name then
        name = name:trim()
        if #name > 0 then
            return name
        end
    end

    name = def.tooltip
    if name then
        name = name:trim()
        if #name > 0 then
            return name
        end
    end

    name = def.name
    if name then
        name = name:trim()
        if #name > 0 then
            return name
        end
    end
end

-------------
-- UNIT PANEL
-------------

UnitDefsPanel = ObjectDefsPanel:extends{}
function UnitDefsPanel:init(tbl)
    self.bridge = unitBridge
    ObjectDefsPanel.init(self, tbl)
end
function UnitDefsPanel:FilterObject(objectDefID)
    local unitDef = UnitDefs[objectDefID]
    local correctType = self.unitTypesID == 2 and unitDef.isBuilding or
            self.unitTypesID == 1 and not unitDef.isBuilding or
            self.unitTypesID == 3

    local correctTerrain = self.unitTerrainID == 1 and (not unitDef.canFly and
    not unitDef.floatOnWater and not unitDef.canSubmerge and unitDef.waterline == 0 and unitDef.minWaterDepth <= 0) or
            self.unitTerrainID == 2 and unitDef.canFly or
        self.unitTerrainID == 3 and (unitDef.canHover or unitDef.floatOnWater or unitDef.waterline > 0 or unitDef.minWaterDepth > 0) or
        self.unitTerrainID == 4
    return correctType and correctTerrain and self:_GetDefHumanName(unitDef):lower():find(self.search:lower():trim())
end
function UnitDefsPanel:PopulateItems()
    local items = {}
    for id, unitDef in pairs(UnitDefs) do
        local humanName = self:_GetDefHumanName(unitDef)
        table.insert(items, {
            humanName,
            "#" .. unitDef.id,
            humanName .. "\ndefName: " .. tostring(unitDef.name),
            unitDef.id
        })
    end
    table.sort(items, function(a, b) return a[1]:lower() < b[1]:lower() end)

    for i = 1, #items do
        local item = items[i]
        local ctrl = self:AddItem(item[1], item[2], item[3])
        ctrl.objectDefID = item[4]
        --if item[2] == "" or true then
        if item[2] == "" then
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

----------------
-- FEATURE PANEL
----------------

FeatureDefsPanel = ObjectDefsPanel:extends{}
function FeatureDefsPanel:init(tbl)
    self.bridge = featureBridge
    ObjectDefsPanel.init(self, tbl)
    self.featureTypeID = 1
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
    if self.featureTypeID == 3 then
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
        correctType = isWreck == (self.featureTypeID == 2)
        if correctType and isWreck then
            correctUnit = false
            local unitTerrainID = self.unitTerrainID
            local unitTypesID = self.unitTypesID
            local correctUnitType = false
            correctUnitType = unitTypesID == 2 and unitDef.isBuilding or
            unitTypesID == 1 and not unitDef.isBuilding or
            unitTypesID == 3

            correctTerrain = unitTerrainID == 1 and (not unitDef.canFly and
            not unitDef.floatOnWater and not unitDef.canSubmerge and unitDef.waterline == 0 and unitDef.minWaterDepth <= 0) or
            unitTerrainID == 2 and unitDef.canFly or
            unitTerrainID == 3 and (unitDef.canHover or unitDef.floatOnWater or unitDef.waterline > 0 or unitDef.minWaterDepth > 0) or
            unitTerrainID == 4
            if correctUnitType and correctTerrain then
                correctUnit = true
            end
        end
    end
    local humanName = self:_GetDefHumanName(featureDef)
    return correctType and correctUnit and humanName:lower():find(self.search:lower():trim())
end
function FeatureDefsPanel:PopulateItems()
    local featureTypeID = self.featureTypeID
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
        local humanName = self:_GetDefHumanName(featureDef)
        table.insert(items, {humanName, unitImagePath, humanName .. "\ndefName: " .. tostring(featureDef.name), featureDef.id})
    end
    table.sort(items, function(a, b) return a[1]:lower() < b[1]:lower() end)

    for i = 1, #items do
        local item = items[i]
        local ctrl = self:AddItem(item[1], item[2], item[3])
        ctrl.objectDefID = item[4]
        if item[2] == "" then
            self:AddDrawIcon(ctrl)
        end
    end
end
function FeatureDefsPanel:SelectFeatureTypesID(featureTypeID)
    self.featureTypeID = featureTypeID
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
