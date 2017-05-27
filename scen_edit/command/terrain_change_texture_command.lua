TerrainChangeTextureCommand = Command:extends{}
TerrainChangeTextureCommand.className = "TerrainChangeTextureCommand"

function TerrainChangeTextureCommand:init(opts)
    self.className = "TerrainChangeTextureCommand"
    self.opts = opts
    self.mergeCommand = "TerrainChangeTextureMergedCommand"
end

function TerrainChangeTextureCommand:execute()
    local cmd = WidgetTerrainChangeTextureCommand(self.opts)
    SB.commandManager:execute(cmd, true)
end

function TerrainChangeTextureCommand:unexecute()
    -- handled by the merged command
end

TerrainChangeTextureMergedCommand = CompoundCommand:extends{}
TerrainChangeTextureMergedCommand.className = "TerrainChangeTextureMergedCommand"

function TerrainChangeTextureMergedCommand:unexecute()
    -- one unexecute is enough (do it better)
    local cmd = WidgetUndoTerrainChangeTextureCommand()
    SB.commandManager:execute(cmd, true)
end

function TerrainChangeTextureMergedCommand:execute()
    self:super("execute")
    self:onMerge()
end

function TerrainChangeTextureMergedCommand:onMerge()
    local cmd = WidgetTerrainChangeTexturePushStackCommand()
    SB.commandManager:execute(cmd, true)
end