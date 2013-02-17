-------------------------

function widget:GetInfo()
  return {
    name      = "Scenario Editor",
    desc      = "Mod-independent scenario editor",
    author    = "gajop",
    date      = "in the future",
    license   = "GPL-v2",
    layer     = 1001,
    enabled   = true,
  }
end

include("keysym.h.lua")
VFS.Include("savetable.lua")

local model
local unitImages

local conditionTypes = {"Unit in area", "Unit attribute", "And conditions", "Or conditions", "Not condition", "Trigger enabled"}
SCEN_EDIT = {}

local function DrawCircle()
    gl.Color(0, 255, 0, 0.2)
    local x, y = gl.GetViewSizes()
    gl.LineWidth(200)
    local parts = 1
    local radius = 200
    local multiplier = radius / parts 
    for i=0, parts do
        gl.DrawGroundCircle(area_x + 500, 50, area_z + 500, radius - i * multiplier, 20)
    end
end


local function AddRectButton()
    SCEN_EDIT.stateManager:SetState(AddRectState())
end

function SelectArea(returnButton)
    SCEN_EDIT.stateManager:SetState(SelectAreaState(returnButton))
end

function SelectUnit(returnButton)
    SCEN_EDIT.stateManager:SetState(SelectUnitState(returnButton))
end

function SelectType(returnButton)
    SCEN_EDIT.stateManager:SetState(SelectUnitTypeState(returnButton))
end

function MakeRadioButtonGroup(checkBoxes)
    for i = 1, #checkBoxes do
        local checkBox = checkBoxes[i]
        table.insert(checkBox.OnChange,
            function(cbToggled, checked)
                if checked then
                    for j = 1, #checkBoxes do
                        if i ~= j then
                            local cb = checkBoxes[j]
                            if cb.checked then
                                cb:Toggle()
                            end
                        end
                    end
                end
            end
        )
    end
end

function MakeSeparator(panel)
    local lblSeparator = Label:New {
        parent = panel,
        height = model.B_HEIGHT + 10,
        caption = "===================================",
        align = 'center',
    }
    return lblSeparator
end

function MakeAddEventWindow(trigger, triggerWindow)
    local newEventWindow = EventWindow:New {
 		parent = screen0,
 		model = model,
		trigger = trigger,
		triggerWindow = triggerWindow,
		mode = 'add',
    }
end

function MakeEditEventWindow(trigger, triggerWindow, event)
    local newEventWindow = EventWindow:New {
 		parent = screen0,
 		model = model,
		trigger = trigger,
		triggerWindow = triggerWindow,
		mode = 'edit',
		event = event,
    }
end

function MakeRemoveEventWindow(trigger, triggerWindow, event, idx)
    table.remove(trigger.events, idx)
    triggerWindow:Populate()
end

local function AddCondition(trigger, triggerWindow, condition)
    table.insert(trigger.conditions, condition)
    triggerWindow:Populate()
end

local function EditCondition(trigger, triggerWindow)
    triggerWindow:Populate()
end

function MakeAddConditionWindow(trigger, triggerWindow)
    local newActionWindow = ConditionWindow:New {
 		parent = screen0,
		trigger = trigger,
		triggerWindow = triggerWindow,
		mode = 'add',
    }
end

function MakeEditConditionWindow(trigger, triggerWindow, condition)
    local newActionWindow = ConditionWindow:New {
 		parent = screen0,	
		trigger = trigger,
		triggerWindow = triggerWindow,
		mode = 'edit',
		condition = condition,
    }
end

function MakeRemoveConditionWindow(trigger, triggerWindow, condition, idx)
    table.remove(trigger.conditions, idx)
    triggerWindow:Populate()
end

function MakeAddEventWindow(trigger, triggerWindow)
    local newEventWindow = EventWindow:New {
 		parent = screen0,
 		model = model,
		trigger = trigger,
		triggerWindow = triggerWindow,
		mode = 'add',
    }
end

function MakeAddActionWindow(trigger, triggerWindow)
    local newActionWindow = ActionWindow:New {
 		parent = screen0,
		trigger = trigger,
		triggerWindow = triggerWindow,
		mode = 'add',
    }
end

function MakeEditActionWindow(trigger, triggerWindow, action)
    local newActionWindow = ActionWindow:New {
 		parent = screen0,
		trigger = trigger,
		triggerWindow = triggerWindow,
		mode = 'edit',
		action = action,
    }
end

function MakeRemoveActionWindow(trigger, triggerWindow, action, idx)
    table.remove(trigger.actions, idx)
    triggerWindow:Populate()
