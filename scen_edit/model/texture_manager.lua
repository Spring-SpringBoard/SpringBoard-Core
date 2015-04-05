TextureManager = Observable:extends{}

function TextureManager:init()
    self:super('init')
    self.TEXTURE_SIZE = 1024

    self.mapFBOTextures = {}
    self.oldMapFBOTextures = {}
    self.stack = {}
    self.tmps = {}

    self.cachedTextures = {}
    self.cachedTexturesMapping = {}
    self.maxCache = 20

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
    Spring.Log("scened", LOG.DEBUG, "Generating textures...")
    local oldMapTexture = self:createMapTexture(false)

    for i = 0, math.floor(Game.mapSizeX / self.TEXTURE_SIZE) do
        self.mapFBOTextures[i] = {}
        for j = 0, math.floor(Game.mapSizeZ / self.TEXTURE_SIZE) do
            local mapTexture = self:createMapTexture()

            Spring.GetMapSquareTexture(i, j, 0, oldMapTexture)
            self:Blit(oldMapTexture, mapTexture)

            self.mapFBOTextures[i][j] = {
                texture = mapTexture,
                dirty = false,
            }
            Spring.SetMapSquareTexture(i, j, mapTexture)
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
        table.insert(self.tmps, self:createMapTexture())
    end
    local tmps = {}
    for i = 1, num do
        table.insert(tmps, self.tmps[i])
    end
    return tmps
end

function TextureManager:resetMapTextures()
    for i, v in pairs(self.mapFBOTextures) do
        for j, textureObj in pairs(v) do
            gl.DeleteTexture(textureObj.texture)
            Spring.SetMapSquareTexture(i, j, "")
        end
    end
    self.mapFBOTextures = {}
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

        local mapTexture = self.mapFBOTextures[i][j].texture

        self:Blit(mapTexture, oldTexture)
        local oldTextureObj = {
            texture = oldTexture,
            dirty = mapTexture.dirty,
        }
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

function TextureManager:Blit(tex1, tex2)
    gl.Texture(tex1)
    gl.RenderToTexture(tex2, function()
        gl.TexRect(-1,-1, 1, 1, 0, 0, 1, 1)
    end)
    gl.Texture(false)
end

function TextureManager:CacheTexture(name)
    SCEN_EDIT.delayGL(function()
        if self.cachedTexturesMapping[name] ~= nil then
            return
        end
        -- maximum number of textures exceeded
        if #self.cachedTextures > self.maxCache then
            local obj = self.cachedTextures[1]
            gl.DeleteTexture(obj.texture)
            self.cachedTexturesMapping[obj.name] = nil
            table.remove(self.cachedTextures, 1)
        end

        local texInfo = gl.TextureInfo(name)
        local texture = gl.CreateTexture(texInfo.xsize, texInfo.ysize, {
            fbo = true,
        })
        self:Blit(name, texture)
        local obj = { texture = texture, name = name }
        self.cachedTexturesMapping[name] = obj
        table.insert(self.cachedTextures, obj)
    end)
end

function TextureManager:GetTexture(name)
    local cachedTex = self.cachedTexturesMapping[name]
    if cachedTex ~= nil then
        return cachedTex.texture
    else
        return name
    end
end