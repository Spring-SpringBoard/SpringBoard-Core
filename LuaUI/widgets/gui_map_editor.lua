--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:GetInfo()
    return {
        name      = "Map Editor",
        version   = 0.9,
        desc      = "Map Drawing Widget(Chili)",
        author    = "Pako",
        date      = "2012.05.24 - 2012.08.07",
        license   = "GNU GPL, v2 or later",
        layer     = 100000,
        enabled   = false
    }
end

--NOTE to edit specular or detail ditribution textures etc. you need a small hacky patch and map definition needs some references to enable the textures
--NOTE select a painting texture by double clickin with right mouse button--(you can easily "update" the texture mode(linear,nearest,etc.) just by dblcking again )
--TODO BUG if the painting texture is empty it is mostly white but there is some crap in there

--TODO
--fix out of map drawing (drawing on edge)
--eraser and clone tool--clone works easily within the same texture?-some GL doc said no...but seems to work fine with my nvidia
--erasing to original texture always needs to get the original map textures which seems to be randomly bugged

--make trackbars show the value and double clicking opens an editbox to set it raw(even outside the scale)

--myMapfilename(use as the folder) editbox, import export --import is fairly easy
--color picker grid--clicking the big square in current color picker shows a grid window
--include blueprint and editor to edit the values(partially edit in realtime with /commands?)
--change editing mode and blend mode to lists

--TODO BUG everything seems randomly inverted or mirrored
--TODO some indentation? do it by compruter, human is not and indentation machine and Python is for redards

--TODO figure out how to generate the map file and do a little help button&textbox which contains the instructions

local gl = gl
local max = math.max
local floor = math.floor
local min = math.min


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local BIG_TEX_SIZE = 128*8 --bigTexSize      = (SQUARE_SIZE * bigSquareSize);
local SPECULAR_TEX_SIZE = 1024
local TEXS_X = math.floor(Game.mapSizeX/BIG_TEX_SIZE)
local TEXS_Z = math.floor(Game.mapSizeZ/BIG_TEX_SIZE)



local mainDir = 'mapEditor/'

local myTex
local mapTexSQ

local mapFBOtextures = {}

local modifiedFBOtextures = {} --only for faster exporting

local myTexShader

local windowImageList
local windowSettingList
local colorBars
local penStepCtrl
local zoomCtrl

local penStep = 100
local penTimeStep = 0.3 --should be more than mouse click duration?-
local projectPen = false
local penZoom = 1.0
local texturePaintZoom = 1.0
local texturePaintOffsetX,texturePaintOffsetZ = 0,0 --BUG ged?

local showPen = true

--FIXME: remove this default pen
local penTexture = "bitmaps/spacer.bmp"
--FIXME: remove this default texture
local paintTexture = false --always set to false or to empty texture (why?)
paintTexture = "bitmaps/grass3.jpg"

local eraser = false --erasing mode

local overTex

local exportNOW = false


local specularEditing = false -- -1 to -5
local editingLayers = { 
    ["Map Texture"] = false, 
    ["SpecularTexture"] = -1,
    ["skyReflectModTex"] = -2,
    ["detailNormalTex"] = -3,
    ["lightEmissionTex"] = -4,
    ["parallaxHeightTex"] = -5,
    ["splatDetailTex"] = -6,
    ["splatDistrTex"] = -7,
}
local mapSpecularTextures = {}


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
--(Blend.*) = (.*;)
--["\1"] = [[\2]],

local shaderFragStr = [[					

uniform sampler2D mapTex;
uniform sampler2D penTex;
uniform sampler2D paintTex;

vec4 mix(vec4 penColor, vec4 mapColor,float alpha) {
    return vec4(penColor.rgb*alpha + mapColor.rgb*(1.0-alpha), 1.0);
}

void main(void)
{
    vec4 mapColor = texture2D(mapTex,gl_TexCoord[0].st);
    vec4 penColor = texture2D(penTex,gl_TexCoord[1].st);
    vec4 texColor = texture2D(paintTex,gl_TexCoord[2].st);

    penColor = (gl_Color*penColor*texColor);

    vec4 color = %s  //mix(penColor,mapColor,penColor.a);
    //color.a = 1.0; //??

    gl_FragColor = color;
}
]]

