SCEN_EDIT.Include("scen_edit/state/abstract_map_editing_state.lua")
AbstractHeightmapEditingState = AbstractMapEditingState:extends{}

function AbstractHeightmapEditingState:enterState()
    self.size = math.min(self.maxSize, self.size)
    self.size = math.max(self.minSize, self.size)
end

function AbstractHeightmapEditingState:KeyPress(key, mods, isRepeat, label, unicode)
    -- FIXME: cannot use "super" here in the current version of LCS and the new version is broken
    if AbstractMapEditingState.KeyPress(self, key, mods, isRepeat, label, unicode) then
        return true
    end
    if key == 49 then -- 1
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
    return false
end