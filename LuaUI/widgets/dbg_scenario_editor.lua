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
local selectedUnit
local updateFrame = 0

local drag_diff_x
local drag_diff_z

local selUnitDef
local unitDraw_x, unitDraw_y, unitDraw_z

local State = {mouse="none"}
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

local function DrawRect(x1, z1, x2, z2)
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

local function DrawRects()
    gl.Color(0, 255, 0, 0.2)
    x, y = gl.GetViewSizes()
    for i, rect in pairs(model.areas) do
        if selected ~= i then
            gl.DrawGroundQuad(rect[1], rect[2], rect[3], rect[4])
        end
    end
    if State.mouse == "addRectEnd" and end_x ~= nil and end_z ~= nil then
        DrawRect(area_x, area_z, end_x, end_z)
    end
    if selected ~= nil then
        gl.Color(0, 127, 127, 0.2)
        rect = model.areas[selected]
        DrawRect(rect[1], rect[2], rect[3], rect[4])
    end
end

local function AddRectButton()
    State.mouse = "addRect"
    selected = nil
end

function SelectArea(returnButton)
    State.mouse = "selArea"
    btnSelectArea = returnButton
end

function SelectUnit(returnButton)
    State.mouse = "selUnit"
    btnSelectUnit = returnButton
end

function SelectType(returnButton)
    State.mouse = "selType"
    btnSelectType = returnButton
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

function MakeTriggerWindow(trigger) 
    local triggerWindow = TriggerWindow:New {
 		parent = screen0,
        trigger = trigger,
        model = model,
    }
    return triggerWindow
end

local function Save()
    model:Save("mission.lua")
end

local function Load()
    success, msg = pcall(Model.Load, model, "mission.lua")
	if not success then
		Spring.Echo("Error loading model : " .. msg)
	end
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
								State.mouse = "terr_inc"
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
								State.mouse = "terr_dec"
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
					if State.mouse == "selType" then
						selUnitDef = unitImages.items[itemIdx].id
						CallListeners(btnSelectType.OnSelectUnitType, selUnitDef)
						State.mouse = "none"
					else
						State.mouse = 'addUnit'
						selUnitDef = unitImages.items[itemIdx].id
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
            end
        end
    }
	unitImages:SelectTeamId(teamsCmb.playerTeamIds[teamsCmb.selected])

    unitsWindow = Window:New {
        parent = screen0,
        caption = "Unit Editor",
        width = 325,
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
	if unitImages then
		return
	end
    featureImages = FeatureDefsView:New {
		name='features',
		x = 0,
		right = 20,
		OnSelectItem = {
			function(obj,itemIdx,selected)
				if selected and itemIdx > 0 then
					if State.mouse == "selectFeatureType" then
						selFeatureDef = featureImages.items[itemIdx].id
						CallListeners(btnSelectType.OnSelectUnitType, selFeatureDef)
						State.mouse = "none"
					else
						State.mouse = 'addFeature'
						selFeatureDef = featureImages.items[itemIdx].id
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
                featureImages:SelectTeamId(teamsCmb.playerTeamIds[itemIdx])
            end
        end
    }
	featureImages:SelectTeamId(teamsCmb.playerTeamIds[teamsCmb.selected])

    featuresWindow = Window:New {
        parent = screen0,
        caption = "Feature Editor",
        width = 325,
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
                caption = "Player:",
                x = 40,
                bottom = 8,
                width = 50,
            },
            teamsCmb,
        }
    }
end

local function StartMission()
	local x = table.show(model:GetMetaData())	
	PassToGadget(model._lua_rules_pre, "start", x)	
end 

function RecieveGadgetMessage(input)
	local tbl = loadstring(input)()
	local data = tbl.data
	local tag = tbl.tag

	if tag == "display" then
		SCEN_EDIT.displayUtil:displayText(data.text, data.coords, data.color)
	elseif tag == "msg" then
		model:InvokeCallback(data.msgId, data.result)
	end
end

function widget:UnitCreated(unitID, unitDefID, teamID, builderID)
	model:AddedUnit(unitID)
end