local shaderTemplate = {
    fragment =
    string.format(shaderFragStr,penBlenders["BlendNormal"]),
    uniformInt = {
        mapTex = 0,
        penTex = 1,
        paintTex = 2,
    },
}

function widget:Initialize()


    Spring.CreateDir(mainDir)


    local Chili = WG.Chili
    local screen0 = Chili.Screen0

    local Image = Chili.Image
    local Button = Chili.Button
    local Label = Chili.Label


    windowImageList = Chili.Window:New{
        x = 0,
        y = "40%",
        width = (64+10)*3, --"15%",
        height = "60%",
        parent = screen0,
    }

    local imgC = {}
    for k,v in pairs {
        ['n'] = "nearest",
        ['l'] = "linear",
        ['a'] = "aniso",
        ['i'] = "invert",
        ['g'] = "greyed",
        ['c'] = "clamped",
        ['b'] = "border",} do
        imgC[#imgC+1] = 		    Chili.Checkbox:New{
            caption=v,
            checked = false,
            textureLTset = false,
            OnChange = { function(self, checked)
                self.textureLTset = checked and k
            end }}
        end

        Chili.StackPanel:New{
            x=0,y="80%",
            width = "100%",
            height = "20%",
            parent = windowImageList,
            children = imgC}

            local function GetParentDir(dir)
                dir = dir:gsub("\\", "/")
                local lastChar = dir:sub(-1)
                if (lastChar == "/") then
                    dir = dir:sub(1,-2)
                end
                local pos,b,e,match,init,n = 1,1,1,1,0,0
                repeat
                    pos,init,n = b,init+1,n+1
                    b,init,match = dir:find("/",init,true)
                until (not b)
                if (n==1) then
                    return ''
                else
                    return dir:sub(1,pos)
                end
            end

            Chili.ScrollPanel:New{
                width = "100%",
                height = "80%",
                --anchors = {top=true,left=true,bottom=true,right=true},
                parent = windowImageList,  
                children =    {Chili.ImageListView:New{
                    name = "MyStencilListView",
                    width = "100%",
                    height = "100%",
                    columns = 6,
                    --      anchors = {top=true,left=true,bottom=true,right=true},
                    --dir = mainDir,
                    --dir = "LuaUI/Images/",
                    dir = "bitmaps/",
                    OnSelectItem = {
                        function(obj,itemIdx,selected)
                            --Spring.Echo("image selected ",itemIdx,selected, obj.children[itemIdx] and obj.children[itemIdx].file)
                        end,
                    },
                    OnDblClickItem = {
                        function(obj,itemPath,_,button)
                            local prefix
                            for _,v in pairs(imgC) do
                                if v.textureLTset then
                                    prefix = prefix and prefix..(v.textureLTset) or ":"..(v.textureLTset)
                                end
                            end
                            prefix = prefix and prefix..":" or ""
                            if button == 1 then
                                Spring.Echo("Pen selected",itemPath)
                                penTexture =  prefix.. tostring(itemPath)
                            elseif button == 3 then
                                Spring.Echo("Texture selected",itemPath)
                                paintTexture =  prefix.. tostring(itemPath)
                                eraser = false
                            end
                        end,
                    },
                    MouseDblClick = function(self,x,y,button)
                        local cx,cy = self:LocalToClient(x,y)
                        local itemIdx = self:GetItemIndexAt(cx,cy)

                        if (itemIdx<0) then return end

                        if (itemIdx==1) then
                            self:SetDir(GetParentDir(self.dir))
                            return self
                        end

                        if (itemIdx<=self._dirsNum+1) then
                            self:SetDir(self._dirList[itemIdx-1])
                            return self
                        else
                            self:CallListeners(self.OnDblClickItem, self.items[itemIdx], itemIdx, button)
                            return self
                        end
                    end,
                }},
                --Button:New{width = 410, height = 400, anchors = {top=true,left=true,bottom=true,right=true}},

            }
            colorBars = Chili.Colorbars:New{
                --x     = "100%",
                --y     = "100%",
                width = "100%",
                height = 80,
            }

            penStepCtrl = Chili.Trackbar:New{
                width = "100%",
                height=30,
                value = 10,
                trackColor = {1,1,0,1},
                min=0,
                max=100,
                step= 1,
                tooltip="Pen stepping (seconds/100 and pixels)",
                OnChange = {function(self,value)
                    penStep = value
                    penTimeStep = value/100
                end,
            }				}
            zoomCtrl = Chili.Trackbar:New{
                width = "100%",
                height=30,
                value = 1,
                min=0.1,
                max=100,
                step= 0.1,
                tooltip="Pen Zooming",
                OnChange = {function(self,value)
                    penZoom = value
                end,
            }				}

            local texturePaintScale = 					      Chili.Trackbar:New{
                width = "100%",
                height=30,
                value = 1,
                min=0.01,
                max=10,
                step= 0.01,
                tooltip="Texture painting scale",
                OnChange = {function(self,value)
                    texturePaintZoom = value
                end,
            }				}

            local texturePaintOX = 					      Chili.Trackbar:New{
                width = "100%",
                height=20,
                value = 0,
                min=-1,
                max=1,
                step= 0.01,
                tooltip="Texture painting offset X",
                OnChange = {function(self,value)
                    texturePaintOffsetX = value
                end,
            }				}
            local texturePaintOZ = 					      Chili.Trackbar:New{
                width = "100%",
                height=20,
                value = 0,
                min=-1,
                max=1,
                step= 0.01,
                tooltip="Texture painting offset Z",
                OnChange = {function(self,value)
                    texturePaintOffsetZ = value
                end,
            }				}

            windowSettingList = Chili.Window:New{
                x = windowImageList.width, -- 300,
                y = "40%",
                width = "20%",
                --height = "40%",
                autosize = true,
                parent = screen0,
                children = {Chili.StackPanel:New{
                    width = 250,
                    --height = "100%", 
                    resizeItems = false,
                    centerItems = false,
                    autosize = true,
                    children = {

                        Chili.Button:New{width = "100%",
                        caption=("Editing Mode: ")..'Map texture',
                        editingItr = "Map Texture",
                        tooltip = "Select which texture to edit",
                        OnClick = { function(self)
                            self.editingItr, specularEditing = next(editingLayers, self.editingItr)
                            if self.editingItr == nil then --around
                                self.editingItr, specularEditing = next(editingLayers, self.editingItr)
                            end
                            Spring.Echo(self.editingItr,specularEditing)
                            self._down = false
                            self.state = 'normal'
                            self:SetCaption( ("Editing Mode: ").. tostring(self.editingItr))
                        end },
                    },
                    Chili.Button:New{width = "100%",
                    caption=("Blend shader mode: ").."BlendNormal",
                    editingItr = "BlendNormal",
                    tooltip = "Reconstruct a shader for texture blending",
                    OnClick = { function(self)
                        local shadeString
                        self.editingItr, shadeString = next(penBlenders, self.editingItr)
                        if self.editingItr == nil then --around
                            self.editingItr, shadeString = next(penBlenders, self.editingItr)
                        end
                        shaderTemplate.fragment = string.format(shaderFragStr, shadeString)
                        if penShader then
                            gl.DeleteShader(penShader)
                            penShader = nil
                        end

                        penShader = gl.CreateShader(shaderTemplate)
                        Spring.Echo(self.editingItr,penShader and "shader enabled" or gl.GetShaderLog())

                        self._down = false
                        self.state = 'normal'
                        self:SetCaption( ("Shader blend mode: ").. tostring(self.editingItr))
                    end },
                },Chili.Checkbox:New{width = "100%",
                caption='Show Pen texture',
                checked = true,
                tooltip = "Draw the pen on screen or on map",
                OnChange = { function(self, checked)
                    showPen = checked
                end },},
                Chili.Checkbox:New{width = "100%",
                caption='Project Pen from Screen to Map',
                checked = false,
                tooltip = "Toggle between map and screen projected drawing",
                OnChange = { function(self, checked)
                    projectPen = checked
                end },
            },Chili.Checkbox:New{width = "100%",
            caption='Overlay "specular" texture',
            checked = false,
            tooltip = "Overlay extra texture",
            OnChange = { function(self, checked)
                overTex = checked
            end },
        },
        colorBars,
        penStepCtrl,
        zoomCtrl,
        texturePaintScale,texturePaintOX,texturePaintOZ,
        Chili.Button:New{width = "100%",
        caption="Deselect pen",
        tooltip = "Clear Pen textures and stop drawing on map",
        OnClick = {function() penTexture = nil
            paintTexture = false end},
        },
        Chili.Checkbox:New{width = "100%",
        caption="Eraser pen",
        checked = false,
        tooltip = "Clear to original map texture",
        OnChange = {function(self, checked) eraser = checked; 
            --if eraser then paintTexture = false end 
        end},
    },
    Chili.Button:New{width = "100%",
    caption="Export to png",
    tooltip = "Save all edited squares to disk as .png images",
    OnClick = {function() exportNOW = true end},
},
  }
  }
  }
}




