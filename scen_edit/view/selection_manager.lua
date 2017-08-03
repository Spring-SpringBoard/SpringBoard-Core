SelectionManager = Observable:extends{}

local AreaListener = AreaManagerListener:extends{}
function SelectionManager:init()
    self:super("init")
    self.selectedUnits = {}
    -- self.selectedFeatures is a table of: feature ID -> true
    -- this is done to have faster updates
    self.selectedFeatures = {}
    self.selectedAreas = {}
    self.areaListener = AreaListener(self)
    SB.model.areaManager:addListener(self.areaListener)
end

function SelectionManager:GetSelection()
    local features = {}
    for featureID, _ in pairs(self.selectedFeatures) do
        table.insert(features, featureID)
    end
    local selection = {
        units = self.selectedUnits,
        features = features,
        areas = self.selectedAreas,
    }
    return selection
end

function SelectionManager:__ClearSelection()
    self.selectedUnits = {}
    Spring.SelectUnitArray({}, false)

    for _, areaID in pairs(self.selectedAreas) do
        SB.view.areaViews[areaID].selected = false
    end
    self.selectedAreas = {}

    self.selectedFeatures = {}
end

function SelectionManager:ClearSelection()
    self:__ClearSelection()
    self:callListeners("OnSelectionChanged", self:GetSelection())
end

function SelectionManager:Select(selection)
    self:__ClearSelection()

    self.selectedUnits = selection.units or {}
    Spring.SelectUnitArray(self.selectedUnits)

    local features = selection.features or {}
    for _, featureID in pairs(features) do
        self.selectedFeatures[featureID] = true
    end

    self.selectedAreas = selection.areas or {}
    for _, areaID in pairs(self.selectedAreas) do
        SB.view.areaViews[areaID].selected = true
    end

    self:callListeners("OnSelectionChanged", self:GetSelection())
end

function SelectionManager:Update()
    local changed = false
    --update unit selection
    local selUnits = Spring.GetSelectedUnits()
    if not Table.Compare(self.selectedUnits, selUnits) then
        changed = true
    end
    self.selectedUnits = selUnits
    Spring.SelectUnitArray(self.selectedUnits)

    for featureID, _ in pairs(self.selectedFeatures) do
        if not Spring.ValidFeatureID(featureID) then
            self.selectedFeatures[featureID] = nil
            changed = true
        end
    end
    --[[
    if #unitIDs ~= #self.selectedUnits then
        self:__ClearSelection()
        if #unitIDs > 0 then
            self:SelectUnits(unitIDs)
        end
    elseif #unitIDs > 0 then
    end--]]
    if changed then
        self:callListeners("OnSelectionChanged", self:GetSelection())
    end
end

-- we cache minx, maxx, minz, maxz for each feature def
-- this saves us a lot of memory
local __cachedDefs = {}
local function _GetFeatureDefSize(featureDefID)
    if __cachedDefs[featureDefID] == nil then
        local featureDef = FeatureDefs[featureDefID]
        local minx, maxx = featureDef.model.minx or -10, featureDef.model.maxx or 10
        local minz, maxz = featureDef.model.minz or -10, featureDef.model.maxz or 10
        if maxx - minx < 20 then
            minx, maxx = -10, 10
        end
        if maxz - minz < 20 then
            minz, maxz = -10, 10
        end
        __cachedDefs[featureDefID] = {minx, maxx, minz, maxz}
    end
    local c = __cachedDefs[featureDefID]
    return c[1], c[2], c[3], c[4]
end

local function DrawLines(x1, x2, z1, z2, by)
    gl.Vertex(x1, by, z1)
    gl.Vertex(x2, by, z1)
    gl.Vertex(x2, by, z2)
    gl.Vertex(x1, by, z2)
    gl.Vertex(x1, by, z1)
end

function SelectionManager:DrawWorldPreUnit()
    if false then
        return
    end
    gl.Color(0, 1, 0, 1)
    for featureID, _ in pairs(self.selectedFeatures) do
        if Spring.ValidFeatureID(featureID) then
            local bx, by, bz = Spring.GetFeaturePosition(featureID)
            local minx, maxx, minz, maxz = _GetFeatureDefSize(Spring.GetFeatureDefID(featureID))
            local x1, z1 = bx + minx - 5, bz + minz + 5
            local x2, z2 = bx + maxx - 5, bz + maxz + 5
            gl.BeginEnd(GL.LINE_STRIP, DrawLines, x1, x2, z1, z2, by)
        end
    end
end

function AreaListener:init(selectionManager)
    self.selectionManager = selectionManager
end

function AreaListener:onAreaRemoved(areaID)
    if #self.selectionManager.selectedAreas ~= 0 then
        for i, selAreaID in pairs(self.selectionManager.selectedAreas) do
            if selAreaID == areaID then
                table.remove(self.selectionManager.selectedAreas, i)
            end
        end
    end
    self.selectionManager:callListeners("OnSelectionChanged", self.selectionManager:GetSelection())
end