function widget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	model:RemovedUnit(unitID)
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
	VFS.Include(SCEN_EDIT_COMMON_DIR .. "display_util.lua")
	SCEN_EDIT.displayUtil = DisplayUtil(true)
	VFS.Include(SCENEDIT_DIR .. "combobox.lua")
	VFS.Include(SCENEDIT_DIR .. "util.lua")
	VFS.Include(SCENEDIT_DIR .. "core_types.lua")
	VFS.Include(SCENEDIT_DIR .. "model.lua")
	model = Model()
	model:RevertHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ)
	SCEN_EDIT.model = model
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
        width = 500,
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
					},
					Button:New {
						height = model.B_HEIGHT + 20,
						width = model.B_HEIGHT + 20,
						caption = '',
						OnClick = {
							function()
								StartMission()
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
					},
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
					btnTriggers.parent.disableChildrenHitTest = false
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
					btnVariableSettings.parent.disableChildrenHitTest = false
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

local function DrawUnits()	
	if State.mouse == "addUnit" then
		x, y = Spring.GetMouseState()
		local result, coords = Spring.TraceScreenRay(x, y)
        if result == "ground" then
			unitDraw_x = coords[1]
			unitDraw_y = coords[2]
			unitDraw_z = coords[3]
			if unitDraw_x ~= nil and unitDraw_y ~= nil and unitDraw_z ~= nil then
				gl.PushMatrix()
				gl.Translate(unitDraw_x, unitDraw_y, unitDraw_z)
				gl.UnitShape(selUnitDef, unitImages.teamId)
				gl.PopMatrix()			
			end
		end
	elseif State.mouse == "addFeature" then
		x, y = Spring.GetMouseState()
		local result, coords = Spring.TraceScreenRay(x, y)
        if result == "ground" then
			featureDraw_x = coords[1]
			featureDraw_y = coords[2]
			featureDraw_z = coords[3]
			if featureDraw_x ~= nil and featureDraw_y ~= nil and featureDraw_z ~= nil then
				gl.PushMatrix()
				gl.Translate(featureDraw_x, featureDraw_y, featureDraw_z)
				gl.FeatureShape(selFeatureDef, featureImages.teamId)
				gl.PopMatrix()			
			end
		end
	end
end

local function DrawModifier()
	x, y = Spring.GetMouseState()
	local result, coords = Spring.TraceScreenRay(x, y)
	if result == "ground" then
		local x, z = coords[1], coords[3]
		local startX, startZ = x - 20, z - 20
		local endX, endZ = x + 20, z + 20
		gl.PushMatrix()
		if State.mouse == "terr_inc" then			
			gl.Color(0, 255, 0, 0.3)
		elseif State.mouse == "terr_dec" then
			gl.Color(255, 0, 0, 0.3)			
		end
		DrawRect(startX, startZ, endX, endZ) 
		gl.PopMatrix()
	end
end

function widget:DrawWorld()
    DrawRects()
	DrawUnits()
	if State.mouse == "terr_inc" or State.mouse == "terr_dec" then
		DrawModifier()
	end
	SCEN_EDIT.displayUtil:Draw()
end

function checkResizeIntersections(x, z)
    if selected == nil then
        return false
    end
    local rect = model.areas[selected]
    local accurancy = 20
    if math.abs(x - rect[1]) < accurancy then
        State.resx = -1
        if z > rect[2] + accurancy and z < rect[4] - accurancy then
            State.resz = 0
        elseif math.abs(rect[2] - z) < accurancy then
            drag_diff_z = rect[2] - z
            State.resz = -1
        elseif math.abs(rect[4] - z) < accurancy then
            drag_diff_z = rect[4] - z
            State.resz = 1
        end
        drag_diff_x = rect[1] - x
        State.mouse = 'resize'
    elseif math.abs(x - rect[3]) < accurancy then
        State.resx = 1
        if z > rect[2] + accurancy and z < rect[4] - accurancy then
            State.resz = 0
        elseif math.abs(rect[2] - z) < accurancy then
            drag_diff_z = rect[2] - z
            State.resz = -1
        elseif math.abs(rect[4] - z) < accurancy then
            drag_diff_z = rect[4] - z
            State.resz = 1
        end
        drag_diff_x = rect[3] - x
        State.mouse = 'resize'
    elseif math.abs(z - rect[2]) < accurancy then
        State.resx = 0
        State.resz = -1
        drag_diff_z = rect[2] - z
        State.mouse = 'resize'
    elseif math.abs(z - rect[4]) < accurancy then
        State.resx = 0
        State.resz = 1
        drag_diff_z = rect[4] - z
        State.mouse = 'resize'
    end
end

function checkAreaIntersections(x, z)
    for i = #model.areas, 1, -1 do
        local rect = model.areas[i]
        if x >= rect[1] and x < rect[3] and z >= rect[2] and z < rect[4] then
            State.mouse = 'none'
            selected = i
            drag_diff_x = rect[1] - x
            drag_diff_z = rect[2] - z
            return
        end
    end
end

function widget:MousePress(x, y, button)
    if State.mouse == "none" and button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y)
        if result == "ground" then
            if selected ~= nil then
                checkResizeIntersections(coords[1], coords[3])
                if State.mouse == 'resize' then
                    return true
                end
            end
            selected = nil
            checkAreaIntersections(coords[1], coords[3])
            if selected ~= nil then
                Spring.SelectUnitArray({}, false)
                return true
            end
        elseif result == "unit" and #Spring.GetSelectedUnits() ~= 0 then
            selected = nil
            selectedUnit = coords --coords = unit id
            --drag_diff_x = coords[1]
            --drag_diff_y = coords[3]
            return true
        end
    elseif State.mouse == "addRect" then
        if button == 1 then
            local result, coords = Spring.TraceScreenRay(x, y)
            if result == "ground" then
                area_x = coords[1]
                area_z = coords[3]
                State.mouse = "addRectEnd"
                return true
            end
        elseif button == 3 then
            State.mouse = "none"
        end
    elseif State.mouse == "addUnit" then
        if button == 1 then
            local result, coords = Spring.TraceScreenRay(x, y)
            if result == "ground" then
                model:AddUnit(selUnitDef, coords[1], coords[2], coords[3], unitImages.teamId)
            end
        elseif button == 3 then
            State.mouse = "none"
            unitImages:SelectItem(0)
        end
    elseif State.mouse == "addFeature" then
        if button == 1 then
            local result, coords = Spring.TraceScreenRay(x, y)
            if result == "ground" then
                model:AddFeature(selFeatureDef, coords[1], coords[2], coords[3], featureImages.teamId)
            end
        elseif button == 3 then
            State.mouse = "none"
            featureImages:SelectItem(0)
        end
    elseif State.mouse == "selUnit" then
        if button == 1 then
            local result, unitId = Spring.TraceScreenRay(x, y)
            if result == "unit"  then
                CallListeners(btnSelectUnit.OnSelectUnit, model:GetModelUnitId(unitId))
            end
        elseif button == 3 then
            State.mouse = "none"
        end
    elseif State.mouse == "selArea" then
        if button == 1 then
            local result, coords = Spring.TraceScreenRay(x, y)
            if result == "ground"  then
                checkAreaIntersections(coords[1], coords[3])
                if selected ~= nil then
                    CallListeners(btnSelectArea.OnSelectArea, selected)
                end
            end
        elseif button == 3 then
            State.mouse = "none"
        end
    elseif State.mouse == "terr_inc" then
		if button == 1 then
			local result, coords = Spring.TraceScreenRay(x, y)
			if result == "ground"  then
				model:AdjustHeightMap(coords[1] - 20, coords[3] - 20, coords[1] + 20, coords[3] + 20, 20)
			end
		elseif button == 3 then
			State.mouse = "none"
		end
	elseif State.mouse == "terr_dec" then
		if button == 1 then
			local result, coords = Spring.TraceScreenRay(x, y)
			if result == "ground"  then
				model:AdjustHeightMap(coords[1] - 20, coords[3] - 20, coords[1] + 20, coords[3] + 20, -20)
			end
		elseif button == 3 then
			State.mouse = "none"
		end
	end
