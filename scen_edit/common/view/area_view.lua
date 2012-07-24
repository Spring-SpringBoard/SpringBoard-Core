AreaView = LCS.class{}

function AreaView:init(areaId)
    self.areaId = areaId
    self.selected = false
end

function AreaView:Draw()
    x1, z1, x2, z2 = unpack(SCEN_EDIT.model.areaManager:getArea(self.areaId))
    if self.selected then
        gl.Color(0, 127, 127, 0.2)
    else
        gl.Color(0, 255, 0, 0.2)
    end
    if x1 < x2 then
        _x1 = x1
        _x2 = x2
    else
        _x1 = x2
        _x2 = x1
    end
    if z1 < z2 then
        _z1 = z1
        _z2 = z2
    else
        _z1 = z2
        _z2 = z1 
    end

    gl.DrawGroundQuad(_x1, _z1, _x2, _z2)
end
