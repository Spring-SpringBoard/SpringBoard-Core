ShaderPanel = AbstractMainWindowPanel:extends{}

function ShaderPanel:init()
    self:super("init")
    self.control:AddChild(TabbedPanelButton({
        tooltip = "Map shader editor",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_height.png" }),
            TabbedPanelLabel({ caption = "Map" }),
        },
        OnClick = {
            function()
                nodeEditor = NodeEditor()
                nodeEditor:Create()
            end
        }
    }))
    self.control:AddChild(TabbedPanelButton({
        tooltip = "Unit shader editor",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "unit.png" }),
            TabbedPanelLabel({ caption = "Unit"}),
        },
        OnClick = {
            function()
                Spring.Echo("Unit shader editor")
            end
        }
    }))
    self.control:AddChild(TabbedPanelButton({
        tooltip = "UI shader editor",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "format-text-bold.png" }),
            TabbedPanelLabel({ caption = "UI"}),
        },
        OnClick = {
            function()
                Spring.Echo("UI shader editor")
                uiEditor = UIEditor()
                uiEditor:Create()
            end
        }
    }))
end

UIEditor = LCS.class{}

function UIEditor:Create()
    self.workPanel = Control:New {
        x = 0,
        y = 0,
        width = 2048,
        height = 2048,
    }
    self.mainWindow = Window:New {
        x = "20%",
        y = "20%",
        right = "40%",
        bottom = "20%",
        parent = screen0,
        caption = "",
        resizable = false,
        draggable = true,
        padding = {5, 0, 0, 0},
        children = {
            ScrollPanel:New {
                x = 5,
                right = 150,
                y = 50,
                bottom = 10,
                children = {
                    self.workPanel,
                }
            },
        },
    }
end

NodeEditor = LCS.class{}

function NodeEditor:Create()
    self.nodes = {}
    self.nodeViews = {}
    self._nodeID = 0
    self:LoadAllNodeClasses()

    local nodeClassCtrls = {}
    for nodeName, nodeClass in pairs(self.nodeClasses) do
        local nodeClassCtrl
        nodeClassCtrl= Button:New {
            caption = nodeClass.title,
            OnMouseDown = {function()
                _, nodeView = self:AddNode(self:NewNode(nodeName))
                nodeClassCtrl._addingCtrl = nodeView

                local ax, ay = nodeView:CorrectlyImplementedLocalToScreen(nodeView.x, nodeView.y)
                local cx, cy = nodeClassCtrl:CorrectlyImplementedLocalToScreen(nodeClassCtrl.x, nodeClassCtrl.y)
                local dx, dy = cx - ax, cy - ay
                nodeView:SetPos(nodeView.x + dx, nodeView.y + dy)

                local mx, my = Spring.GetMouseState()

                nodeClassCtrl.dx = nodeView.x - mx
                nodeClassCtrl.dy = nodeView.y + my
            end},
            OnMouseMove = {function(obj)
                local mx, my = Spring.GetMouseState()
                if nodeClassCtrl._addingCtrl then
                    nodeClassCtrl._addingCtrl:SetPos(mx + nodeClassCtrl.dx, nodeClassCtrl.dy - my)
                    --nodeClassCtrl._addingCtrl:SetPos(nodeClassCtrl._addingCtrl:ScreenToLocal(math.floor(mx), math.floor(-my)))
                end
            end},
            OnMouseUp = {function()
                nodeClassCtrl._addingCtrl = nil
            end},
        }
        table.insert(nodeClassCtrls, nodeClassCtrl)
    end

    self.workPanel = Control:New {
        x = 0,
        y = 0,
        width = 2048,
        height = 2048,
    }
    self.mainWindow = Window:New {
        x = "20%",
		y = "20%",
        right = "40%",
        bottom = "20%",
		parent = screen0,
		caption = "Map shader editor",
		resizable = false,
		draggable = true,
		padding = {5, 0, 0, 0},
		children = {
            ScrollPanel:New {
                x = 5,
                right = 150,
                y = 50,
                bottom = 10,
                children = {
                    self.workPanel,
                }
            },
            ScrollPanel:New {
                right = 10,
                width = 150,
                y = 50,
                bottom = 10,
                children = {
                    StackPanel:New {
                        children = nodeClassCtrls,
                        x = 0,
                        y = 0,
                        width = "100%",
                        height = "100%",
                    },
                },
            }
        },
    }

    self.mainNode = self:AddNode(self:NewNode("main"))
