-------------------------

function widget:GetInfo()
  return {
    name      = "Scenario Editor",
    desc      = "Mod-independent scenario editor",
    author    = "gajop",
    date      = "in the future",
    license   = "GPL-v2",
    layer     = 0,
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

local SCENEDIT_DIR = LUAUI_DIRNAME .. "widgets/scenedit/"
local SCENEDIT_IMG_DIR = LUAUI_DIRNAME .. "images/scenedit/"

local echo = Spring.Echo

local btnSelectUnit = nil
local btnSelectArea = nil
local btnSelectType = nil

local area_x = 500
local area_z = 500
local end_x = nil
local end_y = nil
local model
local selected = nil
local selectedUnit = nil
local updateFrame = 0

local drag_diff_x = nil
local drag_diff_z = nil

local selUnitDef = nil

local State = {mouse="none"}
local unitImages

local eventTypes = {"Game starts", "Game ends", "Player died", "Unit created", "Unit damaged", "Unit destroyed", "Unit finished", "Unit enters area", "Unit leaves area"}
local conditionTypes = {"Unit in area", "Unit attribute", "And conditions", "Or conditions", "Not condition", "Trigger enabled"}
local actionTypes = {"Spawn unit", "Issue order", "Destroy unit", "Move unit", "Transfer unit", "Enable trigger", "Disable trigger"}

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

function MakeVariableChoice(variableType, panel)
    local variableNames = {}
    local variableIds = {}
    for i = 1, #model.variables do
        local variable = model.variables[i]
        if variable.type == variableType then
            table.insert(variableNames, variable.name)
            table.insert(variableIds, variable.id)
        end
    end

    if #variableIds > 0 then
        local stackPanel = MakeComponentPanel(panel)
        local cbVariable = Chili.Checkbox:New {
            caption = "Variable: ",
            right = 100 + 10,
            x = 1,
            checked = false,
            parent = stackPanel,
        }
        
        local cmbVariable = ComboBox:New {
            right = 1,
            width = 100,
            height = B_HEIGHT,
            parent = stackPanel,
            items = variableNames,
            variableIds = variableIds,
        }
        cmbVariable.OnSelectItem = {
            function(obj, itemIdx, selected)
                if selected and itemIdx > 0 then
                    if not cbVariable.checked then
                        cbVariable:Toggle()
                    end
                end
            end
        }
        return cbVariable, cmbVariable
    else
        return nil, nil
    end
end

local function MakeSeparator(panel)
    local lblSeparator = Label:New {
        parent = panel,
        height = B_HEIGHT + 10,
        caption = "===================================",
        align = 'center',
    }
    return lblSeparator
end

function MakeComponentPanel(parentPanel)
    local componentPanel = StackPanel:New {
        parent = parentPanel,
        width = "100%",
        height = B_HEIGHT + 8,
        orientation = "horizontal",
        padding = {0, 0, 0, 0},
        itemMarging = {0, 0, 0, 0},
        resizeItems = false,
    }
    return componentPanel
end

function GetTeams()
    local playerNames = {}
    local playerTeamIds = {}
    local playerIds = Spring.GetTeamList()
    for i = 1, #playerIds do
        local id, _, _, name = Spring.GetAIInfo(playerIds[i])
        if id ~= nil then
            table.insert(playerTeamIds, playerIds[i])
            table.insert(playerNames, "Team " .. playerIds[i] .. ": " .. name)
        end
    end
    return playerNames, playerTeamIds
end

local function AddEvent(trigger, triggerWindow, eventTypeId)
    local event = { eventTypeId = eventTypeId }
    table.insert(trigger.events, event)
    triggerWindow:Populate()
end

local function EditEvent(trigger, triggerWindow, eventTypeId, event)
    event.eventTypeId = eventTypeId
    triggerWindow:Populate()
end

function MakeEventWindow(trigger, triggerWindow)
    triggerWindow.disableChildrenHitTest = true
    local btnOk = Button:New {
        caption = "OK",
        height = B_HEIGHT,
        width = "40%",
        x = "5%",
        y = "20%",
    }
    local btnCancel = Button:New {
        caption = "Cancel",
        height = B_HEIGHT,
        width = "40%",
        x = "55%",
        y = "20%",
    }
    local cmbEventTypes = ComboBox:New {
        items = eventTypes,
        height = B_HEIGHT,
        width = "40%",
        y = "60%",
        x = '30%',
    }
    local newEventWindow = Window:New {
 		parent = screen0,
 		caption = "New event for - " .. trigger.name,
        resizable = false,
        clientWidth = 300,
        clientHeight = 100,
        x = 500,
        y = 300,
        children = {
            cmbEventTypes,
            btnOk,
            btnCancel
        }
    }
    btnCancel.OnClick = {
    function() 
        triggerWindow.disableChildrenHitTest = false
        newEventWindow:Dispose()
    end}
    return newEventWindow, btnOk, cmbEventTypes
end

function MakeAddEventWindow(trigger, triggerWindow)
    newEventWindow, btnOk, cmbEventTypes = MakeEventWindow(trigger, triggerWindow)
    local tw = triggerWindow
    newEventWindow.x = tw.x
    newEventWindow.y = tw.y + tw.height + 5
    if tw.parent.height <= newEventWindow.y + newEventWindow.height then
        newEventWindow.y = tw.y - newEventWindow.height
    end
    btnOk.OnClick = {
    function() 
        AddEvent(trigger, triggerWindow, cmbEventTypes.selected)
        triggerWindow.disableChildrenHitTest = false
        newEventWindow:Dispose()
    end}
end

function MakeEditEventWindow(trigger, triggerWindow, event)
    newEventWindow, btnOk, cmbEventTypes = MakeEventWindow(trigger, triggerWindow)
    local tw = triggerWindow
    if tw.x + tw.width + newEventWindow.width > tw.parent.width then
        newEventWindow.x = tw.x - newEventWindow.width
    else
        newEventWindow.x = tw.x + tw.width
    end
    newEventWindow.y = tw.y
    newEventWindow.caption = "Edit event for trigger " .. trigger.name
    cmbEventTypes:Select(event.eventTypeId)
    btnOk.OnClick = {
    function() 
        EditEvent(trigger, triggerWindow, cmbEventTypes.selected, event)
        triggerWindow.disableChildrenHitTest = false
        newEventWindow:Dispose()
    end}
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
        height = B_HEIGHT,
        width = "40%",
        x = "5%",
        y = "7%",
    }
    local btnCancel = Button:New {
        caption = "Cancel",
        height = B_HEIGHT,
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
        height = B_HEIGHT,
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
    end}
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
    end}
