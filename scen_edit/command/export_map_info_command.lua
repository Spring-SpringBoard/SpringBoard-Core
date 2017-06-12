ExportMapInfoCommand = Command:extends{}
ExportMapInfoCommand.className = "ExportMapInfoCommand"

function ExportMapInfoCommand:init(path)
    self.className = "ExportMapInfoCommand"
    self.path = path
    --add extension if it doesn't exist
    if string.sub(self.path, -string.len(SB_MAP_INFO_FILE_EXT)) ~= SB_MAP_INFO_FILE_EXT then
        self.path = self.path .. SB_MAP_INFO_FILE_EXT
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
    local tbl = {
        teams = {}
    }
    for _, team in pairs(SB.model.teamManager:getAllTeams()) do
        local areaId = team.startPos
        local area
        if areaId then
            area = SB.model.areaManager:getArea(areaId)
            if not area then
                Log.Warning("No area for id: " .. tostring(areaId))
            end
        end
        if area then
            -- FIXME: We're just taking the middle point of the area
            -- Ugly but sue me ^_^
            table.insert(tbl.teams, {
                startPos = {
                    x = (area[1] + area[3]) / 2,
                    z = (area[1] + area[4]) / 2,
                }
            })
        end
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

lowerkeys(mapinfo)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Map Options

do
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

	getfenv()["mapinfo"] = mapinfo
		local files = VFS.DirList("mapconfig/mapinfo/", "*.lua")
		table.sort(files)
		for i=1,#files do
			local newcfg = VFS.Include(files[i])
			if newcfg then
				lowerkeys(newcfg)
				tmerge(mapinfo, newcfg)
			end
		end
	getfenv()["mapinfo"] = nil
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
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

    local mapInfo = {
        -- Section: Global
        name = scenarioInfo.name,
        description = scenarioInfo.description,
        version = scenarioInfo.version,
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
    }

    local file = assert(io.open(self.path, "w"))
    file:write("local mapInfo =")
    file:write(table.show(mapInfo):sub(#"return "))
    file:write(self:GetExtraString())
    file:write("return mapInfo")
    file:close()
end
