TerrainChangeTextureState = AbstractState:extends{}
SCEN_EDIT.Include("scen_edit/model/texture_manager.lua")

--FIXME: remove this default pen
local penTexture = "bitmaps/detailtex.bmp"

local BIG_TEX_SIZE = 128*8 --bigTexSize      = (SQUARE_SIZE * bigSquareSize);
local mapTexSQ = gl.CreateTexture(BIG_TEX_SIZE,BIG_TEX_SIZE, {
    border = false,
    min_filter = GL.NEAREST,
    mag_filter = GL.NEAREST,
    wrap_s = GL.CLAMP_TO_EDGE,
    wrap_t = GL.CLAMP_TO_EDGE,
    fbo = true, 
})

local penBlenders = {
    --'from'
    --// 2010 Kevin Bjorke http://www.botzilla.com
    --// Uses Processing & the GLGraphics library
    ["BlendNormal"] = [[mix(penColor,mapColor,penColor.a);]],

    ["BlendAdd"] = [[mix((mapColor+penColor),mapColor,penColor.a);]],

    ["BlendColorBurn"] = [[mix(1.0-(1.0-mapColor)/penColor,mapColor,penColor.a);]],

    ["BlendColorDodge"] = [[mix(mapColor/(1.0-penColor),mapColor,penColor.a);]],

    ["BlendColor"] = [[mix(sqrt(dot(mapColor.rgb,mapColor.rgb)) * normalize(penColor),mapColor,penColor.a);]],

    ["BlendDarken"] = [[mix(min(mapColor,penColor),mapColor,penColor.a);]],

    ["BlendDifference"] = [[mix(abs(penColor-mapColor),mapColor,penColor.a);]],

    ["BlendExclusion"] = [[mix(penColor+mapColor-(2.0*penColor*mapColor),mapColor,penColor.a);]],

    ["BlendHardLight"] = [[mix(lerp(2.0 * mapColor * penColor,1.0 - 2.0*(1.0-penColor)*(1.0-mapColor),min(1.0,max(0.0,10.0*(dot(vec4(0.25,0.65,0.1,0.0),penColor)- 0.45)))),mapColor,penColor.a);]],

    ["BlendInverseDifference"] = [[mix(1.0-abs(mapColor-penColor),mapColor,penColor.a);]],

    ["BlendLighten"] = [[mix(max(penColor,mapColor),mapColor,penColor.a);]],

    ["BlendLuminance"] = [[mix(dot(penColor,vec4(0.25,0.65,0.1,0.0))*normalize(mapColor),mapColor,penColor.a);]],

    ["BlendMultiply"] = [[mix(penColor*mapColor,mapColor,penColor.a);]],

    ["BlendOverlay"] = [[mix(lerp(2.0 * mapColor * penColor,1.0 - 2.0*(1.0-penColor)*(1.0-mapColor),min(1.0,max(0.0,10.0*(dot(vec4(0.25,0.65,0.1,0.0),mapColor)- 0.45)))),mapColor,penColor.a);]],

    ["BlendPremultiplied"] = [[vec4(penColor.rgb + (1.0-penColor.a)*mapColor.rgb, (penColor.a+mapColor.a));]],

    ["BlendScreen"] = [[mix(1.0-(1.0-mapColor)*(1.0-penColor),mapColor,penColor.a);]],

    ["BlendSoftLight"] = [[mix(2.0*mapColor*penColor+mapColor*mapColor-2.0*mapColor*mapColor*penColor,mapColor,penColor.a);]],

    ["BlendSubtract"] = [[mix(mapColor-penColor,mapColor,penColor.a);]],

    ["BlendUnmultiplied"] = [[mix(penColor,mapColor,penColor.a);]],

    ["BlendRAW"] = [[penColor;]], --//TODO make custom shaders for specular textures
}