end

function MakeRemoveConditionWindow(trigger, triggerWindow, condition, idx)
    table.remove(trigger.conditions, idx)
    triggerWindow:Populate()
end

local function AddAction(trigger, triggerWindow, actionTypeId)
    local action = { actionTypeId = actionTypeId }
    table.insert(trigger.actions, action)
    triggerWindow:Populate()
end

local function EditAction(trigger, triggerWindow, actionTypeId, action)
    action.actionTypeId = actionTypeId
    triggerWindow:Populate()
end

local function MakeActionWindow(trigger, triggerWindow)
    triggerWindow.disableChildrenHitTest = true
    local btnOk = Button:New {
        caption = "OK",
        height = B_HEIGHT,
        width = "40%",
        x = "5%",
        y = "7%",
    }
    local btnCancel = Button:New {
        caption = "Cancel",
        height = B_HEIGHT,
        width = "40%",
        x = "55%",
        y = "7%",
    }
    local actionPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0}
    }
    local cmbActionTypes = ComboBox:New {
        items = actionTypes,
        height = B_HEIGHT,
        width = "60%",
        y = "20%",
        x = '20%',
        OnSelectItem = {
            function(obj, itemIdx, selected)
                if selected and itemIdx > 0 then
                    actionPanel:ClearChildren()
                    local actId = itemIdx
                    local unitAct = false
                    local triggerAct = false
                    local typeAct = false
                    local orderAct = false
                    local areaAct = false

                    if actId == 1 then
                        typeAct = true
                    end
                    if actId == 2 or actId == 3 or actId == 4 or actId == 5 then
                        unitAct = true
                    end
                    if actId == 1 or actId == 4 then
                        areaAct = true
                    end
                    if actId == 2 then
                        orderAct = true
                    end
                    if actId == 6 or actId == 7 then
                        triggerAct = true
                    end

                    if unitAct then
                        actionPanel.unitPanel = UnitPanel:New {
                            parent = actionPanel,
                            model = model,
                        }
                        MakeSeparator(actionPanel)
                    end
                    if areaAct then
                        actionPanel.areaPanel = AreaPanel:New {
                            parent = actionPanel,
                        }
                        MakeSeparator(actionPanel)
                    end
                    if triggerAct then
                        actionPanel.triggerPanel = TriggerPanel:New {
                            parent = actionPanel,
                            model = model,
                        }
                    end
                    if typeAct then
                        MakeSeparator(actionPanel)
                        local stackTypePanel = 
                        MakeComponentPanel(actionPanel)
                        local cbPredefinedType = Checkbox:New {
                            caption = "Predefined type: ",
                            right = 100 + 10,
                            x = 1,
                            checked = false,
                            parent = stackTypePanel,
                        }
                        local btnPredefinedType = Button:New {
                            caption = '...',
                            right = 1,
                            width = 100,
                            height = B_HEIGHT,
                            parent = stackTypePanel,
                            unitTypeId = nil,
                        }
                        btnPredefinedType.OnClick = {
                            function() 
                                SelectType(btnPredefinedType)
                            end
                        }
                        btnPredefinedType.OnSelectUnitType = { 
                            function(unitTypeId)
                                btnPredefinedType.unitTypeId = unitTypeId
                                btnPredefinedType.caption = 
                                "Type id=" .. unitTypeId
                                btnPredefinedType:Invalidate()
                                if not cbPredefinedType.checked then 
                                    cbPredefinedType:Toggle()
                                end
                            end
                        }
                        --SPECIAL TYPE, i.e TRIGGER
                        local stackTypePanel = MakeComponentPanel(actionPanel)
                        local cbSpecialType = Checkbox:New {
                            caption = "Special type: ",
                            right = 100 + 10,
                            x = 1,
                            checked = true,
                            parent = stackTypePanel,
                        }
                        local cmbSpecialType = ComboBox:New {
                            right = 1,
                            width = 100,
                            height = B_HEIGHT,
                            parent = stackTypePanel,
                            items = { "Trigger unit type" },
                            OnSelectItem = {
                                function(obj, itemIdx, selected)
                                    if selected and itemIdx > 0 then
                                        if not cbSpecialType.checked then
                                            cbSpecialType:Toggle()
                                        end
                                    end
                                end
                            },
                        }
                        MakeRadioButtonGroup({cbSpecialType, cbPredefinedType})
                    end
                end
            end
        }
    }
    local newActionWindow = Window:New {
 		parent = screen0,
 		caption = "New action for - " .. trigger.name,
        resizable = false,
        clientWidth = 300,
        clientHeight = 300,
        x = 500,
        y = 300,
        children = {
            cmbActionTypes,
            btnOk,
            btnCancel,
            ScrollPanel:New {
                x = 1,
                y = cmbActionTypes.y + cmbActionTypes.height + 80,
                bottom = 1,
                right = 5,
                children = {
                    actionPanel,
                },
            },
        }
    }
    btnCancel.OnClick = {
    function() 
        triggerWindow.disableChildrenHitTest = false
        newActionWindow:Dispose()
    end}
    return newActionWindow, btnOk, cmbActionTypes
