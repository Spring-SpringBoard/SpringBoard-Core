TextureManager = Observable:extends{}

function TextureManager:init()
    self:super('init')
    self.TEXTURE_SIZE = 1024

    self.mapFBOTextures = {}
    self.oldMapFBOTextures = {}
    self.stack = {}

    SCEN_EDIT.delayGL(function()
        self:generateMapTextures()
    end)
end

function TextureManager:createMapTexture(notFBO)
    return gl.CreateTexture(self.TEXTURE_SIZE, self.TEXTURE_SIZE, {
        border = false,
        min_filter = GL.LINEAR,
        mag_filter = GL.LINEAR,
        wrap_s = GL.CLAMP_TO_EDGE,
        wrap_t = GL.CLAMP_TO_EDGE,
        fbo = not notFBO,
    })
end

function TextureManager:generateMapTextures()
    local oldMapTexture = self:createMapTexture(true)

    for i = 0, math.floor(Game.mapSizeX / self.TEXTURE_SIZE) do
        self.mapFBOTextures[i] = {}
        for j = 0, math.floor(Game.mapSizeZ / self.TEXTURE_SIZE) do
            local mapTexture = self:createMapTexture()

            Spring.GetMapSquareTexture(i, j, 0, oldMapTexture)
            self:Blit(oldMapTexture, mapTexture)

            self.mapFBOTextures[i][j] = mapTexture
            Spring.SetMapSquareTexture(i, j, mapTexture)
        end
    end
end

function TextureManager:resetMapTexures()
    for i, v in pairs(self.mapFBOTextures) do
        for j, _ in pairs(v) do
            Spring.SetMapSquareTexture(i, j, "")
        end
    end
end

function TextureManager:getMapTexture(x, z)
    local i, j = math.floor(x / self.TEXTURE_SIZE), math.floor(z / self.TEXTURE_SIZE)
    return self.mapFBOTextures[i][j]
end

function TextureManager:getOldMapTexture(i, j)
    if self.oldMapFBOTextures[i] == nil then
        self.oldMapFBOTextures[i] = {}
    end
    if self.oldMapFBOTextures[i][j] == nil then
        -- doesn't exist so we create it
        local oldTexture = self:createMapTexture()

        local mapTexture = self.mapFBOTextures[i][j]

        self:Blit(mapTexture, oldTexture)
        self.oldMapFBOTextures[i][j] = oldTexture
    end

    return self.oldMapFBOTextures[i][j]
end

function TextureManager:getMapTextures(startX, startZ, endX, endZ)
    local textures = {}
    local textureSize = self.TEXTURE_SIZE
    
    
    local x1 = math.max(0, math.floor(startX / textureSize))
    local x2 = math.min(math.floor(Game.mapSizeX / textureSize), 
                        math.floor(endX / textureSize))
    local z1 = math.max(0, math.floor(startZ / textureSize))
    local z2 = math.min(math.floor(Game.mapSizeZ / textureSize), 
                        math.floor(endZ / textureSize))
    for i = x1, x2 do
        for j = z1, z2 do
            table.insert(textures, { 
                self.mapFBOTextures[i][j], self:getOldMapTexture(i, j),
                { startX - i * textureSize, startZ - j * textureSize } 
            })
        end
    end
--     Spring.Echo(startX, startZ, endX, endZ, textureSize)
--     table.echo(textures)
    return textures
end

function TextureManager:Blit(tex1, tex2)
    gl.Texture(tex1)
    gl.RenderToTexture(tex2, function()
        gl.TexRect(-1,-1, 1, 1, 0, 0, 1, 1)
    end)
    gl.Texture(false)
end