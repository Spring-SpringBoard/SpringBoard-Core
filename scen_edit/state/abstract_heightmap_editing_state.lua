SCEN_EDIT.Include("scen_edit/state/abstract_map_editing_state.lua")
AbstractHeightmapEditingState = AbstractMapEditingState:extends{}

function AbstractHeightmapEditingState:init(editorView)
    AbstractMapEditingState.init(self, editorView)
    self.strength            = self.editorView.fields["strength"].value
    self.applyDelay          = 0.03
    self.initialDelay        = 0.3
end

function AbstractHeightmapEditingState:leaveState()
    self.editorView:StoppedEditing()
end

function AbstractHeightmapEditingState:enterState()
    self.editorView:SetNumericField("size", self.size)
    self.editorView:StartedEditing()
end

function AbstractHeightmapEditingState:KeyPress(key, mods, isRepeat, label, unicode)
    -- FIXME: cannot use "super" here in the current version of LCS and the new version is broken
    if AbstractMapEditingState.KeyPress(self, key, mods, isRepeat, label, unicode) then
        return true
    end
    if key == 49 then -- 1
        local newState = TerrainShapeModifyState(self.editorView)
        if self.size then
            newState.size = self.size
        end
        SCEN_EDIT.stateManager:SetState(newState)
    elseif key == 50 then -- 2
        local newState = TerrainSmoothState(self.editorView)
        if self.size then
            newState.size = self.size
        end
        SCEN_EDIT.stateManager:SetState(newState)
    elseif key == 51 then -- 3
        local newState = TerrainLevelState(self.editorView)
        if self.size then
            newState.size = self.size
        end
        SCEN_EDIT.stateManager:SetState(newState)
    elseif key == 52 then -- 4
        local newState = TerrainSetState(self.editorView)
        if self.size then
            newState.size = self.size
        end
        SCEN_EDIT.stateManager:SetState(newState)
--     elseif key == 52 then -- 4
--         local newState = TerrainChangeHeightRectState(self.editorView)
--         SCEN_EDIT.stateManager:SetState(newState)
--     elseif key == 53 then -- 5
--         local newState = TerrainShapeModifyState(self.editorView)
--         SCEN_EDIT.stateManager:SetState(newState)
    else
        return false
    end
    return false
end