end

function MakeAddActionWindow(trigger, triggerWindow)
    newActionWindow, btnOk, cmbActionTypes = MakeActionWindow(trigger, triggerWindow)
    local tw = triggerWindow
    newActionWindow.x = tw.x
    newActionWindow.y = tw.y + tw.height + 5
    if tw.parent.height <= newActionWindow.y + newActionWindow.height then
        newActionWindow.y = tw.y - newActionWindow.height
    end
    btnOk.OnClick = {
    function() 
        AddAction(trigger, triggerWindow, cmbActionTypes.selected)
        triggerWindow.disableChildrenHitTest = false
        newActionWindow:Dispose()
    end}
end

function MakeEditActionWindow(trigger, triggerWindow, action)
    newActionWindow, btnOk, cmbActionTypes = MakeActionWindow(trigger, triggerWindow)
    cmbActionTypes:Select(action.actionTypeId)
    local tw = triggerWindow
    if tw.x + tw.width + newActionWindow.width > tw.parent.width then
        newActionWindow.x = tw.x - newActionWindow.width
    else
        newActionWindow.x = tw.x + tw.width
    end
    newActionWindow.y = tw.y
    newActionWindow.caption = "Edit action for trigger " .. trigger.name
    btnOk.OnClick = {
    function() 
        EditAction(trigger, triggerWindow, cmbActionTypes.selected, action)
        triggerWindow.disableChildrenHitTest = false
        newActionWindow:Dispose()
    end}
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
    model:Load("mission.lua")
end