end

local function CreateTerrainEditor()
    succ, msg = pcall(TerrainEditorView)
    if not succ then
        Spring.Echo(msg)
    end
end

local function CreateUnitDefsView()
	if unitImages then
		return
	end
    unitImages = UnitDefsView:New {
		name='units',
		x = 0,
		right = 20,
		OnSelectItem = {
			function(obj,itemIdx,selected)
				if selected and itemIdx > 0 then
                    local currentState = SCEN_EDIT.stateManager:GetCurrentState()
					if currentState:is_A(SelectUnitTypeState) then
						local selUnitDef = unitImages.items[itemIdx].id
                        currentState:SelectUnitType(selUnitDef)
                        unitImages:SelectItem(0)
					else
						local selUnitDef = unitImages.items[itemIdx].id
                        SCEN_EDIT.stateManager:SetState(AddUnitState(selUnitDef, unitImages.teamId, unitImages))
					end
				end
			end,
		},
	}
    local playerNames, playerTeamIds = GetTeams()
    local teamsCmb = ComboBox:New {
        bottom = 1,
        height = model.B_HEIGHT,
        items = playerNames,
        playerTeamIds = playerTeamIds,
        x = 100,
        width=120,
    }
    teamsCmb.OnSelect = {
        function (obj, itemIdx, selected) 
            if selected then
                unitImages:SelectTeamId(teamsCmb.playerTeamIds[itemIdx])
                local currentState = SCEN_EDIT.stateManager:GetCurrentState()
                if currentState:is_A(AddUnitState) then
                    currentState.teamId = unitImages.teamId
                end
            end
        end
    }
	unitImages:SelectTeamId(teamsCmb.playerTeamIds[teamsCmb.selected])

    unitsWindow = Window:New {
        parent = screen0,
        caption = "Unit Editor",
        width = 487,
        height = 400,
        resizable = false,
        x = 1400,
        y = 500,
        children = {
            ScrollPanel:New {
                y = 15,
                x = 1,
                right = 1,
                bottom = model.C_HEIGHT * 4,
                --horizontalScrollBar = false,
                children = {
                    unitImages
                },
            },
            Label:New {
                x = 1,
                width = 50,
                bottom = 8 + model.C_HEIGHT * 2,
                caption = "Type:",
            },
            ComboBox:New {
                height = model.B_HEIGHT,
                x = 50,
                bottom = 1 + model.C_HEIGHT * 2,
                items = {
                    "Units", "Buildings", "All",
                },
                width = 80,
                OnSelect = {
                    function (obj, itemIdx, selected) 
                        if selected then
                            unitImages:SelectUnitTypesId(itemIdx)
                        end
                    end
                },
            },
            Label:New {
                caption = "Terrain:",
                x = 140,
                bottom = 8 + model.C_HEIGHT * 2,
                width = 50,
            },
            ComboBox:New {
                bottom = 1 + model.C_HEIGHT * 2,
                height = model.B_HEIGHT,
                items = {
                    "Ground", "Air", "Water", "All",
                },
                x = 200,
                width=80,
                OnSelect = {
                    function (obj, itemIdx, selected) 
                        if selected then
                            unitImages:SelectTerrainId(itemIdx)
                        end
                    end
                },
            },
            Label:New {
                caption = "Player:",
                x = 40,
                bottom = 8,
                width = 50,
            },
            teamsCmb,
        }
    }
end

