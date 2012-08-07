local squareTextures = {}
local staticTextures = false
local staticTexNames = {[1] = {[1] = "LuaUI/images/scenedit/brush_textures/stone.png", [2] = false}, }
local numTexSquaresX = Game.mapSizeX / 1024
local numTexSquaresZ = Game.mapSizeZ / 1024
local lastGameFrame = -1

local mrandom = math.random
local mfloor = math.floor
local mmodulo = math.fmod

local glTexture = gl.Texture
local glCreateTexture = gl.CreateTexture
local glDeleteTexture = gl.DeleteTexture
local SpringGetGameFrame = Spring.GetGameFrame
local SpringSetMapSquareTexture = Spring.SetMapSquareTexture
local SpringGetMapSquareTexture = Spring.GetMapSquareTexture



function widget:GetInfo()
	return {
		name = "MapTextureRandomizer",
		desc = "",
		author = "Kloot",
		date = "",
		license = "",
		layer = 0,
		enabled = false,
	}
end



function widget:Initialize()
	if (not staticTextures) then
		local texMIP = 0
		local texSQS = 1024

		for mip = 0, (texMIP - 1) do
			texSQS = texSQS / 2
		end

		for i = 1, (numTexSquaresX * numTexSquaresZ) do
			squareTextures[i] = glCreateTexture(texSQS, texSQS, {wrap_s = GL.CLAMP, wrap_t = GL.CLAMP})

			local texSquareX = mmodulo((i - 1), numTexSquaresX)
			local texSquareZ = mfloor((i - 1) / numTexSquaresX)

			SpringGetMapSquareTexture(texSquareX, texSquareZ, texMIP, squareTextures[i])
		end
	end
end

function widget:Shutdown()
	if (not staticTextures) then
		for i = 1, #squareTextures do
			local texSquareX = mmodulo((i - 1), numTexSquaresX)
			local texSquareZ = mfloor((i - 1) / numTexSquaresX)

			SpringSetMapSquareTexture(texSquareX, texSquareZ, "")
			glDeleteTexture(squareTextures[i])
		end
	else
		SpringSetMapSquareTexture(0, 0, "")
		glDeleteTexture(staticTexNames[1][1])
	end
end



function widget:DrawWorld()
	if (not staticTextures) then
		if (SpringGetGameFrame() ~= lastGameFrame) then
			lastGameFrame = SpringGetGameFrame()

			if (mmodulo(lastGameFrame, Game.gameSpeed) == 0) then
				for i = 1, #squareTextures do
					local texSquareX = mrandom(0, numTexSquaresX - 1)
					local texSquareZ = mrandom(0, numTexSquaresZ - 1)
					local texSquareN = mrandom(0, #squareTextures - 1)

					SpringSetMapSquareTexture(texSquareX, texSquareZ, squareTextures[texSquareN + 1])
				end
			end
		end
	else
		if (not staticTexNames[1][2]) then
			staticTexNames[1][2] = true

			-- the mundane way
			glTexture(0, staticTexNames[1][1])
			glTexture(0, false)
			SpringSetMapSquareTexture(0, 0, staticTexNames[1][1])
		end
	end
end