mapTexSQ = gl.CreateTexture(BIG_TEX_SIZE,BIG_TEX_SIZE, {
    border = false,
    min_filter = GL.NEAREST,
    mag_filter = GL.NEAREST,
    wrap_s = GL.CLAMP_TO_EDGE,
    wrap_t = GL.CLAMP_TO_EDGE,
    fbo = false, --????
})

penShader = gl.CreateShader(shaderTemplate)

end


function widget:Shutdown()
    if penShader then
        gl.DeleteShader(penShader)
    end
    if myTex then
        gl.DeleteTexture(myTex)
    end
    for _,v in pairs(mapSpecularTextures) do
        gl.DeleteTexture(v)
    end

    for i,v in pairs(mapFBOtextures) do
        for ii,vv in pairs(v) do
            Spring.SetMapSquareTexture(i, ii, "") --should reset to the original texture
            gl.DeleteTexture(vv)
        end
    end
    if windowImageList then
        windowImageList:Dispose()
        windowImageList = nil
    end
    if windowSettingList then
        windowSettingList:Dispose()
        windowSettingList = nil
    end
end


local function getTexTures(pointsXZ)

    if specularEditing then
        if mapSpecularTextures[specularEditing]==false then
            return {}
        elseif mapSpecularTextures[specularEditing]==nil then --TODO do importing instead --these textures are not compressed so could be even read from map file?
            --[[local OrigSpecularTexture = gl.CreateTexture(SPECULAR_TEX_SIZE,SPECULAR_TEX_SIZE, {
            border = false,
            min_filter = GL.LINEAR,
            mag_filter = GL.LINEAR,
            wrap_s = GL.CLAMP_TO_EDGE,
            wrap_t = GL.CLAMP_TO_EDGE,
            fbo = false,
            })

            if not Spring.GetMapSquareTexture(-1, -1, 0, OrigSpecularTexture) then 
            mapSpecularTexture = false
            glDeleteTexture(OrigSpecularTexture)
            Spring.Echo("ERROR: Getting Specular Texture FAILED")
            return {}
            end
            --]]
            mapSpecularTextures[specularEditing] = gl.CreateTexture(SPECULAR_TEX_SIZE,SPECULAR_TEX_SIZE, {
                border = false,
                min_filter = GL.LINEAR,
                mag_filter = GL.LINEAR,
                wrap_s = GL.CLAMP_TO_EDGE,
                wrap_t = GL.CLAMP_TO_EDGE,
                fbo = true,
            })


            gl.RenderToTexture(mapSpecularTextures[specularEditing],
            function()
                gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,0.5)
                --gl.Texture(OrigSpecularTexture)
                --gl.TexRect(-1,-1, 1, 1,0, 0, 1, 1)
            end)
            --  glDeleteTexture(OrigSpecularTexture)
            local set = "set failed!!!"
            if mapSpecularTextures[specularEditing] and Spring.SetMapSquareTexture(specularEditing,specularEditing,mapSpecularTextures[specularEditing]) then set = nil end
            Spring.Echo("Created Specular mapTexture ID: ", tostring(mapSpecularTextures[specularEditing]), set)
        end

        return {[pointsXZ[1]]={[pointsXZ[2]]=mapSpecularTextures[specularEditing]}} --RETURN specular

    end

    local minX,minZ = math.huge, math.huge
    local maxX,maxZ = 0, 0

    for i=1,#pointsXZ,2 do
        --Spring.Echo(pointsXZ[i],pointsXZ[i+1])
        if pointsXZ[i] < minX then minX = pointsXZ[i] end
        if pointsXZ[i] > maxX then maxX = pointsXZ[i] end
        if pointsXZ[i+1] < minZ then minZ = pointsXZ[i+1] end
        if pointsXZ[i+1] > maxZ then maxZ = pointsXZ[i+1] end
    end
    minX,minZ = max(0,floor(minX/BIG_TEX_SIZE)),max(0,floor(minZ/BIG_TEX_SIZE))
    maxX,maxZ = min(TEXS_X,floor(maxX/BIG_TEX_SIZE)),min(TEXS_X,floor(maxZ/BIG_TEX_SIZE))

    local squares = {}

    for ix=minX,maxX,1 do
        for iz=minZ,maxZ,1 do
            squares[#squares+1] = {ix,iz}
        end
    end

    local retMap = {} --[offsetX][offsetZ] = texID

    for _,v in ipairs(squares) do

        local sqTex = mapFBOtextures[v[1]] and mapFBOtextures[v[1]][v[2]]
        if not sqTex then
            if not mapFBOtextures[v[1]] then mapFBOtextures[v[1]] = {} end
            sqTex = gl.CreateTexture(BIG_TEX_SIZE,BIG_TEX_SIZE, {
                border = false,
                --min_filter = GL.NEAREST,
                --mag_filter = GL.NEAREST,
                min_filter = GL.LINEAR,
                mag_filter = GL.LINEAR,
                --target     =  GL_TEXTURE_2D
                --wrap_s = GL.CLAMP,
                --wrap_t = GL.CLAMP,
                wrap_s = GL.CLAMP_TO_EDGE,
                wrap_t = GL.CLAMP_TO_EDGE,
                fbo = true,
            })
            Spring.GetMapSquareTexture(v[1], v[2], 0, mapTexSQ)
            gl.RenderToTexture(sqTex,
            function()
                --gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,1)
                gl.Texture(mapTexSQ)
                gl.TexRect(-1,-1, 1, 1,0, 0, 1, 1)
            end)
            mapFBOtextures[v[1]][v[2]] = sqTex 

            local set = "set failed"
            if sqTex and Spring.SetMapSquareTexture(v[1],v[2],sqTex) then set = "set ok" end
            Spring.Echo("Created mapTexture", v[1],v[2],"ID: ", tostring(sqTex), set)
        end
        if sqTex then
            if not retMap[pointsXZ[1]-v[1]*BIG_TEX_SIZE] then retMap[pointsXZ[1]-v[1]*BIG_TEX_SIZE] = {} end
            if not modifiedFBOtextures[v[1]] then modifiedFBOtextures[v[1]] = {} end
            retMap[pointsXZ[1]-v[1]*BIG_TEX_SIZE][pointsXZ[2]-v[2]*BIG_TEX_SIZE] = sqTex
            modifiedFBOtextures[v[1]][v[2]] = modifiedFBOtextures[v[1]][v[2]] and modifiedFBOtextures[v[1]][v[2]]+1 or 1
        end
    end

    return retMap
