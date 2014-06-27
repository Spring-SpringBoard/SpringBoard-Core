AreaView = LCS.class{}

function AreaView:init(areaId)
    self.areaId = areaId
    self.selected = false
end

function AreaView:_Draw(x1, z1, x2, z2)
    if x1 > x2 then
        x1, x2 = x2, x1
    end
    if z1 > z2 then
        z1, z2 = z2, z1
    end
    gl.PushMatrix()
    --    gl.Translate(0, 0, 0)
--        gl.Rotate(90, 1, 0, 0)
--        local y = Spring.GetGroundHeight(x1, z1)    
--        gl.Translate(0, 0, -y)
        local bt = 4
        gl.Color(1, 1, 1, 0.7)
        --Instead of actually drawing lines, we're drawing really small quads!
        gl.Utilities.DrawGroundRectangle(x1-bt, z1-bt, x1, z2+bt)
        gl.Utilities.DrawGroundRectangle(x2, z1-bt, x2+bt, z2+bt)
        gl.Utilities.DrawGroundRectangle(x1, z1-bt, x2, z1)
        gl.Utilities.DrawGroundRectangle(x1, z2, x2, z2+bt)
    gl.PopMatrix()

    gl.PushMatrix()
        if self.selected then
            gl.Color(0, 1, 1, 0.2)
        else
            gl.Color(0, 1, 0, 0.2)
        end
        gl.Utilities.DrawGroundRectangle(x1,z1,x2,z2)
    gl.PopMatrix()

    gl.PushMatrix()
        gl.Rotate(90, 1, 0, 0)
        local fontSize = 58
        local txt = tostring(self.areaId)
        local w = gl.GetTextWidth(txt) * fontSize
        local h = gl.GetTextHeight(txt) * fontSize
        local cx = (x1 + x2 - w) / 2
        local cz = (z1 + z2 + h) / 2
        local y = Spring.GetGroundHeight(cx, cz)
        gl.Translate(cx, cz, -y)
        gl.Color(1, 1, 1, 1)    
        gl.Rotate(180, 0, 0, 1)
        gl.Scale(-1, 1, 1)
        gl.Text(txt, 0, 0, fontSize)
    gl.PopMatrix()
end

function AreaView:Draw()
    x1, z1, x2, z2 = unpack(SCEN_EDIT.model.areaManager:getArea(self.areaId))
    self:_Draw(x1, z1, x2, z2)
end
