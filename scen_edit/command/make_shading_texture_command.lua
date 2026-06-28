--- MakeShadingTextureCommand
-- Creates/enables an editor shading texture (specular, splat_distr, ...) on the
-- Rust-owned texture manager. Rust-owned (nativeCommandsOnly); reached from the
-- terrain-settings "new engine texture" dialog.
MakeShadingTextureCommand = Command:extends{}
MakeShadingTextureCommand.className = "MakeShadingTextureCommand"

function MakeShadingTextureCommand:init(opts)
    -- name = internal shading name (e.g. "specular"), per TextureManager.shadingTextureDefs.
    self.name    = opts.name
    self.sizeX   = opts.sizeX
    self.sizeY   = opts.sizeY
    self.color   = opts.color   -- {r,g,b,a}, or nil when seeding from a texture
    self.texture = opts.texture -- source path, or nil when filling a color
end

function MakeShadingTextureCommand:execute()
end