end

function widget:MouseMove(x, y, dx, dy, button)
    if State.mouse == "addRectEnd" then
        local result, coords = Spring.TraceScreenRay(x, y)
        if result == "ground" then
			end_x = coords[1]
			end_z = coords[3]
		end
    elseif State.mouse == "none" then
        if selected ~= nil then
            State.mouse = "drag"
        elseif selected == nil and #Spring.GetSelectedUnits() ~= 0 then
            State.mouse = "dragUnit"
        end
    elseif State.mouse == "drag" then
        local result, coords = Spring.TraceScreenRay(x, y)
        if result == "ground" then
            local area = model.areas[selected]
            local width = area[3] - area[1]
            local height = area[4] - area[2]
            area[1] = coords[1] + drag_diff_x 
            area[2] = coords[3] + drag_diff_z
            area[3] = area[1] + width
            area[4] = area[2] + height
        end
    elseif State.mouse == "dragUnit" then
        local selectedUnits = Spring.GetSelectedUnits()
        if updateFrame > #selectedUnits / 2 then 
            updateFrame = 0
        else 
            return
        end
        local result, coords = Spring.TraceScreenRay(x, y)
        if result == "ground" then
            local unitX, unitY, unitZ = Spring.GetUnitPosition(selectedUnit)
            if unitX == nil then --unit died probably
                State.mouse = "none"
                return false
            end
            local deltaX = coords[1] - unitX 
            local deltaZ = coords[3] - unitZ 
            for i = 1, #selectedUnits do
                local unitId = selectedUnits[i]
                local unitX, unitY, unitZ = Spring.GetUnitPosition(unitId)
                model:MoveUnit(unitId, unitX + deltaX, unitY, unitZ + deltaZ)
            end
        end
    elseif State.mouse == 'resize' then
        local result, coords = Spring.TraceScreenRay(x, y)
        if result == "ground" then
            local area = model.areas[selected]
            if State.resx == -1 then
                area[1] = coords[1] + drag_diff_x 
            elseif State.resx == 1 then
                area[3] = coords[1] + drag_diff_x 
            end
            if State.resz == -1 then
                area[2] = coords[3] + drag_diff_z 
            elseif State.resz == 1 then
                area[4] = coords[3] + drag_diff_z 
            end
        end
	end
