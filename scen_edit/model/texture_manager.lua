TextureManager = Observable:extends{}

function TextureManager:init()
    self:super('init')
    self.TEXTURE_SIZE = 1024

    self.mapFBOTextures = {}
    self.oldMapFBOTextures = {}
    self.stack = {}
    self.tmps = {}

    SCEN_EDIT.delayGL(function()
        self:generateMapTextures()
    end)
end

function TextureManager:createMapObj()
    local texture = gl.CreateTexture(self.TEXTURE_SIZE, self.TEXTURE_SIZE, {
        border = false,
        min_filter = GL.LINEAR,
        mag_filter = GL.LINEAR,
        wrap_s = GL.CLAMP_TO_EDGE,
        wrap_t = GL.CLAMP_TO_EDGE,
        format = 0x83F1,
    })
    return { texture = texture, fbo = gl.CreateFBO({color0 = texture}) }
end

function TextureManager:generateMapTextures()
    for i = 0, math.floor(Game.mapSizeX / self.TEXTURE_SIZE) do
        self.mapFBOTextures[i] = {}
        for j = 0, math.floor(Game.mapSizeZ / self.TEXTURE_SIZE) do
            local obj = self:createMapObj()
            Spring.GetMapSquareTexture(i, j, 0, obj.texture)

            local new = self:createMapObj()
            gl.BlitFBO(obj.fbo, 0, 0, self.TEXTURE_SIZE, self.TEXTURE_SIZE,
                       new.fbo, 0, 0, self.TEXTURE_SIZE, self.TEXTURE_SIZE)

            new.dirty = false
            self.mapFBOTextures[i][j] = new

            Spring.SetMapSquareTexture(i, j, new.texture)
        end
    end
--     self.specularTexture = self:createMapTexture()
--     local x = Spring.GetMapSpecularTexture(self.specularTexture)
--     Spring.Echo("Map specular texture:", x, self.specularTexture)
end

-- function TextureManager:GetMapSpecularTexture()
--     return self.specularTexture
-- end

function TextureManager:GetTMPs(num)
    for i = #self.tmps + 1, num do
        local texture = self:createMapObj()
        table.insert(self.tmps, texture)
    end
    local tmps = {}
    for i = 1, num do
        table.insert(tmps, self.tmps[i])
    end
    return tmps
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
        local oldTextureObj = self:createMapObj()
        local mapTextureObj = self.mapFBOTextures[i][j]

        self:Blit(mapTextureObj, oldTextureObj)

        oldTextureObj.dirty = mapTextureObj.dirty
        self.oldMapFBOTextures[i][j] = oldTextureObj
    end

    return self.oldMapFBOTextures[i][j]
end

function TextureManager:getMapTextures(startX, startZ, endX, endZ)
    local textures = {}
    local textureSize = self.TEXTURE_SIZE

    local i1 = math.max(0, math.floor(startX / textureSize))
    local i2 = math.min(math.floor(Game.mapSizeX / textureSize), 
                        math.floor(endX / textureSize))
    local j1 = math.max(0, math.floor(startZ / textureSize))
    local j2 = math.min(math.floor(Game.mapSizeZ / textureSize), 
                        math.floor(endZ / textureSize))

    for i = i1, i2 do
        for j = j1, j2 do
            table.insert(textures, { 
                self.mapFBOTextures[i][j], self:getOldMapTexture(i, j),
                { startX - i * textureSize, startZ - j * textureSize } 
            })
        end
    end

    return textures
end

function TextureManager:Blit(obj1, obj2)
    gl.BlitFBO(obj1.fbo, 0, 0, self.TEXTURE_SIZE, self.TEXTURE_SIZE,
               obj2.fbo, 0, 0, self.TEXTURE_SIZE, self.TEXTURE_SIZE)
--     gl.Texture(tex1)
--     gl.RenderToTexture(tex2, function()
--         gl.TexRect(-1,-1, 1, 1, 0, 0, 1, 1)
--     end)
--     gl.Texture(false)
end