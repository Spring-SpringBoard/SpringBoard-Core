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

local function Save(path)
	--path = path:gsub("\\", "/")
	--path = "./" .. path 
    err,msg = pcall(Model.Save, SCEN_EDIT.model, path)
    if not err then 
        Spring.Echo(msg)
    end--    model:Save("scenario.lua")
end

local function Load(path)
    --local f, err = loadfile(fileName)
    --local fileName = "scenario.lua"
    --local f = assert(io.open(path, "r"))	
    --local t = f:read("*all")
    --f:close()
    local data = VFS.LoadFile(path)
    Spring.Echo(#data)
    cmd = LoadCommand(data)
    SCEN_EDIT.commandManager:execute(cmd)
end

local function CreateTerrainEditor()
	local terrainEditor = Window:New {
		parent = screen0,
		x = 300,
		y = 400,
		width = 400,	
		height = 100,		
		children = {
			StackPanel:New {
                orientation = 'horizontal',
                width = '100%',
                height = '100%',
                padding = {0,0,0,0},
                itemPadding = {0,10,10,10},
                itemMargin = {0,0,0,0},
                resizeItems = false,
				children = {
					Button:New {
						caption = "Height",
						tooltip = "Modify heightmap",
						width = 120, --model.B_HEIGHT + 20,
						height = model.B_HEIGHT + 20,
						OnClick = {
							function()
                                SCEN_EDIT.stateManager:SetState(TerrainIncreaseState())
							end
						},
					},
					Button:New {
						caption = "Texture",
						tooltip = "Change texture",
						width = model.B_HEIGHT + 20,
						height = model.B_HEIGHT + 20,
						OnClick = {
							function()
                                SCEN_EDIT.stateManager:SetState(TerrainChangeTextureState())
							end
						},
					},
                    Button:New {
                        caption = "S",
						width = model.B_HEIGHT + 20,
						height = model.B_HEIGHT + 20,
                        OnClick = {
                            function()
                                Spring.Echo("HEIGHTMAP SAVE")
                                local fileName = "heightmap.test"
                                local file = assert(io.open(fileName, "wb"))
                                local data = {}
                                local totalChanged = 0

                                local bufferSize = 1000
                                local bufferFlush = function()
                                    if #data == 0 then
                                        return
                                    end
                                    --Spring.Echo("Packing...")
                                    local str = VFS.PackF32(data)
                                    --Spring.Echo("Unpacking...")
                                    local newData = VFS.UnpackF32(str, 1, #str / 4)
                                    --Spring.Echo(#data, #newData)
                                    if #data ~= #newData then
                                        --Spring.Echo("Different size!: ", #data, #newData)
                                    end
                                    local diffCount = 0
                                    for i = 1, math.min(#data, #newData) do
                                        if data[i] ~= newData[i] then
                                            diffCount = diffCount + 1
                                            --Spring.Echo("DIFF:", data[i], newData[i])
                                        end
                                        if diffCount > 100 then
                                            break
                                        end
                                    end
                                    file:write(str)
                                end
                                local addData = function(chunk)
                                    data[#data + 1] = chunk                                
                                    totalChanged = totalChanged + 1
                                    if #data >= bufferSize then
                                        bufferFlush()
                                        data = {}
                                    end
                                end
                                for x = 0, Game.mapSizeX, Game.squareSize do
                                    local lastChanged = false
                                    for z = 0, Game.mapSizeZ, Game.squareSize do
                                        local groundHeight = Spring.GetGroundHeight(x, z)
                                        local origGroundHeight = Spring.GetGroundOrigHeight(x, z)
                                        local deltaHeight = groundHeight - origGroundHeight
                                        if deltaHeight ~= 0 then
                                            --Spring.Echo(x, z)
                                            if lastChanged then
                                                --Spring.Echo(deltaHeight)
                                                if deltaHeight ~= deltaHeight then
                                                    --Spring.Echo(x, z)
                                                end
                                                addData(deltaHeight)
                                            else
                                                --Spring.Echo(x, z, deltaHeight)
                                                if deltaHeight ~= deltaHeight or x ~= x or z ~= z then
                                                    --Spring.Echo(x, z, deltaHeight)
                                                end
                                                addData(x)
                                                addData(z)
                                                addData(deltaHeight)
                                                lastChanged = true
                                            end
                                        else
                                            if lastChanged then
                                                --Spring.Echo(0)
                                                addData(0)
                                                lastChanged = false
                                            end
                                        end
                                    end
                                end
                                bufferFlush()
                                if totalChanged == 0 then
                                    Spring.Echo("Heightmap unchanged")
                                end
                                Spring.Echo("Floats: " .. totalChanged)
                                Spring.Echo("HEIGHTMAP SAVE DONE")
                                assert(file:close())
                            end
                        },
                    },
                    Button:New {
                        caption = "L",
						width = model.B_HEIGHT + 20,
						height = model.B_HEIGHT + 20,
                        OnClick = {
                            function()
                                local fileName = "heightmap.test"
                                local file = assert(io.open(fileName, "rb"))
                                local data = file:read("*a")--[[{}
                                while true do
                                    local d = file:read("*n")
                                    if d == nil then
                                        break
                                    end
                                    data[#data+1] = d
                                end--]]
                                assert(file:close())

                                loadMap = LoadMap(data)
                                SCEN_EDIT.commandManager:execute(loadMap)
                            end
                        },
                    },
				},
			},
		}
	}
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
                        SCEN_EDIT.stateManager:SetState(AddFeatureState(selFeatureDef, featureImages.teamId, featureImages))
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
        children = {
            Image:New { 
                tooltip = "Trigger settings", 
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
        children = {
            Image:New { 
                tooltip = "Variable settings", 
                file=SCEN_EDIT_IMG_DIR .. "format-text-bold.png", 
                height = model.B_HEIGHT - 2, 
                width = model.B_HEIGHT - 2, 
                margin = {0, 0, 0, 0},
            },
        },
    }


    toolboxWindow = Window:New {
        x = 1300,
        y = 100,
        width = 600,
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
                        children = {
                            Image:New { 
                                tooltip = "Add a rectangle area", 
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
                        OnClick = {
							function() 
                                local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
								sfd = SaveFileDialog(dir)
								sfd:setConfirmDialogCallback(function(path)
									success, msg = pcall(Save, path)
									if not success then
										Spring.Echo(msg)
									end
								end)
							end
						},
                        children = {
                            Image:New { 
                                tooltip = "Save mission", 
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
                        OnClick = {
                            function()
                                local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
								ofd = OpenFileDialog(dir)
								ofd:setConfirmDialogCallback(function(path)
									success, msg = pcall(Load, path)
									if not success then
										Spring.Echo(msg)
									end
								end)
                            end
                        },
                        children = {
                            Image:New { 
                                tooltip = "Load mission", 
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
						OnClick = {
							function()
								CreateUnitDefsView()
							end
						},
						children = {
							Image:New {
								tooltip = "Open unit panel",
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
						OnClick = {
							function()
								CreateFeatureDefsView()
							end
						},
						children = {
							Image:New {
								tooltip = "Open feature panel",
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
                                --local success, msg = pcall(OpenFileDialog)
                                if not success then
                                    Spring.Echo(msg)
                                end
								CreateTerrainEditor()
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
    Spring.SendCommands("globallos 1")
    if not wasEnabled then
        Spring.SendCommands("cheat")
    end
end

function widget:DrawWorld()
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