end

local function export2png(exportNOW) 
    local dir = mainDir..Game.mapName
    Spring.CreateDir(dir)
    local startx,startz = 0,0
    if type(exportNOW)=="table" then -- don't halt
        startx,startz = exportNOW[1], exportNOW[2]
    end
    for x=startx,TEXS_X-1,1 do
        for z=startz,TEXS_Z-1,1 do
            local tex = mapFBOtextures[x] and mapFBOtextures[x][z]
            if tex and modifiedFBOtextures[x] and modifiedFBOtextures[x][z] then
                local fn = dir.."/"..x.."_"..z.."__".. os.date("%Y%m%d%H") .. string.format("%06d",modifiedFBOtextures[x][z]) ..".png"
                if VFS.FileExists(fn) then --check if no further modifications --every hour a new save even if no modif.
                    Spring.Echo("Not saving an already existing modified square",x,z,modifiedFBOtextures[x][z])
                else
                    Spring.Echo("Saving a modified square to '"..fn.."'")
                    gl.RenderToTexture(tex,gl.SaveImage,0,0,BIG_TEX_SIZE,BIG_TEX_SIZE,fn)
                    exportNOW = {x,z+1}
                    return exportNOW
                end
            else
                local fn = dir.."/"..x.."_"..z.."__0.png"
                if VFS.FileExists(fn) then --check if the original texture already exists
                    Spring.Echo("Not saving already existing unmodified square",x,z)
                else
                    Spring.Echo("Saving an unmodified square to '"..fn.."'")
                    if not Spring.GetMapSquareTexture(x, z, 0, mapTexSQ) then 
                        Spring.Echo("ERROR getting the texture",x,z,"(maybe rezoom and try again later?)")
                    else
                        if not myTex then	     myTex = gl.CreateTexture(BIG_TEX_SIZE,BIG_TEX_SIZE, { --can often fail when saving but no worries it is only the unmodified textures
                            border = false,
                            --min_filter = GL.NEAREST,
                            --mag_filter = GL.NEAREST,
                            min_filter = GL.LINEAR,
                            mag_filter = GL.LINEAR,
                            --target     =  GL_TEXTURE_2D
                            --wrap_s = GL.CLAMP,
                            --wrap_t = GL.CLAMP,
                            wrap_s = GL.CLAMP_TO_EDGE,
                            wrap_t = GL.CLAMP_TO_EDGE,
                            fbo = true,
                        })end
                        if myTex then
                            gl.RenderToTexture(myTex,
                            function()
                                gl.Texture(mapTexSQ)
                                gl.TexRect(-1,-1, 1, 1,0, 0, 1, 1)
                            end)
                            gl.RenderToTexture(myTex,gl.SaveImage,0,0,BIG_TEX_SIZE,BIG_TEX_SIZE,fn)
                            exportNOW = {x,z+1}
                            return exportNOW
                        else Spring.Echo("warning ",x, z,"couldn't be saved")
                        end
                    end
                end
            end
        end
        startz = 0
    end

    for k,v in pairs(mapSpecularTextures) do
        local fn
        for kk,vv in pairs(editingLayers) do
            if k==vv then 
                fn = tostring(kk)
                break
            end
        end
        fn = (dir.."/".. (fn or "wut").. os.date("%Y%m%d%H%S") .. ".png")
        Spring.Echo("Saving ".. tostring(fn) )
        gl.RenderToTexture(v,gl.SaveImage,0,0,SPECULAR_TEX_SIZE,SPECULAR_TEX_SIZE,fn)
    end

    exportNOW = false
    return exportNOW