end

function widget:MouseRelease(x, y, button)
    if State.mouse == "addRectEnd" then
        State.mouse = "none"
        if button ~= 1 then
            end_x = nil
            end_y = nil
            return
        end
        local result, coords = Spring.TraceScreenRay(x, y)
        if result == "ground" then
            end_x = coords[1]
            end_z = coords[3]
        end
        if end_x == nil or end_z == nil then
            return
        end
        if area_x < end_x then
            x1, x2 = area_x, end_x
        else
            x1, x2 = end_x, area_x
        end
        if area_z < end_z then
            z1, z2 = area_z, end_z
        else
            z1, z2 = end_z, area_z
        end
        table.insert(model.areas, {x1, z1, x2, z2})
        end_x = nil
        end_y = nil
    elseif State.mouse == "drag" then
        State.mouse = "none"
    elseif State.mouse == "dragUnit" then
        State.mouse = "none"
    elseif State.mouse == 'resize' then
        local rect = model.areas[selected]
        if rect[1] > rect[3] then
            rect[1], rect[3] = rect[3], rect[1]
        end
        if rect[2] > rect[4] then
            rect[2], rect[4] = rect[4], rect[2]
        end
        State.mouse = "none"
    elseif State.mouse == "addUnit" then
		echo("mouse release")
		return true
	end
end

function widget:KeyPress(key, mods, isRepeat, label, unicode)
    if State.mouse == "none" and selected ~= nil then
        if key == KEYSYMS.DELETE then
            table.remove(model.areas, selected)
            selected = nil
            return true
        end
    elseif State.mouse == "none" and selected == nil then
        if key == KEYSYMS.DELETE then
            local selectedUnits = Spring.GetSelectedUnits()
            for i = 1, #selectedUnits do
                local unitId = selectedUnits[i]
                model:RemoveUnit(unitId)
            end
            if #selectedUnits > 0 then
                return true
            end
        end
    end
    return false
end

function widget:GameFrame(frameNum)
    updateFrame = updateFrame + 1
	SCEN_EDIT.displayUtil:OnFrame()
end
