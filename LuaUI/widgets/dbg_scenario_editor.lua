-------------------------

function widget:GetInfo()
  return {
    name      = "Scenario Editor",
    desc      = "Mod-independent scenario editor",
    author    = "gajop",
    date      = "in the future",
    license   = "GPL-v2",
    layer     = 1001,
    enabled   = false,
  }
end

include("keysym.h.lua")
VFS.Include("savetable.lua")

local Chili
local Checkbox
local Button
local Label
local EditBox
local Window
local ScrollPanel
local StackPanel
local Grid
local TextBox
local Image
local TreeView
local Trackbar
local screen0
local C_HEIGHT = 16
local B_HEIGHT = 24
--------------------------

local SCENEDIT_DIR = LUAUI_DIRNAME .. "widgets/scen_edit/"
local SCEN_EDIT_COMMON_DIR = "scen_edit/common/"
local SCENEDIT_IMG_DIR = LUAUI_DIRNAME .. "images/scenedit/"

local echo = Spring.Echo

local btnSelectUnit = nil
local btnSelectArea = nil
local btnSelectType = nil

local area_x = 500
local area_z = 500
local end_x
local end_y
local model
local selected
local updateFrame = 0

local drag_diff_x
local drag_diff_z

local selUnitDef
local unitDraw_x, unitDraw_y, unitDraw_z

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
    SCEN_EDIT.stateManager:SetState(SelectUnitType(returnButton))
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

function MakeComponentPanel(parentPanel)
    local componentPanel = StackPanel:New {
        parent = parentPanel,
        width = "100%",
        height = model.B_HEIGHT + 8,
        orientation = "horizontal",
        padding = {0, 0, 0, 0},
        itemMarging = {0, 0, 0, 0},
        resizeItems = false,
    }
    return componentPanel
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

local function UpdateCondition(condition, cmbConditionTypes, conditionPanel)
    local condId = cmbConditionTypes.selected
    condition.typeId = condId 
    local unitCond = false
    local areaCond = false
    local condCond = false
    local unitAttr = false
    local triggerCond = false
    if condId == 1 or condId == 2 then
        unitCond = true
    end
    if condId == 1 then
        areaCond = true
    end
    if condId == 2 then
        unitAttr = true
    end
    if condId == 3 or condId == 4 or condId == 5 then
        condCond = true
    end
    if condId == 6 then
        triggerCond = true
    end

    if unitCond then
        condition.unit = {}
        conditionPanel.unitPanel:UpdateModel(condition.unit)
    end
    if areaCond then
        condition.area = {}
        conditionPanel.areaPanel:UpdateModel(condition.area)
    end

    if unitAttr then
        condition.attr = {}
        conditionPanel.unitAttrPanel:UpdateModel(condition.attr)
    end
    if triggerCond then
        condition.trigger = {}
        conditionPanel.triggerPanel:UpdateModel(condition.trigger)
    end
end

local function AddCondition(trigger, triggerWindow, condition)
    table.insert(trigger.conditions, condition)
    triggerWindow:Populate()
end

local function EditCondition(trigger, triggerWindow)
    triggerWindow:Populate()
end

