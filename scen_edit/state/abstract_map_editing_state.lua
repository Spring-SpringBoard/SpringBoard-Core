AbstractMapEditingState = AbstractEditingState:extends{}

function AbstractMapEditingState:init(editorView)
	AbstractEditingState.init(self, editorView)
    -- common fields
    self.size                = self.editorView.fields["size"].value
    if self.editorView.fields["rotation"] then
        self.rotation        = self.editorView.fields["rotation"].value
    end
end

function AbstractMapEditingState:KeyPress(key, mods, isRepeat, label, unicode)
    -- disable keybindings while changing stuff
    if self.startedChanging then
        return false
    end
    -- FIXME: cannot use "super" here in the current version of LCS and the new version is broken
    if AbstractEditingState.KeyPress(self, key, mods, isRepeat, label, unicode) then
        return true
    end

	return false
--     if key == 27 then -- KEYSYMS.ESC
--         SCEN_EDIT.stateManager:SetState(DefaultState())
--     else
--         return false
--     end
--     return true
end

function AbstractMapEditingState:CanApply()
	local now = os.clock()
    if not self.lastTime then
        self.lastTime = now
        return true
    end
    local delay = math.max(self.applyDelay or 0, self._initialDelay or 0)
    if delay ~= 0 then
        if now - self.lastTime >= delay then
            self.lastTime = now
            self._initialDelay = 0
            return true
        else
            return false
        end
    end
    return true
end

function AbstractMapEditingState:_Apply(...)
    if self:CanApply() then
		self:Apply(...)
	end
end

function AbstractMapEditingState:MousePress(x, y, button)
    if button == 1 or button == 3 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground"  then
            self:startChanging()
            self.x, self.z = coords[1], coords[3]
            self:_Apply(self:GetApplyParams(self.x, self.z, button))
            return true
        end
    end
end

function AbstractMapEditingState:MouseRelease(x, y, button)
    if button == 1 or button == 3 then
        self:stopChanging()
    end
end

function AbstractMapEditingState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground"  then
        self.x, self.z = coords[1], coords[3]
        self:_Apply(self:GetApplyParams(self.x, self.z, button))
    end
    return true
end

function AbstractMapEditingState:MouseWheel(up, value)
    local alt, _, _, shift = Spring.GetModKeyState()
    if shift then
        if up then
            self.size = self.size + self.size * 0.2 + 2
        else
            self.size = self.size - self.size * 0.2 - 2
        end
        self.editorView:Set("size", self.size)
        return true
    elseif alt and self.rotation ~= nil then
        if up then
            self.rotation = self.rotation + 5
        else
            self.rotation = self.rotation - 5
        end
        -- may uncomment this to rotate around
        -- self.rotation = self.rotation - math.floor(self.rotation/360) * 360
        self.editorView:Set("rotation", self.rotation)
        return true
    end
end

function AbstractMapEditingState:Update()
    if not self.startedChanging then
        return
    end
    if self.updateDelay then
        local now = os.clock()
        if not self.lastUpdateTime or now - self.lastUpdateTime >= self.updateDelay then
            self.lastUpdateTime = now
        else
            return false
        end
    end
    local x, y, button1, _, button3 = Spring.GetMouseState()
    local _, _, _, shift = Spring.GetModKeyState()
    if button1 or button3 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground" then
            local x, z = coords[1], coords[3]
            local tolerance = 200
            if math.abs(x - self.x) > tolerance or math.abs(z - self.z) > tolerance then
                self.x, self.z = x, z
            end
			local button
			if button1 then
				button = 1
			elseif button3 then
				button = 3
			end
            self:_Apply(self:GetApplyParams(self.x, self.z, button))
        end
    end
end

function AbstractMapEditingState:startChanging()
    if not self.startedChanging then
        self._initialDelay = self.initialDelay
        local cmd = SetMultipleCommandModeCommand(true)
        SCEN_EDIT.commandManager:execute(cmd)
        self.startedChanging = true
    end
end

function AbstractMapEditingState:stopChanging()
    if self.startedChanging then
        local cmd = SetMultipleCommandModeCommand(false)
        SCEN_EDIT.commandManager:execute(cmd)
        self.startedChanging = false
        self.lastTime = nil
    end
end

-- To implement custom states, override the following methods

function AbstractMapEditingState:GetApplyParams(x, z, button)
	return x, z
