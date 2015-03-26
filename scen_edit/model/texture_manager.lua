TextureManager = Observable:extends{}

function TextureManager:init()
    self:super('init')
    self.TEXTURE_SIZE = 1024

    self.mapFBOTextures = {}
    
    SCEN_EDIT.delayGL(function()
        self:generateMapTextures()
    end)
end

function TextureManager:generateMapTextures()
    local oldMapTexture = gl.CreateTexture(self.TEXTURE_SIZE,self.TEXTURE_SIZE, {
        border = false,
--         min_filter = GL.NEAREST,
--         mag_filter = GL.NEAREST,
        min_filter = GL.LINEAR,
        mag_filter = GL.LINEAR,
        wrap_s = GL.CLAMP_TO_EDGE,
        wrap_t = GL.CLAMP_TO_EDGE,
        fbo = false,
    })

    for i = 0, math.floor(Game.mapSizeX / self.TEXTURE_SIZE) do
        self.mapFBOTextures[i] = {}
        for j = 0, math.floor(Game.mapSizeZ / self.TEXTURE_SIZE) do
            local mapTexture = gl.CreateTexture(
            self.TEXTURE_SIZE, self.TEXTURE_SIZE, {
                border = false,
--                 min_filter = GL.NEAREST,
--                 mag_filter = GL.NEAREST,
                min_filter = GL.LINEAR,
                mag_filter = GL.LINEAR,
                wrap_s = GL.CLAMP_TO_EDGE,
                wrap_t = GL.CLAMP_TO_EDGE,
                fbo = true,
            })

            Spring.GetMapSquareTexture(i, j, 0, oldMapTexture)
            gl.RenderToTexture(mapTexture,
            function()
                gl.Texture(oldMapTexture)
                gl.TexRect(-1,-1, 1, 1,0, 0, 1, 1)
            end)

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

function TextureManager:getMapTextures(startX, startZ, endX, endZ)
    local textures = {}
    for i = math.max(0, math.floor(startX / self.TEXTURE_SIZE)), math.min(math.floor(Game.mapSizeX / self.TEXTURE_SIZE), math.floor(endX / self.TEXTURE_SIZE)) do
        for j = math.max(0, math.floor(startZ / self.TEXTURE_SIZE)), math.min(math.floor(Game.mapSizeZ / self.TEXTURE_SIZE), math.floor(endZ / self.TEXTURE_SIZE)) do
            textures[#textures + 1] = { self.mapFBOTextures[i][j], { startX - i * self.TEXTURE_SIZE, startZ - j * self.TEXTURE_SIZE } }
        end
    end
    return textures
end
