SCEN_EDIT.Include("scen_edit/state/abstract_map_editing_state.lua")
AbstractHeightmapEditingState = AbstractMapEditingState:extends{}

function AbstractHeightmapEditingState:init(heightmapEditorView)
    self.heightmapEditorView = heightmapEditorView
    self.size                = self.heightmapEditorView.fields["size"].value
    self.strength            = self.heightmapEditorView.fields["strength"].value
    self.minSize             = self.heightmapEditorView.fields["size"].minValue
    self.maxSize             = self.heightmapEditorView.fields["size"].maxValue
end

function AbstractHeightmapEditingState:leaveState()
    self.heightmapEditorView:StoppedEditing()
end

function AbstractHeightmapEditingState:MouseWheel(up, value)
    if self:super("MouseWheel", up, value) then
        self.heightmapEditorView:SetNumericField("size", self.size)
        return true
    end
end

function AbstractHeightmapEditingState:enterState()
    self.size = math.min(self.maxSize, self.size)
    self.size = math.max(self.minSize, self.size)
    self.heightmapEditorView:SetNumericField("size", self.size)
    self.heightmapEditorView:StartedEditing()
end

function AbstractHeightmapEditingState:KeyPress(key, mods, isRepeat, label, unicode)
    -- FIXME: cannot use "super" here in the current version of LCS and the new version is broken
    if AbstractMapEditingState.KeyPress(self, key, mods, isRepeat, label, unicode) then
        return true
    end
    if key == 49 then -- 1
        local newState = TerrainIncreaseState(self.heightmapEditorView)
        if self.size then
            newState.size = self.size
        end
        SCEN_EDIT.stateManager:SetState(newState)
    elseif key == 50 then -- 2
        local newState = TerrainSmoothState(self.heightmapEditorView)
        if self.size then
            newState.size = self.size
        end
        SCEN_EDIT.stateManager:SetState(newState)
    elseif key == 51 then -- 3
        local newState = TerrainLevelState(self.heightmapEditorView)
        if self.size then
            newState.size = self.size
        end
        SCEN_EDIT.stateManager:SetState(newState)
    elseif key == 52 then -- 4
        local newState = TerrainChangeHeightRectState(self.heightmapEditorView)
        SCEN_EDIT.stateManager:SetState(newState)
    elseif key == 53 then -- 5
        local newState = TerrainShapeModifyState(self.heightmapEditorView)
        SCEN_EDIT.stateManager:SetState(newState)
    else
        return false
    end
    return false
end