local function MakeConditionWindow(trigger, triggerWindow)
    triggerWindow.disableChildrenHitTest = true
    local btnOk = Button:New {
        caption = "OK",
        height = model.B_HEIGHT,
        width = "40%",
        x = "5%",
        y = "7%",
    }
    local btnCancel = Button:New {
        caption = "Cancel",
        height = model.B_HEIGHT,
        width = "40%",
        x = "55%",
        y = "7%",
    }
    local conditionPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0}
    }
    local cmbConditionTypes = ComboBox:New {
        items = conditionTypes,
        height = model.B_HEIGHT,
        width = "60%",
        y = "20%",
        x = '20%',
        OnSelectItem = {
            function(obj, itemIdx, selected)
                if selected and itemIdx > 0 then
                    conditionPanel:ClearChildren()
                    local condId = itemIdx
                    local unitCond = false
                    local areaCond = false
                    local condCond = false
                    local unitAttr = false
                    local triggerCond = false
                    if condId == 1 or condId == 2 then
                        unitCond = true
                    end
                    if condId == 1 then
                        areaCond = true
                    end
                    if condId == 2 then
                        unitAttr = true
                    end
                    if condId == 3 or condId == 4 or condId == 5 then
                        condCond = true
                    end
                    if condId == 6 then
                        triggerCond = true
                    end

                    if unitCond then
                        conditionPanel.unitPanel = UnitPanel:New {
                            parent = conditionPanel,
                            model = model,
                        }
                        MakeSeparator(conditionPanel)
                    end

                    if areaCond then
                        conditionPanel.areaPanel = AreaPanel:New {
                            parent = conditionPanel,
                        }
                        MakeSeparator(conditionPanel)
                    end
                    if unitAttr then
                        conditionPanel.unitAttrPanel = UnitAttrPanel:New {
                            parent = conditionPanel,
                        }
                        MakeSeparator(conditionPanel)
                    end
                    if condCond then
                        local conditionsPanel = StackPanel:New {
                            itemMargin = {0, 0, 0, 0},
                            x = 1,
                            y = 1,
                            right = 1,
                            autosize = true,
                            resizeItems = false,
                            padding = {0, 0, 0, 0}
                        }
                    end
                    if triggerCond then
                        conditionPanel.triggerPanel = TriggerPanel:New {
                            parent = conditionPanel,
                            model = model,
                        }
                    end
                end
            end
        },
    }
    local newConditionWindow = Window:New {
 		parent = screen0,
 		caption = "New condition for - " .. trigger.name,
        resizable = false,
        clientWidth = 300,
        clientHeight = 300,
        x = 500,
        y = 300,
        children = {
            cmbConditionTypes,
            btnOk,
            btnCancel,
            ScrollPanel:New {
                x = 1,
                y = cmbConditionTypes.y + cmbConditionTypes.height + 80,
                bottom = 1,
                right = 5,
                children = {
                    conditionPanel,
                },
            },
        }
    }
    btnCancel.OnClick = {
    function() 
        triggerWindow.disableChildrenHitTest = false
        newConditionWindow:Dispose()
    end}
    return newConditionWindow, btnOk, cmbConditionTypes, conditionPanel
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
--[[
function MakeAddConditionWindow(trigger, triggerWindow)
    newConditionWindow, btnOk, cmbConditionTypes, conditionPanel = MakeConditionWindow(trigger, triggerWindow)
    local tw = triggerWindow
    newConditionWindow.x = tw.x
    newConditionWindow.y = tw.y + tw.height + 5
    if tw.parent.height <= newConditionWindow.y + newConditionWindow.height then
        newConditionWindow.y = tw.y - newConditionWindow.height
    end
    btnOk.OnClick = {
		function()
			local condition = { typeId = cmbConditionTypes.selected }
			UpdateCondition(condition, cmbConditionTypes, conditionPanel)
			AddCondition(trigger, triggerWindow, condition)
			triggerWindow.disableChildrenHitTest = false
			newConditionWindow:Dispose()
		end
	}
end

function MakeEditConditionWindow(trigger, triggerWindow, condition)
    newConditionWindow, btnOk, cmbConditionTypes, conditionPanel = MakeConditionWindow(trigger, triggerWindow)

    table.print(condition)
    cmbConditionTypes:Select(condition.typeId)
    local condId = condition.typeId
    local unitCond = false
    local areaCond = false
    local condCond = false
    local unitAttr = false
    local triggerCond = false
    if condId == 1 or condId == 2 then
        unitCond = true
    end
    if condId == 1 then
        areaCond = true
    end
    if condId == 2 then
        unitAttr = true
    end
    if condId == 3 or condId == 4 or condId == 5 then
        condCond = true
    end
    if condId == 6 then
        triggerCond = true
    end

    if unitCond then
        conditionPanel.unitPanel:UpdatePanel(condition.unit)
    end
    if areaCond then
        conditionPanel.areaPanel:UpdatePanel(condition.area)
    end
    if unitAttr then
        conditionPanel.unitAttrPanel:UpdatePanel(condition.attr)
    end
    if triggerCond then
        conditionPanel.triggerPanel:UpdatePanel(condition.trigger)
    end


    local tw = triggerWindow
    if tw.x + tw.width + newConditionWindow.width > tw.parent.width then
        newConditionWindow.x = tw.x - newConditionWindow.width
    else
        newConditionWindow.x = tw.x + tw.width
    end
    newConditionWindow.y = tw.y
    newConditionWindow.caption = "Edit condition for trigger " .. trigger.name
    btnOk.OnClick = {
		function() 
			UpdateCondition(condition, cmbConditionTypes, conditionPanel)
			EditCondition(trigger, triggerWindow)
			triggerWindow.disableChildrenHitTest = false
			newConditionWindow:Dispose()
		end
	}
end
--]]
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

