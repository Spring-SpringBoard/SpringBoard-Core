ExportHeightmapCommand = Command:extends{}
ExportHeightmapCommand.className = "ExportHeightmapCommand"

function ExportHeightmapCommand:init(path, heightmapExtremes)
    self.path = path
    self.heightmapExtremes = heightmapExtremes
end

function ExportHeightmapCommand.GetShaderObj()
    if ExportHeightmapCommand.shaderObj ~= nil then
        return ExportHeightmapCommand.shaderObj
    end

    local heightmapScaleShader = [[
        uniform sampler2D heightmapTex;
        uniform float groundMin, groundMax;
        void main() {
            gl_FragColor = texture2D(heightmapTex, gl_TexCoord[0].st);
            gl_FragColor.rgb = (gl_FragColor.rgb - groundMin) / (groundMax - groundMin);
        }
    ]]

    local shader = Shaders.Compile({
        fragment = heightmapScaleShader,
        uniformInt = {heightmapTexID = 0 },
    }, "ExportMapsShader")
    if not shader then
        return
    end
    ExportHeightmapCommand.shaderObj = {
        shader = shader,
        uniforms = {
            heightmapTexID = gl.GetUniformLocation(shader, "heightmapTex"),
            groundMaxID    = gl.GetUniformLocation(shader, "groundMax"),
            groundMinID    = gl.GetUniformLocation(shader, "groundMin"),
        }
    }

    return ExportHeightmapCommand.shaderObj
end

local function ExportHeightmapWithSpring(path, minHeight, maxHeight)
    local texInfo = gl.TextureInfo("$heightmap")
    local GL_LUMINANCE32F_ARB = 0x8818
    if Platform.osFamily == "Windows" then
        GL_LUMINANCE32F_ARB = nil
    end
    local heightmapTexture = gl.CreateTexture(texInfo.xsize, texInfo.ysize, {
        format = GL_LUMINANCE32F_ARB,
        border = false,
        min_filter = GL.NEAREST,
        mag_filter = GL.NEAREST,
        wrap_s = GL.CLAMP_TO_EDGE,
        wrap_t = GL.CLAMP_TO_EDGE,
        fbo = true,
    })

    local shaderObj = ExportHeightmapCommand.GetShaderObj()
    gl.UseShader(shaderObj.shader)
    gl.Uniform(shaderObj.uniforms.groundMaxID, maxHeight)
    gl.Uniform(shaderObj.uniforms.groundMinID, minHeight)
    gl.Texture(0, "$heightmap")
    gl.RenderToTexture(heightmapTexture,
    function()
        gl.TexRect(-1,-1, 1, 1)
    end)
    gl.Texture(0, false)
    gl.UseShader(0)

    local useGrayscale16bit = true
    if Platform.osFamily == "Windows" then
        useGrayscale16bit = false
    end
    gl.RenderToTexture(heightmapTexture, gl.SaveImage, 0, 0, texInfo.xsize, texInfo.ysize, path, {grayscale16bit = useGrayscale16bit})
    gl.DeleteTexture(heightmapTexture)
end

local function ExportHeightmapWithLauncher(path, minHeight, maxHeight)
    WG.Connector.Send("ConvertSBHeightmap", {
        inPath = VFS.GetFileAbsolutePath(Path.Join(projectPath, "heightmap.data"):lower()),
        outPath = path,
        width = Game.mapSizeX,
        height = Game.mapSizeZ,
        min = minHeight,
        max = maxHeight
    })
end

local function ExportHeightmap(path, heightmapExtremes)
    Log.Notice("Saving the heightmap to " .. path .. "...")

    if VFS.FileExists(path, VFS.RAW) then
        Log.Notice("Removing the existing heightmap")
        os.remove(path)
    end

    local minHeight, maxHeight
    if heightmapExtremes ~= nil then
        minHeight, maxHeight = heightmapExtremes[1], heightmapExtremes[2]
    else
        minHeight, maxHeight = math.huge, -math.huge
        for x = 0, Game.mapSizeX, Game.squareSize do
            for z = 0, Game.mapSizeZ, Game.squareSize do
                local groundHeight = Spring.GetGroundHeight(x, z)
                if groundHeight > maxHeight then
                    maxHeight = groundHeight
                end
                if groundHeight < minHeight then
                    minHeight = groundHeight
                end
            end
        end
    end
    Log.Notice("Exporting heightmap with extremes: " ..
                tostring(minHeight) .. " and " .. tostring(maxHeight))

    if Platform.osFamily == "Windows" then
        ExportHeightmapWithLauncher(path, minHeight, maxHeight)
    else
        ExportHeightmapWithSpring(path, minHeight, maxHeight)
    end
end

function ExportHeightmapCommand:execute()
    SB.delayGL(function()
        Spring.CreateDir(Path.GetParentDir(self.path))

        Time.MeasureTime(function()
            Spring.ClearWatchDogTimer(nil, true)
            ExportHeightmap(self.path, self.heightmapExtremes)
            Spring.ClearWatchDogTimer(nil, false)
        end, function (elapsed)
            Log.Notice(("[%.4fs] Exported heightmap"):format(elapsed))
        end)
    end)
end