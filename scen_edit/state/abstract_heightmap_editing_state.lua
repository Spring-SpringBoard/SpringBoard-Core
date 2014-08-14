AbstractHeightmapEditingState = AbstractEditingState:extends{}

function AbstractHeightmapEditingState:init(toDecrease)
end

function AbstractHeightmapEditingState:KeyPress(key, mods, isRepeat, label, unicode)
    if self.startedChanging then
        return false
    end
    -- FIXME: cannot use "super" here in the current version of LCS and the new version is broken
    if AbstractEditingState.KeyPress(self, key, mods, isRepeat, label, unicode) then
        return true
    end
    if key == 27 then --KEYSYMS.ESC then
        SCEN_EDIT.stateManager:SetState(DefaultState())
    elseif key == 49 then -- 1
        local newState = TerrainIncreaseState()
        if self.size then
            newState.size = self.size
        end
        SCEN_EDIT.stateManager:SetState(newState)
    elseif key == 50 then -- 2
        local newState = TerrainSmoothState()
        if self.size then
            newState.size = self.size
        end
        SCEN_EDIT.stateManager:SetState(newState)
    elseif key == 51 then -- 3
        local newState = TerrainLevelState()
        if self.size then
            newState.size = self.size
        end
        SCEN_EDIT.stateManager:SetState(newState)
    elseif key == 52 then -- 4
        local newState = TerrainChangeHeightRectState()
        SCEN_EDIT.stateManager:SetState(newState)
    else
        return false
    end
    return true
end