local shaderFragStr = [[                    

uniform sampler2D mapTex;
uniform sampler2D penTex;
uniform sampler2D paintTex;

vec4 mix(vec4 penColor, vec4 mapColor, float alpha) {
    return vec4(penColor.rgb * alpha + mapColor.rgb * (1.0 - alpha), 1.0);
}

void main(void)
{
    vec4 mapColor = texture2D(mapTex,gl_TexCoord[0].st);
    vec4 penColor = texture2D(penTex,gl_TexCoord[1].st);
    vec4 texColor = texture2D(paintTex,gl_TexCoord[2].st);
    
    penColor = (gl_Color*penColor*texColor);
    vec4 color = %s  //mix(penColor,mapColor,penColor.a);

    vec2 delta = vec2(0.5, 0.5) - gl_TexCoord[1].xy;
    float distance = sqrt(delta.x * delta.x + delta.y * delta.y);    
    color.a -= 2 * distance;

    gl_FragColor = color;
}
]]
local shaderTemplate = {
    fragment = string.format(shaderFragStr,penBlenders["BlendRAW"]),
    uniformInt = {
        mapTex = 0,
        penTex = 1,
        paintTex = 2,
    },
}

penShader = gl.CreateShader(shaderTemplate)
function TerrainChangeTextureState:ApplyPen(pointsXZ, x, z, penTexture)
    local rT
    local texSizeX = BIG_TEX_SIZE
    local texSizeY = BIG_TEX_SIZE

    gl.Texture(1, penTexture)
    gl.Texture(2, self.paintTexture)
    ptX,ptZ = math.pi, math.pi

    if penShader then gl.UseShader(penShader) end

    local textures = SCEN_EDIT.model.tm:getMapTextures(x, z, x + 2*self.size, z + 2*self.size)
    for _, v in pairs(textures) do
        local mapTexSQ, coords = v[1], v[2]
        local x, z = coords[1], coords[2]
        local dx, dz = x, z 
        gl.RenderToTexture(mapTexSQ,
        function()
            local pp = {dx+pointsXZ[1],dz+pointsXZ[2], dx+pointsXZ[3],dz+pointsXZ[4],dx+pointsXZ[7],dz+pointsXZ[8],dx+pointsXZ[5],dz+pointsXZ[6]}
            local fx,fz = pointsXZ[1],pointsXZ[2]
            for i=1,#pp,2 do
                pp[i] = (pp[i]-fx)/texSizeX*2-1
                pp[i+1] = (pp[i+1]-fz)/texSizeY*2-1
            end

            gl.BeginEnd(GL.POLYGON --GL.QUADS
            ,function()
                gl.MultiTexCoord(1, 0,0)  
                gl.MultiTexCoord(0, (pp[1]+1)/2,(pp[2]+1)/2)
                gl.MultiTexCoord(2, (pp[1]+1)*ptX,(pp[2]+1)*ptZ)
                gl.Vertex(pp[1], pp[2])

                gl.MultiTexCoord(1, 0,1)  
                gl.MultiTexCoord(0, (pp[3]+1)/2,(pp[4]+1)/2) 
                gl.MultiTexCoord(2, (pp[3]+1)*ptX,(pp[4]+1)*ptZ)
                gl.Vertex(pp[3], pp[4]) 

                gl.MultiTexCoord(1, 1,1)  
                gl.MultiTexCoord(0, (pp[7]+1)/2,(pp[8]+1)/2)
                gl.MultiTexCoord(2, (pp[7]+1)*ptX,(pp[8]+1)*ptZ)
                gl.Vertex(pp[7], pp[8]) 

                gl.MultiTexCoord(1, 1,0)  
                gl.MultiTexCoord(0, (pp[5]+1)/2,(pp[6]+1)/2)
                gl.MultiTexCoord(2, (pp[5]+1)*ptX,(pp[6]+1)*ptZ)
                gl.Vertex(pp[5], pp[6])

            end
            )
        end)

        gl.Texture(0, false)
        rT = tex

        local errors = gl.GetShaderLog(penShader)
        if errors ~= "" then
            Spring.Echo(errors)
        end
    end
    gl.UseShader(0)

    return rT
end

function TerrainChangeTextureState:init(paintTexture, textureImages)
    self.size = 100
    self.paintTexture = paintTexture
	self.textureImages = textureImages
    Spring.Echo(self.paintTexture)
end

function TerrainChangeTextureState:SetTexture(x, z, textureName)
    local mapPoints = {x,z,x,z+2*self.size, x+2*self.size,z+2*self.size, x+2*self.size,z}
    tx = self:ApplyPen(mapPoints, x, z, penTexture)