end

local function drawPen(pointsXZ, textureMap, penTexture)
    local rT

    local texSizeX = specularEditing and Game.mapSizeX or BIG_TEX_SIZE
    local texSizeY = specularEditing and Game.mapSizeZ or BIG_TEX_SIZE

    local color = colorBars.color --{1,1,1,1}

    gl.Texture(1, penTexture)
    gl.Texture(2, paintTexture)
    ptX,ptZ = 0.5/texturePaintZoom,0.5/texturePaintZoom

    if penShader then gl.UseShader(penShader) end

    for x,v in pairs(textureMap) do
        for z,tex in pairs(v) do
            --Spring.Echo("Painting pen at ", x,z,pointsXZ[1],pointsXZ[2],(x+pointsXZ[1])/BIG_TEX_SIZE,"ID: ", tostring(tex))
            --Spring.Echo("Painting pen at ",(x)/BIG_TEX_SIZE, (z)/BIG_TEX_SIZE,"ID: ", tostring(tex))
            --gl.Texture(0, tex)
            if eraser then
                if not Spring.GetMapSquareTexture(x, z, 0, mapTexSQ) then Spring.Echo("Error getting the original texture") end --BUG GED
                gl.Texture(2, mapTexSQ)
                ptX,ptZ = 0.5,0.5
            end
            gl.Texture(0, tex)
            gl.RenderToTexture(tex,
            function()
                --gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,1)
                --gl.Texture(penTexture)
                --gl.Texture(0, penTexture)
                --gl.Texture(2, penTexture)
                --gl.TexRect((x)/BIG_TEX_SIZE*2-1,(z)/BIG_TEX_SIZE*2-1, (x+pointsXZ[5]-pointsXZ[1])/BIG_TEX_SIZE*2-1,(z+pointsXZ[6]-pointsXZ[2])/BIG_TEX_SIZE*2-1,   0, 0, 1, 1)
                local pp = {x+pointsXZ[1],z+pointsXZ[2], x+pointsXZ[3],z+pointsXZ[4],x+pointsXZ[7],z+pointsXZ[8],x+pointsXZ[5],z+pointsXZ[6]}
                local fx,fz = pointsXZ[1],pointsXZ[2]
                for i=1,#pp,2 do
                    pp[i] = (pp[i]-fx)/texSizeX*2-1
                    pp[i+1] = (pp[i+1]-fz)/texSizeY*2-1
                end

                gl.BeginEnd(GL.POLYGON --GL.QUADS
                ,function()
                    color[4] = 0
                    gl.Color(color)
                    gl.MultiTexCoord(1, 0,0)  
                    gl.MultiTexCoord(0, (pp[1]+1)/2,(pp[2]+1)/2)
                    gl.MultiTexCoord(2, (pp[1]+1)*ptX+texturePaintOffsetX,(pp[2]+1)*ptZ+texturePaintOffsetZ)
                    gl.Vertex(pp[1], pp[2])

                    color[4] = 1
                    gl.Color(color)
                    gl.MultiTexCoord(1, 0,1)  
                    gl.MultiTexCoord(0, (pp[3]+1)/2,(pp[4]+1)/2) 
                    gl.MultiTexCoord(2, (pp[3]+1)*ptX+texturePaintOffsetX,(pp[4]+1)*ptZ+texturePaintOffsetZ)
                    gl.Vertex(pp[3], pp[4]) 

                    color[4] = 0
                    gl.Color(color)
                    gl.MultiTexCoord(1, 1,1)  
                    gl.MultiTexCoord(0, (pp[7]+1)/2,(pp[8]+1)/2)
                    gl.MultiTexCoord(2, (pp[7]+1)*ptX+texturePaintOffsetX,(pp[8]+1)*ptZ+texturePaintOffsetZ)
                    gl.Vertex(pp[7], pp[8]) 

                    color[4] = 0
                    gl.Color(color)
                    gl.MultiTexCoord(1, 1,0)  
                    gl.MultiTexCoord(0, (pp[5]+1)/2,(pp[6]+1)/2)
                    gl.MultiTexCoord(2, (pp[5]+1)*ptX+texturePaintOffsetX,(pp[6]+1)*ptZ+texturePaintOffsetZ)
                    gl.Vertex(pp[5], pp[6])

                end
                )
            end)
            rT = tex
        end
    end

    gl.UseShader(0)

    return rT
