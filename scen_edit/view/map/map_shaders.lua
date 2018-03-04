SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

MapShadersEditor = Editor:extends{}
Editor.Register({
    name = "mapShaders",
    editor = MapShadersEditor,
    tab = "Map",
    caption = "Shaders",
    tooltip = "Edit map shaders",
    image = SB_IMG_DIR .. "globe.png",
    order = 5,
})

function MapShadersEditor:init()
    self:super("init")

    self:AddControl("shader-sep", {
        Label:New {
            caption = "Load shader",
        },
        Line:New {
            x = 150,
        }
    })
    self.btnLoadShader = Button:New ({
        caption = "Load",
        height = 30,
        width = 100,
        OnClick = {
            function()
                self:LoadShader()
            end
        }
    })
    self.btnResetShader = Button:New ({
        caption = "Reset",
        height = 30,
        width = 100,
        OnClick = {
            function()
                Spring.SetMapShader(nil, nil)
            end
        }
    })
    self:AddField(GroupField({
        AssetField({
            name = "shaderFile",
            title = "Shader file:",
            tooltip = "SpringBoard Shader Lua file",
            rootDir = "shaders/",
        }),
        Field({
            name = "btnLoadShader",
            height = 30,
            width = 100,
            components = {
                self.btnLoadShader,
            }
        }),
        Field({
            name = "btnResetShader",
            height = 30,
            width = 100,
            components = {
                self.btnResetShader,
            }
        }),
    }))

    local children = {
        ScrollPanel:New {
            x = 0,
            y = 0,
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        },
    }

    self:Finalize(children)
end

function MapShadersEditor:LoadShader()
    local shaderFile = self.fields["shaderFile"].value
    if not shaderFile or shaderFile == "" then
        return
    end

    self.shaderDef = nil
    local success, msg = pcall(function()
        local envTbl = getfenv()
        envTbl.__path__ = shaderFile
        self.shaderDef = VFS.Include(shaderFile, envTbl)
        Spring.SetMapShader(self.shaderDef.shader, self.shaderDef.shader)
        SB.DrawGroundPreForward = self.shaderDef.DrawGroundPreForward
        SB.DrawWorld = self.shaderDef.DrawWorld
    end)

    if not success then
        Log.Error(msg)
    else
        for name, _ in pairs(self.fields) do
            if name:find("uniform_") or name == "uniform-sep" then
                self:RemoveField(name)
            end
        end

        if self.shaderDef.uniform then
            self:AddControl("uniform-sep", {
                Label:New {
                    caption = "Uniforms",
                },
            })
            for uName, value in pairs(self.shaderDef.uniform) do
                local fieldName = "uniform_" .. uName
                self:AddField(NumericField({
                    name = fieldName,
                    title = uName .. ":",
                    value = value,
                }))
            end
        end

        self.stackPanel:EnableRealign()
        self:_MEGA_HACK()
    end
end

function MapShadersEditor:OnFieldChange(name, value)
    if name:find("uniform_") then
        gl.ActiveShader(self.shaderDef.shader, function()
            -- slow/ugly
            local nameID = gl.GetUniformLocation(self.shaderDef.shader, name:sub(#"uniform_" + 1))
            gl.Uniform(nameID, value)
        end)
    end
end