end

function TerrainChangeTextureState:MousePress(x, y, button)
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground"  then
            SCEN_EDIT.delayGL(function()
                local x, z = coords[1] - self.size, coords[3] - self.size
                self:SetTexture(x, z, textureName) 
            end)
            return true
        end
    elseif button == 3 then
        SCEN_EDIT.stateManager:SetState(DefaultState())
		self.textureImages:Select(0)
    end
end

function TerrainChangeTextureState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground"  then
        SCEN_EDIT.delayGL(function ()
            local x, z = coords[1] - self.size, coords[3] - self.size
            self:SetTexture(x, z, textureName) 
        end)
    end
end

function TerrainChangeTextureState:MouseRelease(x, y, button)
end

function TerrainChangeTextureState:KeyPress(key, mods, isRepeat, label, unicode)
end

function TerrainChangeTextureState:MouseWheel(up, value)
    local _, ctrl = Spring.GetModKeyState()
    if ctrl then
        if up then
            self.size = self.size + self.size * 0.2 + 2
        else
            self.size = self.size - self.size * 0.2 - 2
        end
        self.size = math.min(1000, self.size)
        self.size = math.max(20, self.size)
        return true
    end
end

function TerrainChangeTextureState:DrawPen(x, z)
    if penShader then gl.UseShader(penShader) end

    local mapPoints = {x,z,x,z+2*self.size, x+2*self.size,z+2*self.size, x+2*self.size,z}
    gl.DepthTest(false)
    if penTexture and type(penTexture)=="string" then

        local ptX,ptZ = 1024 ,1024

        gl.Texture(0,penTexture)
        gl.Texture(1,self.paintTexture)
        gl.Texture(2,penTexture)
        gl.BeginEnd(GL.POLYGON --GL.QUADS
        ,function()

            gl.MultiTexCoord(0, 0,0)  
            gl.MultiTexCoord(1, mapPoints[1]/ptX,mapPoints[2]/ptZ)
            gl.MultiTexCoord(2, mapPoints[1]/ptX,mapPoints[2]/ptZ)
            gl.Vertex(mapPoints[1],Spring.GetGroundHeight(mapPoints[1],mapPoints[2]), mapPoints[2])

            gl.MultiTexCoord(0, 0,1)  
            gl.MultiTexCoord(1, mapPoints[3]/ptX,mapPoints[4]/ptZ) 
            gl.MultiTexCoord(2, mapPoints[3]/ptX,mapPoints[4]/ptZ) 
            gl.Vertex(mapPoints[3],Spring.GetGroundHeight(mapPoints[3],mapPoints[4]), mapPoints[4]) 

            gl.MultiTexCoord(0, 1,1)  
            gl.MultiTexCoord(1, mapPoints[5]/ptX,mapPoints[6]/ptZ)
            gl.MultiTexCoord(2, mapPoints[5]/ptX,mapPoints[6]/ptZ)
            gl.Vertex(mapPoints[5],Spring.GetGroundHeight(mapPoints[5],mapPoints[6]), mapPoints[6]) 

            gl.MultiTexCoord(0, 1,0)
            gl.MultiTexCoord(1, mapPoints[7]/ptX,mapPoints[8]/ptZ)
            gl.MultiTexCoord(2, mapPoints[7]/ptX,mapPoints[8]/ptZ)
            gl.Vertex(mapPoints[7],Spring.GetGroundHeight(mapPoints[7],mapPoints[8]), mapPoints[8])

        end
        )
        gl.Texture(0,false)
        gl.Texture(1,false)
        gl.Texture(2,false)
        local errors = gl.GetShaderLog(penShader)
        if errors ~= "" then
            Spring.Echo(errors)
        end
    end
    gl.UseShader(0)

    gl.DepthTest(true)
end

function TerrainChangeTextureState:DrawWorld()
    x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local x, z = coords[1], coords[3]
        gl.PushMatrix()
        gl.Color(0, 1, 0, 0.3)
        self:DrawPen(x-self.size, z-self.size)
        --gl.Utilities.DrawGroundCircle(x, z, self.size)
        gl.PopMatrix()
    end
end