end


local buttonPressed = false

local tx

local previousDrawMY, previousDrawMX, previousTime = 0,0,0
local mapPoints = {0,0,0,0,0,0,0,0}

function widget:DrawWorld()
    gl.DepthTest(false)
    if (not projectPen) and (not buttonPressed) and penTexture and type(penTexture)=="string" then
        if showPen then
            local color = colorBars.color

            local ptX,ptZ = 1024*texturePaintZoom    ,1024*texturePaintZoom     

            gl.Texture(0,penTexture)
            gl.Texture(1,paintTexture)
            gl.BeginEnd(GL.POLYGON --GL.QUADS
            ,function()

                gl.Color(color)
                gl.MultiTexCoord(0, 0,0)  
                gl.MultiTexCoord(1, mapPoints[1]/ptX+texturePaintOffsetX,mapPoints[2]/ptZ+texturePaintOffsetZ)
                gl.Vertex(mapPoints[1],Spring.GetGroundHeight(mapPoints[1],mapPoints[2]), mapPoints[2])

                gl.MultiTexCoord(0, 0,1)  
                gl.MultiTexCoord(1, mapPoints[3]/ptX+texturePaintOffsetX,mapPoints[4]/ptZ+texturePaintOffsetZ) 
                gl.Vertex(mapPoints[3],Spring.GetGroundHeight(mapPoints[3],mapPoints[4]), mapPoints[4]) 

                gl.MultiTexCoord(0, 1,1)  
                gl.MultiTexCoord(1, mapPoints[5]/ptX+texturePaintOffsetX,mapPoints[6]/ptZ+texturePaintOffsetZ)
                gl.Vertex(mapPoints[5],Spring.GetGroundHeight(mapPoints[5],mapPoints[6]), mapPoints[6]) 

                gl.MultiTexCoord(0, 1,0)
                gl.MultiTexCoord(1, mapPoints[7]/ptX+texturePaintOffsetX,mapPoints[8]/ptZ+texturePaintOffsetZ)
                gl.Vertex(mapPoints[7],Spring.GetGroundHeight(mapPoints[7],mapPoints[8]), mapPoints[8])

            end
            )
            gl.Texture(0,false)
            gl.Texture(1,false)
        end
        gl.Color(1,1,1,1)
        if overTex and specularEditing and mapSpecularTextures[specularEditing] then
            gl.Texture(mapSpecularTextures[specularEditing])
            gl.DrawGroundQuad(0,0,Game.mapSizeX,Game.mapSizeZ,false,true)
        end

        gl.Texture(false)
        gl.DepthTest(true)
    end