local function Save()
    err,msg = pcall(Model.Save, SCEN_EDIT.model, "scenario.lua")
    if not err then 
        Spring.Echo(msg)
    end--    model:Save("scenario.lua")
end

local function Load()
    --local f, err = loadfile(fileName)
    local fileName = "scenario.lua"
    local f = assert(io.open(fileName, "r"))
    local t = f:read("*all")
    f:close()
    cmd = LoadCommand(t)
    SCEN_EDIT.commandManager:execute(cmd)
--[[    success, msg = pcall(Model.Load, model, "scenario.lua")
	if not success then
		Spring.Echo("Error loading model : " .. msg)
	end-]]
end

local function CreateTerrainEditor()
	local terrainEditor = Window:New {
		parent = screen0,
		x = 300,
		y = 400,
		width = 300,	
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
						caption = "Up",
						tooltip = "Increase terrain",
						width = model.B_HEIGHT + 20,
						height = model.B_HEIGHT + 20,
						OnClick = {
							function()
                                SCEN_EDIT.stateManager:SetState(TerrainIncreaseState())
							end
						},
					},
					Button:New {
						caption = "Down",
						tooltip = "Decrease terrain",
						width = model.B_HEIGHT + 20,
						height = model.B_HEIGHT + 20,
						OnClick = {
							function()
                                SCEN_EDIT.stateManager:SetState(TerrainDecreaseState())
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
						selUnitDef = unitImages.items[itemIdx].id
						CallListeners(currentState.btnSelectType.OnSelectUnitType, selUnitDef)
                        SCEN_EDIT.stateManager:SetState(DefaultState())
					else
						selUnitDef = unitImages.items[itemIdx].id
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
    teamsCmb.OnSelectItem = {
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
                bottom = 8 + C_HEIGHT * 2,
                caption = "Type:",
            },
            ComboBox:New {
                height = model.B_HEIGHT,
                x = 50,
                bottom = 1 + C_HEIGHT * 2,
                items = {
                    "Units", "Buildings", "All",
                },
                width = 80,
                OnSelectItem = {
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
                bottom = 8 + C_HEIGHT * 2,
                width = 50,
            },
            ComboBox:New {
                bottom = 1 + C_HEIGHT * 2,
                height = model.B_HEIGHT,
                items = {
                    "Ground", "Air", "Water", "All",
                },
                x = 200,
                width=80,
                OnSelectItem = {
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
    teamsCmb.OnSelectItem = {
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
                bottom = 8 + C_HEIGHT * 2,
                caption = "Type:",
            },
            ComboBox:New {
                height = model.B_HEIGHT,
                x = 50,
                bottom = 1 + C_HEIGHT * 2,
                items = {
                    "Wreckage", "Other", "All",
                },
                width = 80,
                OnSelectItem = {
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
                bottom = 8 + C_HEIGHT * 2,
                caption = "Wreck:",
            },
            ComboBox:New {
                height = model.B_HEIGHT,
                x = 190,
                bottom = 1 + C_HEIGHT * 2,
                items = {
                    "Units", "Buildings", "All",
                },
                width = 80,
                OnSelectItem = {
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
                bottom = 8 + C_HEIGHT * 2,
                width = 50,
            },
            ComboBox:New {
                bottom = 1 + C_HEIGHT * 2,
                height = model.B_HEIGHT,
                items = {
                    "Ground", "Air", "Water", "All",
                },
                x = 330,
                width=80,
                OnSelectItem = {
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

function widget:Initialize()
    local devMode = Spring.GetGameRulesParam('devmode') == 1
    if not WG.Chili or not devMode then
        widgetHandler:RemoveWidget(widget)
        return
    end
	widgetHandler:RegisterGlobal("RecieveGadgetMessage", RecieveGadgetMessage)
	reloadGadgets() --uncomment for development	
	VFS.Include(SCEN_EDIT_COMMON_DIR .. "class.lua")
    LCS = loadstring(VFS.LoadFile(SCEN_EDIT_COMMON_DIR .. "lcs/LCS.lua"))
    LCS = LCS()
    VFS.Include(SCEN_EDIT_COMMON_DIR .. "observable.lua")

	VFS.Include(SCEN_EDIT_COMMON_DIR .. "display_util.lua")
	SCEN_EDIT.displayUtil = DisplayUtil(true)
	VFS.Include(SCENEDIT_DIR .. "combobox.lua")
	VFS.Include(SCENEDIT_DIR .. "util.lua")
	VFS.Include(SCENEDIT_DIR .. "core_types.lua")
	VFS.Include(SCENEDIT_DIR .. "model.lua")
	model = Model()
	model:RevertHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ)
	SCEN_EDIT.model = model

    VFS.Include(SCEN_EDIT_COMMON_DIR .. "model/area_manager.lua")
    SCEN_EDIT.model.areaManager = AreaManager()

    VFS.Include(SCEN_EDIT_COMMON_DIR .. "model/unit_manager.lua")
    SCEN_EDIT.model.unitManager = UnitManager(true)

    VFS.Include(SCEN_EDIT_COMMON_DIR .. "model/feature_manager.lua")
    SCEN_EDIT.model.featureManager = FeatureManager(true)

    VFS.Include(SCEN_EDIT_COMMON_DIR .. "model/variable_manager.lua")
    SCEN_EDIT.model.variableManager = VariableManager(true)

    VFS.Include(SCEN_EDIT_COMMON_DIR .. "model/variable_manager_listener.lua")
    VFS.Include(SCEN_EDIT_COMMON_DIR .. "model/variable_manager_listener_widget.lua")

    VFS.Include(SCEN_EDIT_COMMON_DIR .. "model/trigger_manager.lua")
    SCEN_EDIT.model.triggerManager = TriggerManager(true)

    VFS.Include(SCEN_EDIT_COMMON_DIR .. "model/trigger_manager_listener.lua")
    VFS.Include(SCEN_EDIT_COMMON_DIR .. "model/trigger_manager_listener_widget.lua")

    VFS.Include(SCEN_EDIT_COMMON_DIR .. "view/clipboard.lua")
    SCEN_EDIT.clipboard = Clipboard()

    VFS.Include(SCEN_EDIT_COMMON_DIR .. "command/command_manager.lua")
    SCEN_EDIT.commandManager = CommandManager()
    SCEN_EDIT.commandManager.widget = true
    SCEN_EDIT.commandManager:loadClasses()

    VFS.Include(SCEN_EDIT_COMMON_DIR .. "state/state_manager.lua")
    SCEN_EDIT.stateManager = StateManager()

    VFS.Include(SCEN_EDIT_COMMON_DIR .. "view/view.lua")
    SCEN_EDIT.view = View()
    local viewAreaManagerListener = ViewAreaManagerListener()
    SCEN_EDIT.model.areaManager:addListener(viewAreaManagerListener)

    VFS.Include(SCEN_EDIT_COMMON_DIR .. "message/message.lua")
    VFS.Include(SCEN_EDIT_COMMON_DIR .. "message/message_manager.lua")
    SCEN_EDIT.messageManager = MessageManager()
    SCEN_EDIT.messageManager.widget = true

    VFS.Include(SCENEDIT_DIR .. "unitdefsview.lua")    
	VFS.Include(SCENEDIT_DIR .. "feature_defs_view.lua")    
    VFS.Include(SCENEDIT_DIR .. "triggers_window.lua")
    VFS.Include(SCENEDIT_DIR .. "trigger_window.lua")
    VFS.Include(SCENEDIT_DIR .. "variable_settings_window.lua")
    VFS.Include(SCENEDIT_DIR .. "variable_window.lua")
	
    VFS.Include(SCENEDIT_DIR .. "panels/unit_panel.lua")
    VFS.Include(SCENEDIT_DIR .. "panels/area_panel.lua")    
    VFS.Include(SCENEDIT_DIR .. "panels/trigger_panel.lua")
    VFS.Include(SCENEDIT_DIR .. "panels/team_panel.lua")
    VFS.Include(SCENEDIT_DIR .. "panels/type_panel.lua")
    VFS.Include(SCENEDIT_DIR .. "panels/number_panel.lua")
	VFS.Include(SCENEDIT_DIR .. "panels/string_panel.lua")
	VFS.Include(SCENEDIT_DIR .. "panels/bool_panel.lua")
	VFS.Include(SCENEDIT_DIR .. "panels/order_panel.lua")
	VFS.Include(SCENEDIT_DIR .. "panels/numeric_comparison_panel.lua")
	VFS.Include(SCENEDIT_DIR .. "panels/identity_comparison_panel.lua")
	VFS.Include(SCENEDIT_DIR .. "panels/generic_array_panel.lua")

	VFS.Include(SCENEDIT_DIR .. "event_window.lua")
	VFS.Include(SCENEDIT_DIR .. "action_window.lua")
	VFS.Include(SCENEDIT_DIR .. "condition_window.lua")
	VFS.Include(SCENEDIT_DIR .. "custom_window.lua")
	  
    -- setup Chili
    Chili = WG.Chili
    Checkbox = Chili.Checkbox
    Button = Chili.Button
    Label = Chili.Label
    EditBox = Chili.EditBox
    Window = Chili.Window
    ScrollPanel = Chili.ScrollPanel
    StackPanel = Chili.StackPanel
    Grid = Chili.Grid
    TextBox = Chili.TextBox
    Image = Chili.Image
    TreeView = Chili.TreeView
    Trackbar = Chili.Trackbar
    screen0 = Chili.Screen0

    local btnTriggers = Button:New {
        caption = '',
        height = model.B_HEIGHT + 20,
        width = model.B_HEIGHT + 20,
        children = {
            Image:New { 
                tooltip = "Trigger settings", 
                file=SCENEDIT_IMG_DIR .. "applications-system.png", 
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
                file=SCENEDIT_IMG_DIR .. "format-text-bold.png", 
                height = model.B_HEIGHT - 2, 
                width = model.B_HEIGHT - 2, 
                margin = {0, 0, 0, 0},
            },
        },
    }


    toolboxWindow = Window:New {
        x = 500,
        y = 500,
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
                                file=SCENEDIT_IMG_DIR .. "view-fullscreen.png", 
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
                        OnClick = {Save},
                        children = {
                            Image:New { 
                                tooltip = "Save mission", 
                                file=SCENEDIT_IMG_DIR .. "document-save.png", 
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
                        OnClick = {Load},
                        children = {
                            Image:New { 
                                tooltip = "Load mission", 
                                file = SCENEDIT_IMG_DIR .. "document-open.png", 
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
								file = SCENEDIT_IMG_DIR .. "face-monkey.png",
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
								file = SCENEDIT_IMG_DIR .. "face-monkey.png",
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
								file = SCENEDIT_IMG_DIR .. "media-playback-start.png",
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
                                --local success, msg = pcall(FileDialog)
                                --if not success then
                                 --   Spring.Echo(msg)
                                --end
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

	--[[
    local testWindow = Window:New {
        parent = screen0,
        caption = "Test",
        width = 325,
        height = 100,
        resizable = false,
        x = 800,
        y = 500,
        children = {
            EditBox:New {
                text = "text",
                width = 100,
                x = 0,
                y = 30,
                height = model.B_HEIGHT,
                OnMouseDown = { function() echo("clicked") end },
            },
            EditBox:New {
                text = "text",
                width = 100,
                x = 150,
                y = 30,
                height = model.B_HEIGHT,
                OnMouseDown = { function() echo("clicked") end },
            },
        },
    }
    eb = testWindow.children[1]
    eb.OnClick = { function() echo(eb.x, eb.y, eb.width, eb.height) end }
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
    SCEN_EDIT.view:draw()
	SCEN_EDIT.displayUtil:Draw()
end

function checkAreaIntersections(x, z)
    local areas = SCEN_EDIT.model.areaManager:getAllAreas()
    local selected, dragDiffX, dragDiffZ
    for id, area in pairs(areas) do
        if x >= area[1] and x < area[3] and z >= area[2] and z < area[4] then
            SCEN_EDIT.view.areaViews[id].selected = true
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

function widget:KeyPress(key, mods, isRepeat, label, unicode)
    return SCEN_EDIT.stateManager:KeyPress(key, mods, isRepeat, label, unicode)
end

function widget:GameFrame(frameNum)
    SCEN_EDIT.stateManager:GameFrame(frameNum)
	SCEN_EDIT.displayUtil:OnFrame()
end
