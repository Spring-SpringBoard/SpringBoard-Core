ImportFeaturePlacerCommand = AbstractCommand:extends{}
ImportFeaturePlacerCommand.className = "ImportFeaturePlacerCommand"

function ImportFeaturePlacerCommand:init(modelData)
    self.className = "ImportFeaturePlacerCommand"
    self.modelData = modelData
end

function ImportFeaturePlacerCommand:execute()
    -- convert feature placer format to our own
    local fpData = loadstring(self.modelData)()
    local mission = {}

    local gaiaID = Spring.GetGaiaTeamID()

    local features = {}
    if fpData.objectlist then
        for _, fpFeature in pairs(fpData.objectlist) do
            local angle = -tonumber(fpFeature.rot) * math.pi / 32768
            local feature = {
                featureDefName = fpFeature.name,
                x = fpFeature.x,
                y = Spring.GetGroundHeight(fpFeature.x, fpFeature.z) + 5,
                z = fpFeature.z,
                angle = angle,
            }
            table.insert(features, feature)
        end
    end

    -- we combine existing non-gaia units with fp units and buildings
    local units = {}

    local oldUnits = SCEN_EDIT.model.unitManager:serialize()
    for _, unit in pairs(oldUnits) do
        if unit.teamId == gaiaID then
            table.insert(oldUnits, units)
        end
    end
    if fpData.unitlist then
        for _, fpUnit in pairs(fpData.unitlist) do
            local angle = -tonumber(fpUnit.rot) * math.pi / 32768
            local unit = {
                unitDefName = fpUnit.name,
                x = fpUnit.x,
                y = Spring.GetGroundHeight(fpUnit.x, fpUnit.z) + 5,
                z = fpUnit.z,
                angle = angle,
                neutral = true,
                alwaysVisible = true,
                blocking = true,
                losState = {true, true, true, true},
            }
            table.insert(units, unit)
        end
    end

    if fpData.buildinglist then
        -- building rotations are saved in a simplified format
        local reverseRotlookup = {}
        reverseRotlookup["south"] = 0
        reverseRotlookup["east"]  = 16384
        reverseRotlookup["north"] = 32767
        reverseRotlookup["west"]  = -16384
        for _, fpBuilding in pairs(fpData.buildinglist) do
            local rot = reverseRotlookup[fpBuilding.rot]
            local angle = -tonumber(rot) * math.pi / 32768
            local unit = {
                unitDefName = fpBuilding.name,
                x = fpBuilding.x,
                y = Spring.GetGroundHeight(fpBuilding.x, fpBuilding.z) + 5,
                z = fpBuilding.z,
                angle = angle,
                neutral = true,
                alwaysVisible = true,
                blocking = true,
                losState = {true, true, true, true},
            }
            table.insert(units, unit)
        end
    end

    local mission = {
        units = units,
        features = features,
    }

    --SCEN_EDIT.model.unitManager:clear()
    SCEN_EDIT.model.featureManager:clear()

    SCEN_EDIT.model.unitManager:load(mission.units)
    SCEN_EDIT.model.featureManager:load(mission.features)
end
