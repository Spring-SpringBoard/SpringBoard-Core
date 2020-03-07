SB.Include(Path.Join(SB.DIRS.SRC, 'state/abstract_map_editing_state.lua'))

AbstractHeightmapEditingState = AbstractMapEditingState:extends{}

function AbstractHeightmapEditingState:init(editorView)
    AbstractMapEditingState.init(self, editorView)
    self.patternTexture      = self.editorView.fields["patternTexture"].value
    if self.editorView.fields["strength"] then
        self.strength = self.editorView.fields["strength"].value
    else
        self.strength = 1
    end
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

function AbstractHeightmapEditingState:GetApplyParams(x, z, button)
    local strength = self.strength
    if button == 3 and strength ~= nil then
        strength = -strength
    end
    return x, z, strength
end

function AbstractHeightmapEditingState:CanApply()
    local ss = self.size * self.size / 5000.0 / 5000.0
    self.applyDelay = ss * 1.0
    self.applyDelay = math.max(0.01, self.applyDelay)
    return AbstractMapEditingState.CanApply(self)
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
