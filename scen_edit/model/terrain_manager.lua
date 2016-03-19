TerrainManager = Observable:extends{}

function TerrainManager:init()
    self.shapes = {}
end

function TerrainManager:addShape(name, value)
    self.shapes[name] = value
end

function TerrainManager:getShape(name)
    return self.shapes[name]
end

function TerrainManager:generateShape(name)
    SCEN_EDIT.delayGL(function()
        local shapeSize = 256
        local texName = ':r' .. tostring(shapeSize) .. "," .. tostring(shapeSize) .. ':' .. name
        local tex = gl.CreateTexture(shapeSize, shapeSize, {
            border = false,
            min_filter = GL.LINEAR,
            mag_filter = GL.LINEAR,
            wrap_s = GL.CLAMP_TO_EDGE,
            wrap_t = GL.CLAMP_TO_EDGE,
            fbo = true,
        })

        self.createdPaint = self.paintTexture

        local texInfo = gl.TextureInfo(tex)
        local w, h = texInfo.xsize, texInfo.ysize
        local res
        gl.Texture(texName)
        gl.RenderToTexture(tex, function()
            gl.TexRect(-1,-1, 1, 1, 0, 0, 1, 1)
            res = gl.ReadPixels(0, 0, w, h)
        end)
        gl.Texture(false)

        local greyscale = {}
        for i, row in pairs(res) do
            for j, point in pairs(row) do
--                 greyscale[(i-1) + (j-1) * #res] = (point[1] + point[2] + point[3]) / 3 * point[4]
                greyscale[(i-1) + (j-1) * #res] = point[4]
            end
        end

        greyscale = {
            res = greyscale,
            sizeX = #res,
            sizeZ = #res[1],
            name = name,
        }

        self:addShape(name, greyscale)

        local cmd = SetHeightmapBrushCommand(greyscale)
        SCEN_EDIT.commandManager:execute(cmd)
    end)
end