function widget:Initialize()
    local devMode = Spring.GetGameRulesParam('devmode') == 1
    if not WG.Chili or not devMode then
        widgetHandler:RemoveWidget(widget)
        return
    end

    VFS.Include(SCENEDIT_DIR .. "unitdefsview.lua")
    VFS.Include(SCENEDIT_DIR .. "combobox.lua")
    VFS.Include(SCENEDIT_DIR .. "model.lua")
    VFS.Include(SCENEDIT_DIR .. "triggers_window.lua")
    VFS.Include(SCENEDIT_DIR .. "trigger_window.lua")
    VFS.Include(SCENEDIT_DIR .. "variable_settings_window.lua")
    VFS.Include(SCENEDIT_DIR .. "variable_window.lua")

    VFS.Include(SCENEDIT_DIR .. "panels/unit_panel.lua")
    VFS.Include(SCENEDIT_DIR .. "panels/area_panel.lua")
    VFS.Include(SCENEDIT_DIR .. "panels/unit_attr_panel.lua")
    VFS.Include(SCENEDIT_DIR .. "panels/trigger_panel.lua")
    VFS.Include(SCENEDIT_DIR .. "panels/team_panel.lua")
    VFS.Include(SCENEDIT_DIR .. "panels/type_panel.lua")
    VFS.Include(SCENEDIT_DIR .. "panels/numeric_panel.lua")
    
    VFS.Include(SCENEDIT_DIR .. "util.lua")

    model = Model:New()

    reloadGadgets() --uncomment for development

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
        height = B_HEIGHT + 20,
        width = B_HEIGHT + 20,
        children = {
            Image:New { 
                tooltip = "Trigger settings", 
                file=SCENEDIT_IMG_DIR .. "applications-system.png", 
                height = B_HEIGHT - 2, 
                width = B_HEIGHT - 2,
            },
        },
    }
    local btnVariableSettings = Button:New {
        height = B_HEIGHT + 20,
        width = B_HEIGHT + 20,
        caption = '',
        children = {
            Image:New { 
                tooltip = "Variable settings", 
                file=SCENEDIT_IMG_DIR .. "format-text-bold.png", 
                height = B_HEIGHT - 2, 
                width = B_HEIGHT - 2, 
                margin = {0, 0, 0, 0},
            },
        },
    }


    toolboxWindow = Window:New {
        x = 500,
        y = 500,
        width = 300,
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
                        height = B_HEIGHT + 20,
                        width = B_HEIGHT + 20,
                        caption = '',
                        OnClick = {AddRectButton},
                        children = {
                            Image:New { 
                                tooltip = "Add a rectangle area", 
                                file=SCENEDIT_IMG_DIR .. "view-fullscreen.png", 
                                height = B_HEIGHT - 2, 
                                width = B_HEIGHT - 2, 
                                margin = {0, 0, 0, 0},
                            },
                        },
                    },
                    Button:New {
                        height = B_HEIGHT + 20,
                        width = B_HEIGHT + 20,
                        caption = '',
                        OnClick = {Save},
                        children = {
                            Image:New { 
                                tooltip = "Save mission", 
                                file=SCENEDIT_IMG_DIR .. "document-save.png", 
                                height = B_HEIGHT - 2, 
                                width = B_HEIGHT - 2, 
                                margin = {0, 0, 0, 0},
                            },
                        },
                    },
                    Button:New {
                        height = B_HEIGHT + 20,
                        width = B_HEIGHT + 20,
                        caption = '',
                        OnClick = {Load},
                        children = {
                            Image:New { 
                                tooltip = "Load mission", 
                                file=SCENEDIT_IMG_DIR .. "document-open.png", 
                                height = B_HEIGHT - 2, 
                                width = B_HEIGHT - 2, 
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
            end)
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
            end)
        end
    }
    unitImages =
        UnitDefsView:New {
            name='units',
            x = 0,
            right = 20,
            OnSelectItem = {
                function(obj,itemIdx,selected)
                    if selected and itemIdx > 0 then
                        if State.mouse == "none" then
                            State.mouse = 'addUnit'
                            selUnitDef = unitImages.items[itemIdx].id
                        elseif State.mouse == "selType" then
                            selUnitDef = unitImages.items[itemIdx].id
                            CallListeners(btnSelectType.OnSelectUnitType, selUnitDef)
                            State.mouse = "none"
                        end
                    end
                end,
            },
        }
    local playerNames, playerTeamIds = GetTeams()
    local teamsCmb = ComboBox:New {
        bottom = 1,
        height = B_HEIGHT,
        items = playerNames,
        playerTeamIds = playerTeamIds,
        x = 100,
        width=120,
    }
    teamsCmb.OnSelectItem = {
        function (obj, itemIdx, selected) 
            if selected then
                unitImages:SelectTeamId(playerTeamIds[itemIdx])
            end
        end
    }
    teamsCmb:SelectItem(1)

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
                bottom = C_HEIGHT * 4,
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
                height = B_HEIGHT,
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
                height = B_HEIGHT,
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
                height = B_HEIGHT,
                OnMouseDown = { function() echo("clicked") end },
            },
            EditBox:New {
                text = "text",
                width = 100,
                x = 150,
                y = 30,
                height = B_HEIGHT,
                OnMouseDown = { function() echo("clicked") end },
            },
        },
    }
    eb = testWindow.children[1]
    eb.OnClick = { function() echo(eb.x, eb.y, eb.width, eb.height) end }
    
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

function widget:DrawWorld()
    DrawRects()
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
    elseif State.mouse == "selUnit" then
        if button == 1 then
            local result, unitId = Spring.TraceScreenRay(x, y)
            if result == "unit"  then
                CallListeners(btnSelectUnit.OnSelectUnit, unitId)
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
                Model:MoveUnit(unitId, unitX + deltaX, unitY, unitZ + deltaZ)
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
end