end

function AbstractMapEditingState:Apply(...)
end


function AbstractMapEditingState:initShader()
    local shaderFragStr = [[
        uniform sampler2D brushTex;
        void main()
        {
            vec4 brushColor = texture2D(brushTex, gl_TexCoord[0].st);
            gl_FragColor = gl_Color * brushColor.a;
            //gl_FragColor = gl_Color;
            //gl_FragColor = vec4(gl_TexCoord[0].st, 0, 1);
        }
    ]]

    local shaderTemplate = {
        fragment = shaderFragStr,
        uniformInt = {
            brushTex = 0,
        },
    }

    local shader = Shaders.Compile(shaderTemplate, "AbstractMapEditingState")
    if shader then
        self.shaderObj = {
            shader = shader,
        }
    end
end

-- minX,minY,minZ, maxX,maxY,maxZ
-- 0,   -0.5,  0,     1, 0.5,   1
function DrawRectangle()
    gl.BeginEnd(GL.QUADS, function()
    --                 gl.MultiTexCoord(0, mCoord[1], mCoord[2])
    --                 gl.MultiTexCoord(1, tCoord[1], tCoord[2] )
        gl.MultiTexCoord(0, 0, 0 )
        gl.Vertex(0, 0, 0)

    --                 gl.MultiTexCoord(0, mCoord[3], mCoord[4])
    --                 gl.MultiTexCoord(1, tCoord[3], tCoord[4] )
        gl.MultiTexCoord(0, 1, 0 )
        gl.Vertex(1, 0, 0)

    --                 gl.MultiTexCoord(0, mCoord[5], mCoord[6])
    --                 gl.MultiTexCoord(1, tCoord[5], tCoord[6] )
        gl.MultiTexCoord(0, 1, 1 )
        gl.Vertex(1, 0, 1)

    --                 gl.MultiTexCoord(0, mCoord[7], mCoord[8])
    --                 gl.MultiTexCoord(1, tCoord[7], tCoord[8] )
        gl.MultiTexCoord(0, 0, 1 )
        gl.Vertex(0, 0, 1)
    end)
end

-- local heightMargin = 2000
-- local averageGroundHeight = (minheight + maxheight) / 2
-- local shapeHeight = heightMargin + (maxheight - minheight) + heightMargin

function DrawTexturedGroundRectangle(x1,z1,x2,z2, rot, dlist)
  if (type(x1) == "table") then
    local rect = x1
    x1,z1,x2,z2 = rect[1],rect[2],rect[3],rect[4]
  end
  gl.PushMatrix()
  local sizeX, sizeZ = x2 - x1, z2 - z1
  local y = Spring.GetGroundHeight((x1+x2)/2, (z1+z2)/2) - 1
--   gl.Rotate(rot, 0, 1, 0)
  gl.Translate(x1, y, z1)
  gl.Translate(sizeX/2, 0, sizeZ/2)
  gl.Rotate(rot, 0, 1, 0)
  gl.Translate(-sizeX/2, 0, -sizeZ/2)
  gl.Scale(x2-x1, 1, z2-z1)
  gl.Utilities.DrawVolume(dlist)
  gl.PopMatrix()
end

function AbstractMapEditingState:DrawShape(shape, x, z)
    gl.PushMatrix()
    local scale = 1/2 * math.sqrt(2)
--     local rotRad = math.rad(self.rotation) + math.pi/2

    if not self.shaderObj then
        self:initShader()
        self.dlist = gl.CreateList(DrawRectangle)
    end
    gl.Texture(0, shape)
    gl.UseShader(self.shaderObj.shader)
    gl.Blending("alpha_add")
    gl.Color(0, 1, 0, 0.3)
--         gl.Utilities.DrawGroundRectangle(x-self.size, z-self.size, x+self.size, z+self.size)
    DrawTexturedGroundRectangle(x-self.size*scale, z-self.size*scale, x+self.size*scale, z+self.size*scale, self.rotation, self.dlist)
    gl.UseShader(0)
    gl.Texture(0, false)
    gl.Color(0, 1, 1, 0.5)
--     gl.Utilities.DrawGroundHollowCircle(x+self.size * math.sin(rotRad), z+self.size * math.cos(rotRad), self.size / 10, self.size / 12)
    gl.PopMatrix()
end
