ExportMapInfoCommand = Command:extends{}
ExportMapInfoCommand.className = "ExportMapInfoCommand"

function ExportMapInfoCommand:init(path)
    self.path = path
    if Path.GetExt(self.path) ~= ".lua" then
        self.path = self.path .. ".lua"
    end
end

function ExportMapInfoCommand:GetAtmosphere()
    local tbl = {
        -- FIXME: not set
        --minWind = 5,
        --maxWind = 25,

        fogStart = gl.GetAtmosphere("fogStart"),
        fogEnd = gl.GetAtmosphere("fogEnd"),
        fogColor = {gl.GetAtmosphere("fogColor")},

        -- FIXME: not set
        skyBox = "",
        skyColor = {gl.GetAtmosphere("skyColor")},
        -- FIXME: not set
        --skyDir = gl.GetAtmosphere("skyDir"),
        sunColor = {gl.GetAtmosphere("sunColor")},
        cloudColor = {gl.GetAtmosphere("cloudColor")},
        -- FIXME: not set
        --fluidDensity = ,
        --cloudDensity = ,
    }
    return tbl
end

function ExportMapInfoCommand:GetGrass()
    local tbl = {
        -- FIXME: not set
        -- bladeWaveScale = 1.0,
        -- bladeWidth  = 0.8,
        -- bladeHeight = 4.5,
        -- bladeAngle  = 1.0,
        -- maxStrawsPerTurf = 150,
        -- bladeColor  = {0.1, 0.1, 0.1},
        -- bladeTexName = "",
    }
    return tbl
end

function ExportMapInfoCommand:GetLighting()
    local tbl = {
        sunDir = {gl.GetSun()},

        groundAmbientColor = {gl.GetSun("ambient")},
        groundDiffuseColor = {gl.GetSun("diffuse")},
        groundSpecularColor = {gl.GetSun("specular")},
        groundShadowDensity = gl.GetSun("shadowDensity"),

        unitAmbientColor = {gl.GetSun("ambient", "unit")},
        unitDiffuseColor = {gl.GetSun("diffuse", "unit")},
        unitSpecularColor = {gl.GetSun("specular", "unit")},
        unitShadowDensity = gl.GetSun("shadowDensity", "unit"),

        -- FIXME: not set
        --specularExponent = "",
    }
    return tbl
end

function ExportMapInfoCommand:GetWater()
    local tbl = {
        -- FIXME: not set
        --fluidDensity = 0,
        repeatX = gl.GetWaterRendering("repeatX"),
        repeatY = gl.GetWaterRendering("repeatY"),
        -- FIXME: not set
        --damage = 0,

        -- FIXME: not set
        --absorb    =
        --baseColor =
        --minColor  =

        ambientFactor = gl.GetWaterRendering("ambientFactor"),
        diffuseFactor = gl.GetWaterRendering("diffuseFactor"),
        specularFactor = gl.GetWaterRendering("specularFactor"),
        specularPower = gl.GetWaterRendering("specularPower"),

        planeColor = {gl.GetWaterRendering("planeColor")},
        hasWaterPlane = gl.GetWaterRendering("hasWaterPlane"),

        -- FIXME: not set
        -- surfaceColor,
        -- surfaceAlpha,
        diffuseColor = {gl.GetWaterRendering("diffuseColor")},
        specularColor = {gl.GetWaterRendering("specularColor")},

        fresnelMin = gl.GetWaterRendering("fresnelMin"),
        fresnelMax = gl.GetWaterRendering("fresnelMax"),
        fresnelPower = gl.GetWaterRendering("fresnelPower"),

        reflectionDistortion = gl.GetWaterRendering("reflectionDistortion"),

        blurBase = gl.GetWaterRendering("blurBase"),
        blurExponent = gl.GetWaterRendering("blurExponent"),

        perlinStartFreq = gl.GetWaterRendering("perlinStartFreq"),
        perlinLacunarity = gl.GetWaterRendering("perlinLacunarity"),
        perlinAmplitude = gl.GetWaterRendering("perlinAmplitude"),
        -- FIXME: not set
        -- windSpeed

        texture = gl.GetWaterRendering("texture"),
        foamTexture = gl.GetWaterRendering("foamTexture"),
        normalTexture = gl.GetWaterRendering("normalTexture"),

        shoreWaves = gl.GetWaterRendering("shoreWaves"),

        forceRendering = gl.GetWaterRendering("forceRendering"),

        numTiles = gl.GetWaterRendering("numTiles"),
        -- FIXME: not set
        -- caustics
    }
    return tbl
end

function ExportMapInfoCommand:GetTeams()
    local tbl = {}
    local counter = 0 -- teams start with 0
    for _, team in pairs(SB.model.teamManager:getAllTeams()) do
        local areaID = team.startPos
        local area
        if areaID then
            area = SB.model.areaManager:getArea(areaID)
            if not area then
                Log.Warning("No area for id: " .. tostring(areaID))
            end
        end
        if not area then
            area = { -- if there's no area, we default to the entire map
                0, 0, Game.mapSizeX, Game.mapSizeZ
            }
        end
        -- FIXME: We're just taking the middle point of the area
        -- Ugly but sue me ^_^
        tbl[counter] = {
            startPos = {
                x = (area[1] + area[3]) / 2,
                z = (area[1] + area[4]) / 2,
            }
        }
        counter = counter + 1
    end
    return tbl
end

