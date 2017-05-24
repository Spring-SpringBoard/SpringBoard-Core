ExportFeaturePlacerCommand = AbstractCommand:extends{}
ExportFeaturePlacerCommand.className = "ExportFeaturePlacerCommand"

function ExportFeaturePlacerCommand:init(path)
    self.className = "ExportFeaturePlacerCommand"	
    self.path = path
    --add extension if it doesn't exist
    if string.sub(self.path,-string.len(SB_FEATURE_PLACER_FILE_EXT)) ~= SB_FEATURE_PLACER_FILE_EXT then
        self.path = self.path .. SB_FEATURE_PLACER_FILE_EXT
    end
end

function ExportFeaturePlacerCommand:execute()
    -- convert to feature placer format
    local features = SB.model.featureManager:serialize()
    local fpFeatures = {}
    for _, feature in pairs(features) do
        local rot = tostring(-feature.angle * 32768 / math.pi)
        local fpFeature = {
            name = feature.featureDefName,
            x = feature.x,
            z = feature.z,
            rot = rot,
        }
        table.insert(fpFeatures, fpFeature)
    end

    local units = SB.model.unitManager:serialize()
    local fpBuildings = {}
    local fpUnits = {}
    local gaiaID = Spring.GetGaiaTeamID()
    
    -- feature placer saves building rotations in a simplified format
    local rotlookup = {}
    rotlookup[0]        = "south" 
    rotlookup[16384]    = "east"
    rotlookup[32767]    = "north"
    rotlookup[-16384]   = "west"
    for _, unit in pairs(units) do
        local unitDef = UnitDefNames[unit.unitDefName]
        -- NOTICE: this will only export GAIA units and is used to best mimic FP functionality
        if unit.teamId == gaiaID then
            local rot = tostring(-unit.angle * 32768 / math.pi)
            local fpObj = {
                name = unit.unitDefName,
                x = unit.x,
                z = unit.z,
                rot = rot,
            }

            -- this is how FP diffentiates units from buildings
            local isUnit = unitDef.canMove
            if isUnit then
                table.insert(fpUnits, fpObj)
            else
                local buildingRot = rotlookup[rot] 
                if buildingRot == nil then
                    Log.Warning("Custom building rotations cannot be saved accurately in the feature placer format.")
                    -- FIXME: should get the closest rotation, but lazy atm
                    buildingRot = rotlookup[0]
                end
                fpObj.rot = buildingRot
                table.insert(fpBuildings, fpObj)
            end
        end
    end

    local featureCfg = { 
        objectlist = fpFeatures,
        buildinglist = fpBuildings,
        unitlist = fpUnits,
    }

    local file = assert(io.open(self.path, "w"))
    file:write(table.show(featureCfg))
    file:close()
end