local function CreateFeatureDefsView()
	if featureImages then
		return
	end
    local ebAmount = EditBox:New {
        text = "1",
        x = 310,
        bottom = 8,
        width = 50,
        OnKeyPress = {
            function(obj, ...)
                local currentState = SCEN_EDIT.stateManager:GetCurrentState()
                if currentState:is_A(AddFeatureState) then
                    currentState.amount = tonumber(obj.text) or 1
                end
            end
        }
    }

    featureImages = FeatureDefsView:New {
		name='features',
		x = 0,
		right = 20,
		OnSelectItem = {
			function(obj,itemIdx,selected)
				if selected and itemIdx > 0 then
                    local currentState = SCEN_EDIT.stateManager:GetCurrentState()
					if currentState:is_A(SelectFeatureTypeState) then
						selFeatureDef = featureImages.items[itemIdx].id
						CallListeners(currentState.btnSelectType.OnSelectFeatureType, selFeatureDef)
                        SCEN_EDIT.stateManager:SetState(DefaultState())
					else
						selFeatureDef = featureImages.items[itemIdx].id
                        SCEN_EDIT.stateManager:SetState(AddFeatureState(selFeatureDef, featureImages.teamId, featureImages, tonumber(ebAmount.text) or 1))
					end
                    local feature = FeatureDefs[selFeatureDef]
				end
			end,
		},
	}
    local playerNames, playerTeamIds = GetTeams()
    local teamsCmb = ComboBox:New {
        bottom = 1,
        height = model.B_HEIGHT,
        items = playerNames,
        playerTeamIds = playerTeamIds,
        x = 100,
        width=120,
    }
    teamsCmb.OnSelect = {
        function (obj, itemIdx, selected) 
            if selected then
                featureImages:SelectTeamId(teamsCmb.playerTeamIds[itemIdx])
                local currentState = SCEN_EDIT.stateManager:GetCurrentState()
                if currentState:is_A(AddFeatureState) then
                    currentState.teamId = featureImages.teamId
                end
            end
        end
    }
	featureImages:SelectTeamId(teamsCmb.playerTeamIds[teamsCmb.selected])

    featuresWindow = Window:New {
        parent = screen0,
        caption = "Feature Editor",
        width = 487,
        height = 400,
        resizable = false,
        x = 1400,
        y = 500,
        children = {
            ScrollPanel:New {
                y = 15,
                x = 1,
                right = 1,
                bottom = model.C_HEIGHT * 4,
                --horizontalScrollBar = false,
                children = {
                    featureImages
                },
            },
            Label:New {
                x = 1,
                width = 50,
                bottom = 8 + model.C_HEIGHT * 2,
                caption = "Type:",
            },
            ComboBox:New {
                height = model.B_HEIGHT,
                x = 50,
                bottom = 1 + model.C_HEIGHT * 2,
                items = {
                    "Wreckage", "Other", "All",
                },
                width = 80,
                OnSelect = {
                    function (obj, itemIdx, selected) 
                        if selected then
                            featureImages:SelectFeatureTypesId(itemIdx)
                        end
                    end
                },
            },
            Label:New {
                x = 140,
                width = 50,
                bottom = 8 + model.C_HEIGHT * 2,
                caption = "Wreck:",
            },
            ComboBox:New {
                height = model.B_HEIGHT,
                x = 190,
                bottom = 1 + model.C_HEIGHT * 2,
                items = {
                    "Units", "Buildings", "All",
                },
                width = 80,
                OnSelect = {
                    function (obj, itemIdx, selected) 
                        if selected then
                            featureImages:SelectUnitTypesId(itemIdx)
                        end
                    end
                },
            },
            Label:New {
                caption = "Terrain:",
                x = 270,
                bottom = 8 + model.C_HEIGHT * 2,
                width = 50,
            },
            ComboBox:New {
                bottom = 1 + model.C_HEIGHT * 2,
                height = model.B_HEIGHT,
                items = {
                    "Ground", "Air", "Water", "All",
                },
                x = 330,
                width=80,
                OnSelect = {
                    function (obj, itemIdx, selected) 
                        if selected then
                            featureImages:SelectTerrainId(itemIdx)
                        end
                    end
                },
            },
            Label:New {
                caption = "Player:",
                x = 40,
                bottom = 8,
                width = 50,
            },
            teamsCmb,
            Label:New {
                caption = "Amount:",
                x = 250, 
                bottom = 8,
                width = 50,
            },
            ebAmount,
        }
    }
end

local function explode(div,str)
  if (div=='') then return false end
  local pos,arr = 0,{}
  -- for each divider found
  for st,sp in function() return string.find(str,div,pos,true) end do
    table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
    pos = sp + 1 -- Jump past current divider
  end
  table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
  return arr
end

function RecieveGadgetMessage(msg)
	pre = "scen_edit"
	local data = explode( '|', msg)
    if data[1] ~= pre then return end
    local op = data[2]

--    Spring.Echo(msg)
    if op == 'sync' then
