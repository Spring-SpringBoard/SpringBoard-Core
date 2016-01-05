TerrainChangeTextureState = AbstractMapEditingState:extends{}
SCEN_EDIT.Include("scen_edit/model/texture_manager.lua")

function TerrainChangeTextureState:init(editorView)
    AbstractMapEditingState.init(self, editorView)
    self.paintTexture   = self.editorView.paintTexture
    self.brushTexture   = self.editorView.brushTexture
    self.texScale       = self.editorView.fields["texScale"].value
    self.mode           = self.editorView.fields["mode"].value
    self.blendFactor    = self.editorView.fields["blendFactor"].value
    self.falloffFactor  = self.editorView.fields["falloffFactor"].value
    self.featureFactor  = self.editorView.fields["featureFactor"].value
    self.diffuseColor   = self.editorView.fields["diffuseColor"].value
    self.texOffsetX     = self.editorView.fields["texOffsetX"].value
    self.texOffsetY     = self.editorView.fields["texOffsetY"].value
	self.diffuseEnabled = self.editorView.fields["diffuseEnabled"].value
	self.specularEnabled= self.editorView.fields["specularEnabled"].value
	self.normalEnabled  = self.editorView.fields["normalEnabled"].value
	self.voidFactor     = self.editorView.fields["voidFactor"].value

    self.updateDelay    = 0.2
    self.applyDelay     = 0.02
end

function TerrainChangeTextureState:initShader()
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

    local shader = gl.CreateShader(shaderTemplate)
    local errors = gl.GetShaderLog(shader)
    if errors ~= "" then
        Spring.Log("Scened", "error", "Error creating shader: " .. tostring(errors))
    else
        self.shaderObj = {
            shader = shader,
        }
    end
end

function TerrainChangeTextureState:Apply(x, z, voidFactor)
    if not self.brushTexture.diffuse then
        return
    end
	local opts = {
		x = x - self.size/2,
		z = z - self.size/2,
		size = self.size,
		rotation = self.rotation,
		paintTexture = self.paintTexture,
        brushTexture = self.brushTexture.diffuse, -- FIXME: shouldn't be called "diffuse"
		texScale = self.texScale,
		mode = self.mode,
		blendFactor = self.blendFactor,
		falloffFactor = self.falloffFactor,
		featureFactor = self.featureFactor,
		diffuseColor = self.diffuseColor,
		texOffsetX = self.texOffsetX,
		texOffsetY = self.texOffsetY,
		diffuseEnabled = self.diffuseEnabled,
		specularEnabled = self.specularEnabled,
		normalEnabled = self.normalEnabled,
		voidFactor = voidFactor,
		void = not not self.void,
		smartPaint = not not self.smartPaint,
        blur = not not self.blur,
		textures = self.textures,
	}
	local command = TerrainChangeTextureCommand(opts)
	SCEN_EDIT.commandManager:execute(command)
end

function TerrainChangeTextureState:leaveState()
    self.editorView:Select(0)
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

local heightMargin = 2000
local minheight, maxheight = Spring.GetGroundExtremes()  --the returned values do not change even if we terraform the map
local averageGroundHeight = (minheight + maxheight) / 2
local shapeHeight = heightMargin + (maxheight - minheight) + heightMargin

function DrawTexturedGroundRectangle(x1,z1,x2,z2, dlist)
  if (type(x1) == "table") then
    local rect = x1
    x1,z1,x2,z2 = rect[1],rect[2],rect[3],rect[4]
  end
  gl.PushMatrix()
  gl.Translate(x1, averageGroundHeight, z1)
  gl.Scale(x2-x1, shapeHeight, z2-z1)
  gl.Utilities.DrawVolume(dlist)
  gl.PopMatrix()
end

function TerrainChangeTextureState:DrawWorld()
    if not self.brushTexture.diffuse then
        return
    end
    x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local x, z = coords[1], coords[3]
        gl.PushMatrix()
        if not self.shaderObj then
            self:initShader()
            self.dlist = gl.CreateList(DrawRectangle)
        end
        gl.UseShader(self.shaderObj.shader)
        local tex = SCEN_EDIT.model.textureManager:GetTexture(self.brushTexture.diffuse)
        gl.Texture(0, tex)
		gl.Blending("alpha_add")
        gl.Color(0, 1, 0, 0.3)
--         gl.Utilities.DrawGroundRectangle(x-self.size, z-self.size, x+self.size, z+self.size)
        local scale = 1/2 * math.sqrt(2)
        DrawTexturedGroundRectangle(x-self.size*scale, z-self.size*scale, x+self.size*scale, z+self.size*scale, self.dlist)
        gl.UseShader(0)
        gl.Texture(0, false)
        gl.Color(0, 1, 1, 0.5)
        local rotRad = math.rad(self.rotation) + math.pi/2
        gl.Utilities.DrawGroundHollowCircle(x+self.size * math.sin(rotRad), z+self.size * math.cos(rotRad), self.size / 10, self.size / 12)
        gl.PopMatrix()
    end
end

function TerrainChangeTextureState:GetApplyParams(x, z, button)
	local voidFactor = self.voidFactor
	if button == 3 then
		voidFactor = -1
	end
	return x, z, voidFactor
end
