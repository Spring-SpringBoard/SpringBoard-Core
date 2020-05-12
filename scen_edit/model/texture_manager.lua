SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'model/rendering'))

TextureManager = Observable:extends{}

-- local smftTexAniso = Spring.GetConfigInt("SMFTexAniso")
local ssmfTexAniso

function TextureManager:init()
    self:super('init')
    self.TEXTURE_SIZE = 1024

    ssmfTexAniso = Spring.GetConfigInt("SSMFTexAniso")

    self.mapFBOTextures = {}
    self.activeDrawing = ActiveDrawing()
    self.stack = TextureUndoStack()

    self.cachedTextures = {}
    self.cachedTexturesMapping = {}
    self.maxCache = 20

    self.shadingTextures = {}
    self.shadingTextureDefs = {
        specular = {
            engineName = "$ssmf_specular",
            mapinfo_name = "specularTex",
        },
        emission = {
            engineName = "$ssmf_emission",
            mapinfo_name = "lightEmissionTex",
            alpha = true,
        },
        refl = {
            engineName = "$ssmf_sky_refl",
            mapinfo_name = "skyReflectModTex",
        },
        -- parallax = {
        --     engineName = "$ssmf_parallax",
        -- },
        splat_distr = {
            engineName = "$ssmf_splat_distr",
            mapinfo_name = "splatDistrTex",
            alpha = true,
        },
        -- splat_detail = {
        --     engineName = "$ssmf_splat_detail",
        -- },
        splat_normals0 = {
            engineName = "$ssmf_splat_normals:0",
            _setParams = {"$ssmf_splat_normals", 0},
            mapinfo_name = "splatDetailNormalTex0",
            alpha = true,
        },
        splat_normals1 = {
            engineName = "$ssmf_splat_normals:1",
            _setParams = {"$ssmf_splat_normals", 1},
            mapinfo_name = "splatDetailNormalTex1",
            alpha = true,
        },
        splat_normals2 = {
            engineName = "$ssmf_splat_normals:2",
            _setParams = {"$ssmf_splat_normals", 2},
            mapinfo_name = "splatDetailNormalTex2",
            alpha = true,
        },
        splat_normals3 = {
            engineName = "$ssmf_splat_normals:3",
            _setParams = {"$ssmf_splat_normals", 3},
            mapinfo_name = "splatDetailNormalTex3",
            alpha = true,
        },

        detail = {
            engineName = "$detail",
            mapinfo_name = "detailTex",
            alpha = false,
        }
    }
    self.materialTextures = {
        diffuse = {
            suffix = "_diffuse",
            enabled = true,
        },
        specular = {
            suffix = "_specular",
            enabled = true,
        },
        normal = {
            suffix = "_normal",
            enabled = true,
        },
        emission = {
            suffix = "_emission",
            enabled = true,
        },
        refl = {
            suffix = "_refl",
            enabled = true,
        },

        -- NB: DISABLED below
        -- Would like to use it for parallax, but how?
        -- Maybe we can just forget about parallax without splats
        -- height = {
        --     suffix = "_height",
        --     enabled = false,
        -- },
        -- glow = {
        --     suffix = "_glow",
        --     enabled = false,
        -- }
    }
    self.shadingTextureNames = {}
    for name, texDef in pairs(self.shadingTextureDefs) do
        texDef.name = name
        table.insert(self.shadingTextureNames, name)
    end

    SB.delayGL(function()
        self:GenerateMapTextures()
    end)
end

-- Texture def fields:
-- name: string
-- engineName: string
-- enabled: bool
function TextureManager:GetShadingTextureDefs()
    return self.shadingTextureDefs
end

function TextureManager:createMapTexture(notFBO, notMinMap)
    local min_filter
    if notMinMap then
        min_filter = GL.LINEAR
    else
        min_filter = GL.LINEAR --GL.LINEAR_MIPMAP_NEAREST
    end
    return gl.CreateTexture(self.TEXTURE_SIZE, self.TEXTURE_SIZE, {
        border = false,
        min_filter = min_filter,
        mag_filter = GL.LINEAR,
        wrap_s = GL.CLAMP_TO_EDGE,
        wrap_t = GL.CLAMP_TO_EDGE,
        fbo = not notFBO,
    })
end

function TextureManager:SetupShader()
    -- local vertProg = VFS.LoadFile("shaders/SMFVertProg.glsl")
    -- local fragProg = VFS.LoadFile("shaders/SMFFragProg.glsl")
    TextureManager.mapShader = Shaders.Compile({
        vertex = [[
void main(void)
{
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;

}
]],
        fragment = [[
uniform ivec2 texSquare;

varying vec2 diffuseTexCoords;
uniform sampler2D diffuseTex;
void main(void)
{
    vec2 diffTexCoords = diffuseTexCoords;
    vec4 diffuseCol = texture2D(diffuseTex, diffTexCoords);
    gl_FragColor = diffuseCol;
}
]]
    }, "TextureManager:SetupShader")
    Spring.SetMapShader(TextureManager.mapShader, TextureManager.mapShader)
