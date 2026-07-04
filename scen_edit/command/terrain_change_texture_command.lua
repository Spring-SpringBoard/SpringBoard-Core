TerrainChangeTextureCommand = NativeCommand:extends{}
TerrainChangeTextureCommand.className = "TerrainChangeTextureCommand"

function TerrainChangeTextureCommand:init(opts)
    self.opts = opts
    self.mergeCommand = "TerrainChangeTextureMergedCommand"
end

TerrainChangeTextureMergedCommand = NativeCommand:extends{}
TerrainChangeTextureMergedCommand.className = "TerrainChangeTextureMergedCommand"
