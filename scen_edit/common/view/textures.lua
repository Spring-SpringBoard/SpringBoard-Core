TextureManager = LCS.class{}
local SCEN_EDIT_TEXTURE_DIR = LUAUI_DIRNAME .. "images/scenedit/brush_textures/"

function TextureManager:init()
    self.textures = {}
    self._toLoad = {}
    self:LoadAllTextures()
end

function TextureManager:GetRandomTexture()
    for i, v in pairs(self.textures) do
--        Spring.Echo(i)
        if i ~= "grass" then
            return v
        end
    end
end

function TextureManager:LoadAllTextures()
    local files = VFS.DirList(SCEN_EDIT_TEXTURE_DIR)
--    Spring.Echo(#files)
    for _, file in pairs(files) do
        if file:find(".png") then
            table.insert(self._toLoad, file)
        end
    end
--    Spring.Echo(#self._toLoad)
end

local function drawTextureOnSquare()
    gl.TexRect(-1, 1, 1, -1)
end

function TextureManager:LoadTexture(file)
--    Spring.Echo(file)
    if not self.textures[file] then
        local i, j = file:find(".*/")
        textureName = file:sub(j + 1)
        i, j = textureName:find(".png")
        textureName = textureName:sub(1, i - 1)
--        Spring.Echo(textureName)

        local SQUARE_SIZE = 256 --hmm
        local cur = gl.CreateTexture(SQUARE_SIZE, SQUARE_SIZE, {
            wrap_s = GL.CLAMP_TO_EDGE, 
            wrap_t = GL.CLAMP_TO_EDGE,
            fbo = true,
        })
        local texture = gl.Texture(file, textureName)
        gl.RenderToTexture(cur, drawTextureOnSquare)--, x-sx*SQUARE_SIZE,z-sz*SQUARE_SIZE, BLOCK_SIZE, dx, dz, tex.tile)
--        Spring.Echo(cur)


--        Spring.Echo(file, texture)
        self.textures[textureName] = cur
    end
end

function TextureManager:DrawWorld()
    if #self._toLoad > 0 then
--    Spring.Echo("to load ", #self._toLoad)
        for _, textureName in pairs(self._toLoad) do
            self:LoadTexture(textureName)
        end
        self._toLoad = {}
    end
end