end

function TextureManager:GenerateMapTextures()
    Log.Debug("Generating textures...")
    local oldMapTexture = self:createMapTexture(true, true)

    for i = 0, math.floor(Game.mapSizeX / self.TEXTURE_SIZE) do
        self.mapFBOTextures[i] = {}
        for j = 0, math.floor(Game.mapSizeZ / self.TEXTURE_SIZE) do
            local mapTexture = self:createMapTexture()

            Spring.GetMapSquareTexture(i, j, 0, oldMapTexture)
            gfx.Blit(oldMapTexture, mapTexture)
            --gl.GenerateMipmap(mapTexture)

            self.mapFBOTextures[i][j] = {
                texture = mapTexture,
                dirty = false,
            }
            Spring.SetMapSquareTexture(i, j, mapTexture)
        end
    end

    self.shadingTextures = {}
    for name, texDef in pairs(self.shadingTextureDefs) do
        self:ResetShadingTexture(name)
        self:AssignShadingTexture(name, texDef.engineName)
        Log.Notice("texture [" .. tostring(name) .. "] enabled: "
                   .. tostring(texDef.enabled))
    end

--      self:SetupShader()
end

function TextureManager:ResetShadingTexture(name)
    local texDef = self.shadingTextureDefs[name]
    texDef.enabled = false
    local engineName = texDef.engineName

    local success
    if texDef._setParams then
        success = Spring.SetMapShadingTexture(texDef._setParams[1], "", texDef._setParams[2])
    else
        success = Spring.SetMapShadingTexture(engineName, "")
    end

    if not success then
        Log.Error("Failed to reset texture: " .. tostring(name) .. ", engine name: " .. tostring(engineName))
    end
end

function TextureManager:AssignShadingTexture(name, source)
    local texInfo = gl.TextureInfo(source)
    if texInfo == nil then
        return
    end
    local sizeX, sizeY = texInfo.xsize, texInfo.ysize
    if sizeX <= 0 or sizeY <= 0 then
        return
    end

    local texDef = self.shadingTextureDefs[name]
    local tex = self:MakeShadingTexture(name, sizeX, sizeY)
    gfx.Blit(source, tex)
    if name:find("splat_normals") or name:find("detail") then
        gl.GenerateMipmap(tex)
    end
    self:SetShadingTexture(name, tex)
end

function TextureManager:SetShadingTexture(name, tex)
    local texDef = self.shadingTextureDefs[name]
    self.shadingTextures[name] = {
        texture = tex,
        dirty = true,
    }
    local success
    if texDef._setParams then
        success = Spring.SetMapShadingTexture(texDef._setParams[1], tex, texDef._setParams[2])
    else
        success = Spring.SetMapShadingTexture(texDef.engineName, tex)
    end
    if not success then
        Log.Error("Failed to set new texture: " .. tostring(name) ..
                  ", engine name: " .. tostring(texDef.engineName))
        return
    end
    texDef.enabled = true
end

function TextureManager:MakeShadingTexture(name, sizeX, sizeY)
    if name:find("splat_normals") then
        return gl.CreateTexture(sizeX, sizeY, {
            border = false,
            min_filter = GL.LINEAR_MIPMAP_NEAREST,
            mag_filter = GL.LINEAR,
            wrap_s = GL.REPEAT,
            wrap_t = GL.REPEAT,
            aniso = ssmfTexAniso,
            fbo = true,
        })
    elseif name:find("detail") then
        -- TODO: merge with splat_normals?
        return gl.CreateTexture(sizeX, sizeY, {
            border = false,
            min_filter = GL.LINEAR_MIPMAP_NEAREST,
            mag_filter = GL.LINEAR,
            wrap_s = GL.REPEAT,
            wrap_t = GL.REPEAT,
            aniso = ssmfTexAniso,
            fbo = true,
        })
    else
        return gl.CreateTexture(sizeX, sizeY, {
            border = false,
            min_filter = GL.LINEAR,
            mag_filter = GL.LINEAR,
            wrap_s = GL.CLAMP_TO_EDGE,
            wrap_t = GL.CLAMP_TO_EDGE,
            fbo = true,
        })
    end
end