end
local lm,mm,rm
function widget:MousePress(x, y, button)
    Spring.Echo(penTexture)
    if penTexture and button == 1 then
        lm = true
        return true
    end
    return false
end

function widget:MouseRelease(x, y, button)
    if button == 1 then
        lm = false
    end
end

function widget:MouseMove(x, y, dx, dy, button)

end

function widget:DrawScreen()

    gl.Color(1,1,1,1)

    if exportNOW then exportNOW = export2png(exportNOW) end
    --[[ gl.Texture(myTex)

    local ss = gl.TextureInfo(myTex)
    --gl.Billboard()
    gl.TexRect(50,60, 50 + ss.xsize,60+ss.ysize)

    gl.Texture(false)
    --]]
    if penTexture and type(penTexture)=="string" then

        gl.Color(1,1,1,1)
        gl.Texture(penTexture)--needed for caching the texture info..
        --local mxo,myo, lm,mm,rm = Spring.GetMouseState()
        local mxo,myo = Spring.GetMouseState()
        local ss = gl.TextureInfo(penTexture)
        local mx,my = mxo,myo
        if projectPen then
            mx,my = math.floor(mxo-ss.xsize/2*penZoom), math.floor(myo-ss.ysize/2*penZoom)
        end
        mapPoints = {mx,my, mx,my+ss.ysize*penZoom, mx+ss.xsize*penZoom,my+ss.ysize*penZoom, mx+ss.xsize*penZoom,my}
        for i=1,#mapPoints,2 do
            if (not projectPen) and i ~= 1 then
                mapPoints[1] = mapPoints[1]-ss.xsize*penZoom*0.5
                mapPoints[2] = mapPoints[2]+ss.ysize*penZoom*0.5
                mapPoints[3] = mapPoints[1]
                mapPoints[4] = mapPoints[2]-ss.ysize*penZoom
                mapPoints[5] = mapPoints[1]+ss.xsize*penZoom
                mapPoints[6] = mapPoints[2]-ss.ysize*penZoom
                mapPoints[7] = mapPoints[1]+ss.xsize*penZoom
                mapPoints[8] = mapPoints[2]
                break
            else
                local _,xyz = Spring.TraceScreenRay(mapPoints[i],mapPoints[i+1], true,false,true)
                if xyz then
                    mapPoints[i] = xyz[1]
                    mapPoints[i+1] = xyz[3]
                end
            end
        end

        --gl.Billboard()

        --REM
        --[[
        if tx then --show the last edited texture in screenspace
        gl.Texture(tx)
        local ss = gl.TextureInfo(tx)
        --gl.Billboard()
        gl.TexRect(50,60, 50 + ss.xsize,60+ss.ysize)
        gl.Texture(false)
        end--]]
        --REMOVE

        --REMOVE
        --[[
        gl.RenderToTexture(myTex,
        function()
        gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,1)
        gl.TexRect(-1,-1, 1, 1,0, 0, 1, 1)
        end)--]]
        --REMOVE
        gl.Texture(false)

        if floor(previousDrawMY/penStep) ~= floor(myo/penStep) or floor(previousDrawMX/penStep) ~= floor(mxo/penStep) or previousTime+penTimeStep < widgetHandler:GetHourTimer() then
            buttonPressed = false
            previousDrawMY = myo
            previousDrawMX = mxo
            previousTime = widgetHandler:GetHourTimer()
        end

        if lm and not buttonPressed then
            --Spring.Echo("drawingPen at",mapPoints[1],mapPoints[2])
            buttonPressed = true
            local tmap = getTexTures(mapPoints)
            tx = drawPen(mapPoints, tmap, penTexture)

        else
            if not lm then
                buttonPressed = false
            end
            if projectPen and not buttonPressed and showPen then
                gl.Texture(0,penTexture)
                gl.Texture(1,paintTexture)
                gl.TexRect(mx,my, mx+ss.xsize*penZoom,my+ss.ysize*penZoom) --hides
                gl.Texture(0,false)
                gl.Texture(1,false)
            end
        end
        gl.Texture(false)
    end


end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