--        Spring.Echo("Widget synced!")
        local msgTable = loadstring(string.sub(msg, #(pre .. "|sync|") + 1))()
        local msg = Message(msgTable.tag, msgTable.data)
--        table.echo(msg)
        if msg.tag == 'command' then
            local cmd = SCEN_EDIT.resolveCommand(msg.data)
            SCEN_EDIT.commandManager:execute(cmd, true)
        end
        return
    end
	local tbl = loadstring(msg)()
	local data = tbl.data
	local tag = tbl.tag

    if tag == "msg" then
		model:InvokeCallback(data.msgId, data.result)
	end
end

function LoadGUI()
    local btnTriggers = Button:New {
        caption = '',
        height = model.B_HEIGHT + 20,
        width = model.B_HEIGHT + 20,
		tooltip = "Trigger settings",
        children = {
            Image:New {                 
                file=SCEN_EDIT_IMG_DIR .. "applications-system.png", 
                height = model.B_HEIGHT - 2, 
                width = model.B_HEIGHT - 2,
            },
        },
    }
    local btnVariableSettings = Button:New {
        height = model.B_HEIGHT + 20,
        width = model.B_HEIGHT + 20,
        caption = '',
		tooltip = "Variable settings",
        children = {
            Image:New {                 
                file=SCEN_EDIT_IMG_DIR .. "format-text-bold.png", 
                height = model.B_HEIGHT - 2, 
                width = model.B_HEIGHT - 2, 
                margin = {0, 0, 0, 0},
            },
        },
    }


    toolboxWindow = Window:New {
        x = 1000,
        y = 100,
        width = 700,
        height = 100,
        parent = screen0,
        caption = "Scenario Toolbox",
        resizable = false,
        children = {
            StackPanel:New {
                name='stack_main',
                orientation = 'horizontal',
                width = '100%',
                height = '100%',
                padding = {0,0,0,0},
                itemPadding = {0,10,10,10},
                itemMargin = {0,0,0,0},
                resizeItems = false,

                children = {
                    Button:New {
                        height = model.B_HEIGHT + 20,
                        width = model.B_HEIGHT + 20,
                        caption = '',
                        OnClick = {AddRectButton},
						tooltip = "Add a rectangle area", 
                        children = {
                            Image:New {                                 
                                file=SCEN_EDIT_IMG_DIR .. "view-fullscreen.png", 
                                height = model.B_HEIGHT - 2, 
                                width = model.B_HEIGHT - 2, 
                                margin = {0, 0, 0, 0},
                            },
                        },
                    },
                    Button:New {
                        height = model.B_HEIGHT + 20,
                        width = model.B_HEIGHT + 20,
                        caption = '',
						tooltip = "Save scenario", 
                        OnClick = {
							function() 
                                local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
								sfd = SaveFileDialog(dir)
								sfd:setConfirmDialogCallback(function(path)
                                    local saveCommand = SaveCommand(path)
                                    success, errMsg = pcall(function()
                                        SCEN_EDIT.commandManager:execute(saveCommand, true)
                                    end)
                                    if not success then
                                        Spring.Echo(errMsg)
                                    end
                                end)
							end
						},
                        children = {
                            Image:New { 
                                file=SCEN_EDIT_IMG_DIR .. "document-save.png", 
                                height = model.B_HEIGHT - 2, 
                                width = model.B_HEIGHT - 2, 
                                margin = {0, 0, 0, 0},
                            },
                        },
                    },
                    Button:New {
                        height = model.B_HEIGHT + 20,
                        width = model.B_HEIGHT + 20,
                        caption = '',
						tooltip = "Load scenario", 
                        OnClick = {
                            function()
                                local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
								ofd = OpenFileDialog(dir)
                                ofd:setConfirmDialogCallback(function(path)
                                    VFS.MapArchive(path)
                                    local data = VFS.LoadFile("model.lua", VFS.ZIP)
                                    cmd = LoadCommand(data)
                                    SCEN_EDIT.commandManager:execute(cmd)
                                    
                                    local data = VFS.LoadFile("heightmap.data", VFS.ZIP)
                                    loadMap = LoadMap(data)
                                    SCEN_EDIT.commandManager:execute(loadMap)
								end)
                            end
                        },
                        children = {
                            Image:New { 
                                file = SCEN_EDIT_IMG_DIR .. "document-open.png", 
                                height = model.B_HEIGHT - 2, 
                                width = model.B_HEIGHT - 2, 
                                margin = {0, 0, 0, 0},
                            },
                        },
                    },
                    Chili.LayoutPanel:New {
                        height = btnTriggers.height,
                        width = btnTriggers.width,
                        children = {btnTriggers},
                        padding = {0, 0, 0, 0},
                        margin = {0, 0, 0, 0},
                        itemMargin = {0, 0, 0, 0},
                        itemPadding = {0, 0, 0, 0},
                    },
                    Chili.LayoutPanel:New {
                        height = btnVariableSettings.height,
                        width = btnVariableSettings.width,
                        children = {btnVariableSettings},
                        padding = {0, 0, 0, 0},
                        margin = {0, 0, 0, 0},
                        itemMargin = {0, 0, 0, 0},
                        itemPadding = {0, 0, 0, 0},
                    },
					Button:New {
						height = model.B_HEIGHT + 20,
						width = model.B_HEIGHT + 20,
						caption = '',
						tooltip = "Unit type panel",
						OnClick = {
							function()
								CreateUnitDefsView()
							end
						},
						children = {
							Image:New {								
								file = SCEN_EDIT_IMG_DIR .. "face-monkey.png",
								height = model.B_HEIGHT - 2,
								width = model.B_HEIGHT - 2,
								margin = {0, 0, 0, 0},
							},
						},
					},
					Button:New {
						height = model.B_HEIGHT + 20,
						width = model.B_HEIGHT + 20,
						caption = '',
						tooltip = "Feature type panel",
						OnClick = {
							function()
								CreateFeatureDefsView()
							end
						},
						children = {
							Image:New {								
								file = SCEN_EDIT_IMG_DIR .. "face-monkey.png",
								height = model.B_HEIGHT - 2,
								width = model.B_HEIGHT - 2,
								margin = {0, 0, 0, 0},
							},
						},
					},--[[
					Button:New {
						height = model.B_HEIGHT + 20,
						width = model.B_HEIGHT + 20,
						caption = '',
						OnClick = {
							function()
                                Spring.StopSoundStream()
--                                Spring.PlaySoundStream("sounds/environment.ogg")
--                                Spring.PlaySoundFile("sounds/environment.ogg")
--                                Spring.Restart("tb.txt2", "")
--                                local cmd = StartCommand()
--                                SCEN_EDIT.commandManager:execute(cmd)
							end
						},
						children = {
							Image:New {
								tooltip = "Start mission",
								file = SCEN_EDIT_IMG_DIR .. "media-playback-start.png",
								height = model.B_HEIGHT - 2,
								width = model.B_HEIGHT - 2,
								margin = {0, 0, 0, 0},
							},
						},
					},--]]
					Button:New {
						height = model.B_HEIGHT + 20,
						width = model.B_HEIGHT + 20,
						caption = "T-Edit",
						tooltip = "Terrain toolbox",
						OnClick = {
							function()
								CreateTerrainEditor()
							end
						}
					},
                    Button:New {
                        height = model.B_HEIGHT + 20,
						width = model.B_HEIGHT + 20,
						caption = "Compress",
						tooltip = "Compress folder",
						OnClick = {
							function()
                                --VFS.CompressFolder("games/ToolBox.sdd/examples/3lanes")
                                VFS.CompressFolder("games/ToolBox.sdd/examples/3lanes", "zip", "games/ToolBox.sdd/examples/3lanes.sdz", true, VFS.RAW)
                               -- VFS.CompressFolder("games/ToolBox.sdd/examples/3lanes")
							end
						}
                    },
                 }
            }
        }
    }
    btnTriggers.OnClick = {
        function () 
            btnTriggers._toggle = TriggersWindow:New {
                parent = screen0,
                model = model, 
            }
            btnTriggers.parent.disableChildrenHitTest = true
            table.insert(btnTriggers._toggle.OnDispose, 
				function()
                    if btnTriggers and btnTriggers.parent then
                        btnTriggers.parent.disableChildrenHitTest = false
                    end
				end
			)
        end
    }

    btnVariableSettings.OnClick = {
        function()
            btnVariableSettings._toggle = VariableSettingsWindow:New {
                parent = screen0,
                model = model, 
            }
            btnVariableSettings.parent.disableChildrenHitTest = true
            table.insert(btnVariableSettings._toggle.OnDispose, 
				function()
                    if btnVariableSettings and btnVariableSettings.parent then
                        btnVariableSettings.parent.disableChildrenHitTest = false
                    end
				end
			)
        end
    }
end
function widget:Initialize()
	reloadGadgets() --uncomment for development	
    if not WG.Chili then
        widgetHandler:RemoveWidget(widget)
        return
    end
    VFS.Include("scen_edit/exports.lua")
	widgetHandler:RegisterGlobal("RecieveGadgetMessage", RecieveGadgetMessage)
    LCS = loadstring(VFS.LoadFile(LIBS_DIR .. "lcs/LCS.lua"))
    LCS = LCS()
    
    vstruct = require("vstruct")
	VFS.Include(SCEN_EDIT_DIR .. "util.lua")
    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "observable.lua")

	SCEN_EDIT.Include(SCEN_EDIT_DIR .. "display_util.lua")
	SCEN_EDIT.displayUtil = DisplayUtil(true)
	SCEN_EDIT.Include(SCEN_EDIT_DIR .. "model/model.lua")
	model = Model()
	SCEN_EDIT.model = model

    SCEN_EDIT.model.areaManager = AreaManager()
    SCEN_EDIT.model.unitManager = UnitManager(true)
    SCEN_EDIT.model.featureManager = FeatureManager(true)
    SCEN_EDIT.model.variableManager = VariableManager(true)
    SCEN_EDIT.model.triggerManager = TriggerManager(true)

    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "command/command_manager.lua")
    SCEN_EDIT.commandManager = CommandManager()
    SCEN_EDIT.commandManager.widget = true

    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "state/state_manager.lua")
    SCEN_EDIT.stateManager = StateManager()

    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "view/view.lua")
    SCEN_EDIT.view = View()
    
    local viewAreaManagerListener = ViewAreaManagerListener()
    SCEN_EDIT.model.areaManager:addListener(viewAreaManagerListener)

    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "message/message.lua")
    SCEN_EDIT.Include(SCEN_EDIT_DIR .. "message/message_manager.lua")
    SCEN_EDIT.messageManager = MessageManager()
    SCEN_EDIT.messageManager.widget = true


    --]]
    --    Spring.AssignMouseCursor('cursor-y', 'cursor-y');
    --    Spring.AssignMouseCursor('cursor-x-y-1', 'cursor-x-y-1');
    --    Spring.AssignMouseCursor('cursor-x-y-2', 'cursor-x-y-2');
    --    Spring.AssignMouseCursor('cursor-x', 'cursor-x');
    SCEN_EDIT.model:GenerateTeams(widget) 
    local commands = {}
    for id, team in pairs(SCEN_EDIT.model.teams) do
        local cmd = SetTeamColorCommand(id, team.color)
        table.insert(commands, cmd)
    end
    local cmd = CompoundCommand(commands)
    SCEN_EDIT.commandManager:execute(cmd)


    if devMode then
        LoadGUI()
    end
