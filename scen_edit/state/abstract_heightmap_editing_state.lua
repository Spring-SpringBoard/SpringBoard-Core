SB.Include("scen_edit/state/abstract_map_editing_state.lua")
AbstractHeightmapEditingState = AbstractMapEditingState:extends{}

function AbstractHeightmapEditingState:init(editorView)
    AbstractMapEditingState.init(self, editorView)
    self.patternTexture      = self.editorView.fields["patternTexture"].value
    self.strength            = self.editorView.fields["strength"].value
    self.height              = self.editorView.fields["height"].value
    self.applyDelay          = 0.03
    self.initialDelay        = 0.3
end

function AbstractHeightmapEditingState:leaveState()
    self:super("leaveState")
end

function AbstractHeightmapEditingState:enterState()
    self:super("enterState")
    self.editorView:Set("size", self.size)
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
        SB.stateManager:SetState(newState)
    elseif key == 50 then -- 2
        local newState = TerrainSetState(self.editorView)
        if self.size then
            newState.size = self.size
        end
        SB.stateManager:SetState(newState)
    elseif key == 51 then -- 3
        local newState = TerrainSmoothState(self.editorView)
        if self.size then
            newState.size = self.size
        end
        SB.stateManager:SetState(newState)
--     elseif key == 52 then -- 4
--         local newState = TerrainChangeHeightRectState(self.editorView)
--         SB.stateManager:SetState(newState)
--     elseif key == 53 then -- 5
--         local newState = TerrainShapeModifyState(self.editorView)
--         SB.stateManager:SetState(newState)
    else
        return false
    end
    return false
end

function AbstractHeightmapEditingState:GetApplyParams(x, z, button)
	local strength = self.strength
	if button == 3 and strength ~= nil then
		strength = -strength
	end
	return x, z, strength
end

function AbstractHeightmapEditingState:Apply(x, z, strength)
    if not self.patternTexture then
        return false
    end
    if SB.model.terrainManager:getShape(self.patternTexture) == nil then
        SB.model.terrainManager:generateShape(self.patternTexture)
    end

    local cmd = self:GetCommand(x, z, strength)
    SB.commandManager:execute(cmd)
    return true
end