end

function NodeEditor:NewNode(nodeClassName)
    local nodeClass = self.nodeClasses[nodeClassName]
    nodeInstance = SCEN_EDIT.deepcopy(nodeClass)
    return nodeInstance
end

function NodeEditor:AddNode(node)
    node = node or {}
    self._nodeID = self._nodeID + 1
    node.id = self._nodeID
    self.nodes[self._nodeID] = node
    if not node.title then
        node.title = "Node: " .. tostring(node.id)
    end
    if not node.fields then
        node.fields = {}
    end
    local nodeView = self:AddNodeView(node)
    self:Update()
    return node, nodeView
end

-- Links field fOutput -> fInput
function NodeEditor:Link(fOutput, fInput)
    -- something already links to fInput, remove it
    if fInput.link then
        table.remove(fInput.link, fInput)
    end

    fOutput.links = fInput.links or {}
    table.insert(fOutput.links, fInput)
    fInput.link = fOutput
end

function NodeEditor:AddNodeView(node)
    local fieldCtrls = {}
    local i = 0
    for fieldName, field in pairs(node.fields) do
        local fieldCtrl = Button:New {
            caption = field.title or fieldName,
            y = i * 35 + 10,
            height = 30,
            OnClick = {function()
                if field.output then
                end
                if self.fOutput then
                    self.CanLink(fOutput, field)
                    self:Link(fOutput, field)
                else
                    self.fOutput = field
                end
            end}
        }
        table.insert(fieldCtrls, fieldCtrl)
        i = i + 1
    end
    local nodeView = Window:New {
        caption = node.title,
        x = 50,
        y = 50,
        minWidth = 100,
        minHeight = 100,
        draggable = true,
        resizable = false,
        autosize = true,
        children = fieldCtrls,
    }
    self.workPanel:AddChild(nodeView)
    return nodeView
end

function NodeEditor:Update()
    local vertexShader = [[
        #define SMF_TEXSQR_SIZE 1024.0
        uniform ivec2 texSquare;
        varying vec2 texCoords;

        void main(void) {
            texCoords = (floor(gl_Vertex.xz) / SMF_TEXSQR_SIZE) - vec2(texSquare);

            gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
        }
    ]]
    shader = gl.CreateShader({
        vertex = vertexShader,

        fragment = [[
            uniform sampler2D texSampler;
            varying vec2 texCoords;
            void main(void) {
                gl_FragColor = texture2D(texSampler, texCoords);
            }
        ]],

        uniformInt = {
            texSampler = 0,
        },
    })

    local errors = gl.GetShaderLog(shader)
    if errors ~= "" then
        Spring.Log("MapShaders", LOG.ERROR, errors)
        Spring.SetMapShader(0, 0)
    else
        Spring.SetMapShader(shader, 0)
    end
end

function NodeEditor:LoadAllNodeClasses()
    self.nodeClasses = {
        main = {
            title = "Map",
            fields = {
                position = {
                    type = "vec4",
                },
                color = {
                    type = "vec4",
                },
            },
        },
        texture2D = {
            title = "Texture 2D",
            fields = {
                sampler2D = {
                    type = "sampler2D"
                },
                color = {
                    type = "vec4",
                    output = true,
                },
                r = {
                    type = "float",
                    output = true,
                },
                g = {
                    type = "float",
                    output = true,
                },
                b = {
                    type = "float",
                    output = true,
                },
                a = {
                    type = "float",
                    output = true,
                }
            }
        },
        -- arithmetic
        add = {
            title = "Add",
            fields = {
                x = {
                    type = "number"
                },
                y = {
                    type = "number"
                },
                output = {
                    type = "number",
                    output = true,
                },
            },
            shader = {
                "$3 = $1 + $2;"
            }
        }
    }
    for nodeName, nodeClasses in pairs(self.nodeClasses) do
        nodeClasses.name = nodeName
        if not nodeClasses.title then
            nodeClasses.title = nodeClasses.name
        end
    end
end