function ExportMapInfoCommand:GetTerrainTypes()
    local tbl = {
        -- FIXME: nothing set
    }
    return tbl
end

function ExportMapInfoCommand:GetCustom()
    local tbl = {
        -- FIXME: nothing set
    }
    return tbl
end

function ExportMapInfoCommand:GetSMF()
    local maxH, minH = -math.huge, math.huge
    for z = 0, Game.mapSizeZ, Game.squareSize do
        for x = 0, Game.mapSizeX, Game.squareSize do
            local groundHeight = Spring.GetGroundHeight(x, z)
            if groundHeight > maxH then
                maxH = groundHeight
            end
            if groundHeight < minH then
                minH = groundHeight
            end
        end
    end

    local tbl = {
        minheight = minH,
		maxheight = maxH,
		smtFileName0 = SB.project.name .. ".smt",
    }
    return tbl
end

function ExportMapInfoCommand:GetResources()
    -- Engine parses these textures from the resource table.
    -- These are the possible values:
        -- detailTex
        -- specularTex
        -- splatDetailTex
        -- splatDistrTex
        -- splatDetailNormalTex
        -- grassShadingTex
        -- skyReflectModTex
        -- detailNormalTex
        -- lightEmissionTex
        -- parallaxHeightTex

    -- However, we ONLY support the following subset (code below)

    local tbl = {
        splatDetailNormalDiffuseAlpha = gl.GetMapRendering("splatDetailNormalDiffuseAlpha"),
    }
    for texType, shadingTexObj in pairs(SB.model.textureManager.shadingTextures) do
        local fileName = texType .. ".png"
        -- FIXME: HARDCODED
        if texType == "specular" then
            tbl["specularTex"] = fileName
        elseif texType == "splat_distr" then
            tbl["splatDistrTex"] = fileName
        elseif texType:find("splat_normals") ~= nil then
            local key = "splatDetailNormalTex" .. texType:sub(#"splat_normals" + 1)
            tbl[key] = fileName
        end
    end
    return tbl
end

function ExportMapInfoCommand:GetExtraString()
    return [[
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Helper

local function lowerkeys(ta)
    local fix = {}
    for i,v in pairs(ta) do
        if (type(i) == "string") then
            if (i ~= i:lower()) then
                fix[#fix+1] = i
            end
        end
        if (type(v) == "table") then
            lowerkeys(v)
        end
    end

    for i=1,#fix do
        local idx = fix[i]
        ta[idx:lower()] = ta[idx]
        ta[idx] = nil
    end
end

lowerkeys(mapInfo)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Map Options

if (Spring) then
    local function tmerge(t1, t2)
        for i,v in pairs(t2) do
            if (type(v) == "table") then
                t1[i] = t1[i] or {}
                tmerge(t1[i], v)
            else
                t1[i] = v
            end
        end
    end

    -- make code safe in unitsync
    if (not Spring.GetMapOptions) then
        Spring.GetMapOptions = function() return {} end
    end
    function tobool(val)
        local t = type(val)
        if (t == 'nil') then
            return false
        elseif (t == 'boolean') then
            return val
        elseif (t == 'number') then
            return (val ~= 0)
        elseif (t == 'string') then
            return ((val ~= '0') and (val ~= 'false'))
        end
        return false
    end

    getfenv()["mapInfo"] = mapInfo
        local files = VFS.DirList("mapconfig/mapinfo/", "*.lua")
        table.sort(files)
        for i=1,#files do
            local newcfg = VFS.Include(files[i])
            if newcfg then
                lowerkeys(newcfg)
                tmerge(mapInfo, newcfg)
            end
        end
    getfenv()["mapInfo"] = nil
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return mapInfo
]]
end

function ExportMapInfoCommand:execute()
    local scenarioInfo = SB.model.scenarioInfo

    local atmosphere = self:GetAtmosphere()
    local grass = self:GetGrass()
    local lighting = self:GetLighting()
    local water = self:GetWater()
    local teams = self:GetTeams()
    local terrainTypes = self:GetTerrainTypes()
    local custom = self:GetCustom()
    local smf = self:GetSMF()
    local resources = self:GetResources()

    local mapInfo = {
        -- Section: Global
        -- name = scenarioInfo.name,
        name = SB.project.name,
        description = scenarioInfo.description,
        -- version = scenarioInfo.version,
        version = "1.0",
        author = scenarioInfo.author,

        -- Constant (OK)
        shortname   = "",
        modtype     = 3, --// 1=primary, 0=hidden, 3=map
        depend      = {"Map Helper v1"},
        replace     = {},

        -- FIXME: not set
        --maphardness     = 800,
        --notDeformable   = false,

        --gravity         = 130,

        --tidalStrength   = 0,
        --maxMetal        = 1,
        --extractorRadius = 0,
        voidWater       = gl.GetMapRendering and gl.GetMapRendering("voidWater"),
        voidGround      = gl.GetMapRendering and gl.GetMapRendering("voidGround"),

        -- Section: GUI
        --autoShowMetal   = true,

        atmosphere = atmosphere,
        grass = grass,
        lighting = lighting,
        water = water,
        teams = teams,
        terrainTypes = terrainTypes,
        custom = custom,
        smf = smf,
        resources = resources,
    }

    local file = assert(io.open(self.path, "w"))
    file:write("local mapInfo =")
    file:write(table.show(mapInfo):sub(#"return "))
    file:write(self:GetExtraString())
    file:close()
end