end

function reloadGadgets()
    wasEnabled = Spring.IsCheatingEnabled()
    if not wasEnabled then
        Spring.SendCommands("cheat")
    end
    Spring.SendCommands("luarules reload")
    Spring.SendCommands("globallos")
    if not wasEnabled then
        Spring.SendCommands("cheat")
    end
end

function widget:DrawScreen()
    SCEN_EDIT.stateManager:DrawScreen()
end

function widget:DrawWorld()
    --has to be initialized here since it creates textures
    if not SCEN_EDIT.model.tm then
        SCEN_EDIT.model.tm = TextureManager()
        SCEN_EDIT.model.tm:generateMapTextures()
    end

    SCEN_EDIT.stateManager:DrawWorld()
    SCEN_EDIT.view:DrawWorld()
	SCEN_EDIT.displayUtil:Draw()
end

function widget:DrawWorldPreUnit()
    SCEN_EDIT.stateManager:DrawWorldPreUnit()
    SCEN_EDIT.view:DrawWorldPreUnit()
end

function checkAreaIntersections(x, z)
    local areas = SCEN_EDIT.model.areaManager:getAllAreas()
    local selected, dragDiffX, dragDiffZ
    for id, area in pairs(areas) do
        if x >= area[1] and x < area[3] and z >= area[2] and z < area[4] then
            selected = id
            dragDiffX = area[1] - x
            dragDiffZ = area[2] - z
        end
    end
    return selected, dragDiffX, dragDiffZ
end

function widget:MousePress(x, y, button)
    return SCEN_EDIT.stateManager:MousePress(x, y, button)
end

function widget:MouseMove(x, y, dx, dy, button)
    return SCEN_EDIT.stateManager:MouseMove(x, y, button)
end

function widget:MouseRelease(x, y, button)
    return SCEN_EDIT.stateManager:MouseRelease(x, y, button)
end

function widget:MouseWheel(up, value)
    return SCEN_EDIT.stateManager:MouseWheel(up, value)
end

function widget:KeyPress(key, mods, isRepeat, label, unicode)
    return SCEN_EDIT.stateManager:KeyPress(key, mods, isRepeat, label, unicode)
end

function widget:GameFrame(frameNum)
    SCEN_EDIT.stateManager:GameFrame(frameNum)
	SCEN_EDIT.displayUtil:OnFrame()
    SCEN_EDIT.view:GameFrame(frameNum)
end