function TextureManager:MakeAndEnableMapShadingTexture(opts)
    local name = opts.name
    local sizeX = opts.sizeX
    local sizeY = opts.sizeY
    local color = opts.color
    local texture = opts.texture

    -- gl.DeleteTexture(self.shadingTextureDefs[name].engineName)
    local tex = self:MakeShadingTexture(name, sizeX, sizeY)

    gl.Blending("enable")
    if color then
        gl.Color(unpack(color))
    end
    if texture then
        gl.Texture(texture)
    end
    gl.RenderToTexture(tex, function()
        gl.TexRect(-1,-1, 1, 1, 0, 0, 1, 1)
    end)
    if texture then
        gl.Texture(texture, false)
    end

    self:SetShadingTexture(name, tex)
    return tex
end

local grayscaleShader
local function _GetDNTSShader()
    if not grayscaleShader then
        grayscaleShader = Shaders.Compile({
            fragment = [[
    uniform sampler2D normalTex;
    uniform sampler2D diffuseTex;
    void main(void)
    {
        vec4 normalColor = texture2D(normalTex, gl_TexCoord[0].st);
        vec4 diffuseColor = texture2D(diffuseTex, gl_TexCoord[0].st);

        float grayscale =  dot(diffuseColor.rgb, float3(0.3, 0.59, 0.11));
        gl_FragColor = vec4(normalColor.rgb, grayscale);
    }
    ]]
        }, "TextureManager:_GetDNTSShader")
        return grayscaleShader
    end
    return grayscaleShader
end

function TextureManager:SetDNTS(dntsIndex, material)
    local texObj = self.shadingTextures["splat_normals" .. tostring(dntsIndex)]
    local texture = texObj.texture
    local shader = _GetDNTSShader()

    gl.UseShader(shader)
    gl.Blending("disable")
    gl.Texture(0, material.normal)
    gl.Texture(1, material.diffuse)
    gl.RenderToTexture(texture, function()
        gl.TexRect(-1,-1, 1, 1, 0, 0, 1, 1)
    end)
    gl.Texture(0, false)
    gl.Texture(1, false)
    gl.UseShader(0)

    gl.GenerateMipmap(texture)
    texObj.dirty = true
end

function TextureManager:ResetMapTextures()
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

-- automatically pushes textures on the undo stack
function TextureManager:getMapTextures(startX, startZ, endX, endZ)
    local textures = {}
    local textureSize = self.TEXTURE_SIZE

    local i1 = math.max(0, math.floor(startX))
    local i2 = math.min(math.floor(Game.mapSizeX / textureSize),
                        math.floor(endX))
    local j1 = math.max(0, math.floor(startZ))
    local j2 = math.min(math.floor(Game.mapSizeZ / textureSize),
                        math.floor(endZ))

    for i = i1, i2 do
        for j = j1, j2 do
            self:__SetActiveMapTexture(i, j)
            table.insert(textures, {
                renderTexture = self.mapFBOTextures[i][j],
                x = startX - i,
                y = startZ - j
            })
        end
    end

    return textures
end

function TextureManager:Blit(tex1, tex2)
    gfx.Blit(tex1, tex2)
end

function TextureManager:CacheTexture(name)
    SB.delayGL(function()
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
        gfx.Blit(name, texture)
        local obj = { texture = texture, name = name }
        self.cachedTexturesMapping[name] = obj
        table.insert(self.cachedTextures, obj)
    end)
end

function TextureManager:UnCacheTexture(name)
    local objDel = self.cachedTexturesMapping[name]
    if objDel == nil then
        Log.Debug("No texture to uncache: " .. tostring(name))
        return
    end

    for i, obj in pairs(self.cachedTextures) do
        if obj == objDel then
            Log.Debug("Deleted texture[" .. tostring(i) ..
                       "]: " .. tostring(name))
            table.remove(self.cachedTextures, i)
            gl.DeleteTexture(obj.texture)
            self.cachedTexturesMapping[name] = nil
            return
        end
    end
    Log.Warning('Failed to delete texture: ' .. tostring(name))
end

function TextureManager:GetTexture(name)
    local cachedTex = self.cachedTexturesMapping[name]
    if cachedTex ~= nil then
        return cachedTex.texture
    else
        return name
    end
end

function TextureManager:__SetActiveMapTexture(i, j)
    local mapTexture = self.mapFBOTextures[i][j]
    self.activeDrawing:SetActiveTexture(mapTexture)
end

function TextureManager:BackupShadingTexture(name)
    local texObj = self.shadingTextures[name]
    self.activeDrawing:SetActiveTexture(texObj)
end


function TextureManager:PushStack()
    local stackItem = self.activeDrawing:Get()
    self.stack:PushStack(stackItem)
    self.activeDrawing:Reset()
end

function TextureManager:RemoveFirst()
    self.stack:RemoveFirst()
end

function TextureManager:PopStack()
    self.stack:PopStack()
    self.activeDrawing:Reset()
end
