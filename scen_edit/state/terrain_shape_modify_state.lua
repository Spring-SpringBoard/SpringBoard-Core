TerrainShapeModifyState = AbstractHeightmapEditingState:extends{}

function TerrainShapeModifyState:init(heightmapEditorView)
    self:super("init", heightmapEditorView)
    self.paintTexture   = self.heightmapEditorView.paintTexture
end

function TerrainShapeModifyState:Apply(x, z, strength)
    if self:super("Apply", x, z, strength) then
        SCEN_EDIT.delayGL(function()
            if self.createdPaint == nil or self.createdPaint ~= self.paintTexture then
                local shapeSize = 256
                local tex = gl.CreateTexture(shapeSize, shapeSize, {
                    border = false,
                    min_filter = GL.LINEAR,
                    mag_filter = GL.LINEAR,
                    wrap_s = GL.CLAMP_TO_EDGE,
                    wrap_t = GL.CLAMP_TO_EDGE,
                    fbo = true,
                })
                
                imgPath = ':r' .. tostring(shapeSize) .. "," .. tostring(shapeSize) .. ':' .. self.paintTexture
                self.createdPaint = self.paintTexture

                local texInfo = gl.TextureInfo(tex)
                local w, h = texInfo.xsize, texInfo.ysize
                local res
                gl.Texture(imgPath)
                gl.RenderToTexture(tex, function()
                    gl.TexRect(-1,-1, 1, 1, 0, 0, 1, 1)
                    res = gl.ReadPixels(0, 0, w, h)
                end)
                gl.Texture(false)

                local greyscale = {}
                for i, row in pairs(res) do
                    for j, point in pairs(row) do
                        greyscale[(i-1) * #res + (j-1)] = (point[1] + point[2] + point[3]) / 3 * point[4]
                    end
                end

                greyscale = {
                    res = greyscale,
                    sizeX = #res,
                    sizeZ = #res[1],
                }

                --table.echo(greyscale)
                local cmd = SetHeightmapBrushCommand(greyscale)
                SCEN_EDIT.commandManager:execute(cmd)
            end

            local cmd = TerrainShapeModifyCommand(x, z, self.size, strength * 5)
            SCEN_EDIT.commandManager:execute(cmd)
        end)
        return true
    end
end

function TerrainShapeModifyState:DrawWorld()
    x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local x, z = coords[1], coords[3]
        gl.PushMatrix()
        gl.Color(1, 1, 1, 0.4)
        gl.Utilities.DrawGroundRectangle(x - self.size, z - self.size, x + self.size, z + self.size)
        gl.Color(0, 0.5, 0.5, 0.4)
        gl.Utilities.DrawGroundRectangle(x - self.size * 0.95, z - self.size * 0.95, x + self.size * 0.95, z + self.size * 0.95)
        gl.PopMatrix()
    end
end
