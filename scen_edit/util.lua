SCEN_EDIT.classes = {}
-- include this dir
SCEN_EDIT.classes[SCEN_EDIT_DIR .. "util.lua"] = true

function MakeComponentPanel(parentPanel)
    local componentPanel = Control:New {
        parent = parentPanel,
        width = "100%",
        height = SCEN_EDIT.conf.B_HEIGHT + 8,
        orientation = "horizontal",
        padding = {0, 0, 0, 0},
        itemMarging = {0, 0, 0, 0},
        margin = { 0, 0, 0, 0},
        resizeItems = false,
    }
    return componentPanel
end

--non recursive file include
function SCEN_EDIT.IncludeDir(dirPath)
    local files = VFS.DirList(dirPath)
    local context = Script.GetName()
    for i = 1, #files do
        local file = files[i]
        -- don't load files ending in _gadget.lua in LuaUI nor _widget.lua in LuaRules
        if file:sub(-string.len(".lua")) == ".lua" and 
            (context ~= "LuaRules" or file:sub(-string.len("_widget.lua")) ~= "_widget.lua") and
            (context ~= "LuaUI" or file:sub(-string.len("_gadget.lua")) ~= "_gadget.lua") then

            SCEN_EDIT.Include(file)
        end
    end
end

function SCEN_EDIT.Include(path)
    if not SCEN_EDIT.classes[path] then
        VFS.Include(path)
        SCEN_EDIT.classes[path] = true
    end
end

function SCEN_EDIT.ZlibCompress(str)
    return tostring(#str) .. "|" .. VFS.ZlibCompress(str)
end

function SCEN_EDIT.ZlibDecompress(str)
    local compressedSize = 0
    local strStart = 0
    for i = 1, #str do
        local substr = str:sub(1, i)
        if str:sub(i,i) == '|' then
            compressedSize = tonumber(str:sub(1, i - 1))
            strStart = i + 1
            break
        end
    end
    if compressedSize == 0 then
        error("string is not of valid format")
    end
    return VFS.ZlibDecompress(str:sub(strStart, #str), compressedSize)
end

function CallListeners(listeners, ...)
    for i = 1, #listeners do
        local listener = listeners[i]
        listener(...)
    end
end

function SCEN_EDIT.MakeConfirmButton(dialog, btnConfirm)
    dialog.OnConfirm = {}
    btnConfirm.OnClick = {
        function()
            CallListeners(dialog.OnConfirm)
            dialog:Dispose()
        end
    }
end

function SCEN_EDIT.MakeRadioButtonGroup(checkBoxes)
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

function SCEN_EDIT.checkAreaIntersections(x, z)
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

function SCEN_EDIT.SetMouseCursor(name)
    SCEN_EDIT.cursor = name
    if SCEN_EDIT.cursor then
        Spring.SetMouseCursor(SCEN_EDIT.cursor)
    end
end

function SCEN_EDIT.MakeSeparator(panel)
    local lblSeparator = Label:New {
        parent = panel,
        height = SCEN_EDIT.conf.B_HEIGHT + 10,
        caption = "===================================",
        align = 'center',
    }
    return lblSeparator
end


function SCEN_EDIT.CreateNameMapping(origArray)
    local newArray = {}
    for i = 1, #origArray do
        local item = origArray[i]
        newArray[item.name] = item
    end
    return newArray
end

function SCEN_EDIT.GroupByField(origArray, field)
    local newArray = {}
    for i = 1, #origArray do
        local item = origArray[i]
        local fieldValue = item[field]
        if newArray[fieldValue] then
            table.insert(newArray[fieldValue], item)
        else
            newArray[fieldValue] = { item }
        end
    end
    return newArray
end

function SCEN_EDIT.AddExpression(dataType, parent)
    local viableExpressions = SCEN_EDIT.metaModel.functionTypesByOutput[dataType]
    if viableExpressions then
        local stackPanel = MakeComponentPanel(parent)
        local cbExpressions = Checkbox:New {
            caption = "Expression: ",
            right = 100 + 10,
            x = 1,
            checked = false,
            parent = stackPanel,
        }
        local btnExpressions = Button:New {
            caption = 'Expression',
            right = 1,
            width = 100,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackPanel,
            data = {},
        }
        btnExpressions.OnClick = {
            function()
                local mode = 'add'
                if #btnExpressions.data > 0 then
                    mode = 'edit'
                end
                local newActionWindow = CustomWindow:New {
                    parent = parent.parent.parent.parent,
                    mode = mode,
                    dataType = dataType,
                    parentWindow = parent.parent.parent,
                    parentObj = btnExpressions.data,
                    condition = btnExpressions.data[1], --nil if mode ~= 'edit'
                    cbExpressions = cbExpressions,
                }
            end
        }
        return cbExpressions, btnExpressions
    end    
    return nil, nil
end


function MakeVariableChoice(variableType, panel)
    local variablesOfType = SCEN_EDIT.model.variableManager:getVariablesOfType(variableType)
    if not variablesOfType then
        return nil, nil
    end
    local variableNames = {}
    local variableIds = {}
    for id, variable in pairs(variablesOfType) do
        table.insert(variableNames, variable.name)
        table.insert(variableIds, id)
    end

    if #variableIds > 0 then
        local stackPanel = MakeComponentPanel(panel)
        local cbVariable = Checkbox:New {
            caption = "Variable: ",
            right = 100 + 10,
            x = 1,
            checked = false,
            parent = stackPanel,
        }
        
        local cmbVariable = ComboBox:New {
            right = 1,        
            width = 100,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackPanel,
            items = variableNames,
            variableIds = variableIds,
        }
        cmbVariable.OnSelect = {
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

function GetField(origArray, field)
    local newArray = {}
    for k, v in pairs(origArray) do
        table.insert(newArray, v[field])
    end
    return newArray
end

function GetIndex(table, value)
    for i = 1, #table do
        if table[i] == value then
            return i
        end
    end
end

function SortByName(t, name)
    local i = 1
    local sortedTable = {}
    for k, v in pairs(t) do
        sortedTable[i] = v
        i = i + 1
    end
    table.sort(sortedTable,
        function(a, b)
            return a[name] < b[name]
        end
    )
    return sortedTable
end

function PassToGadget(prefix, tag, data)
    newTable = { tag = tag, data = data }
    local msg = prefix .. "|table" .. table.show(newTable)    
    Spring.SendLuaRulesMsg(msg)
end

function SCEN_EDIT.humanExpression(data, exprType, dataType)
    if exprType == "condition" then
        if data.conditionTypeName:find("compare_") then
            local firstExpr = SCEN_EDIT.humanExpression(data.first, "value")
            local relation
            if data.conditionTypeName == "compare_number" then
                relation = SCEN_EDIT.humanExpression(data.relation, "identity_comparison")
            else
                relation = SCEN_EDIT.humanExpression(data.relation, "numeric_comparison")
            end
            local secondExpr = SCEN_EDIT.humanExpression(data.second, "value")
            local condHumanName = SCEN_EDIT.metaModel.functionTypes[data.conditionTypeName].humanName
            return condHumanName .. " (" .. firstExpr .. " " .. relation .. " " .. secondExpr .. ")"
        end
    elseif exprType == "action" then
        local action = SCEN_EDIT.metaModel.actionTypes[data.actionTypeName]
        local humanName = action.humanName .. " ("
        for i = 1, #action.input do
            local input = action.input[i]
            humanName = humanName .. SCEN_EDIT.humanExpression(data[input.name], "value")
            if i ~= #action.input then
                humanName = humanName .. ", "
            end
        end
        return humanName .. ")"
    elseif exprType == "value" then 
        if data.type == "pred" then
            if dataType == "unitType" then
                local unitDef = UnitDefs[data.id]
                if unitDef then
                    return tostring(unitDef.name)
                else
                    return tostring(data.id)
                end
            elseif dataType == "unit" then
                local unitId = SCEN_EDIT.model.unitManager:getSpringUnitId(data.id)
                if Spring.ValidUnitID(unitId) then
                    local unitDef = UnitDefs[Spring.GetUnitDefID(unitId)]
                    if unitDef then
                        return tostring(unitDef.name)
                    else
                        return tostring(data.id)
                    end
                else
                    return tostring(data.id)
                end
            elseif dataType == "trigger" or dataType == "variable" then
                return data.name
            else
                return tostring(data.id)
            end
        elseif data.type == "spec" then
            return data.name
        elseif data.type == "expr" then
            -- TODO
        elseif data.orderTypeName then
            local orderType = SCEN_EDIT.metaModel.orderTypes[data.orderTypeName]
            local humanName = orderType.humanName
            for i = 1, #orderType.input do
                local input = orderType.input[i]
                humanName = humanName .. SCEN_EDIT.humanExpression(data[input.name], "value") .. " "
            end
            return humanName
        end
        return "nothing"
    elseif exprType == "numeric_comparison" then
        return SCEN_EDIT.metaModel.numericComparisonTypes[data.cmpTypeId]
    elseif exprType == "identity_comparison" then
        return SCEN_EDIT.metaModel.identityComparisonTypes[data.cmpTypeId]
    end
    return data.humanName
end

function SCEN_EDIT.GenerateTeamColor()
    return 1, 1, 1, 1 --yeah, ain't it great
end

function SCEN_EDIT.GetTeams(widget)
    local playerNames = {}
    local playerTeamIds = {}
    local playerColors = {}
    
    local teamIds = Spring.GetTeamList()
    
    for i = 1, #teamIds do
        local id, _, _, name = Spring.GetAIInfo(teamIds[i])
        table.insert(playerTeamIds, teamIds[i])
        local teamName = tostring(teamIds[i])
        if id ~= nil then
            teamName = teamName .. ": " .. name
        end
        table.insert(playerNames, teamName)

        local r, g, b, a = SCEN_EDIT.GenerateTeamColor()--Spring.GetTeamColor(teamIds[i])
        if widget then
            r, g, b, a = Spring.GetTeamColor(teamIds[i])
        end
        local color = { r = r, g = g, b = b, a = a }
        table.insert(playerColors, color)
    end
    return playerNames, playerTeamIds, playerColors
end

function SCEN_EDIT.Error(msg)
    Spring.Echo(msg)
end

function SCEN_EDIT.SetClassName(class, className)
    class.className = className
    if SCEN_EDIT.commandManager:getCommandType(className) == nil then
        SCEN_EDIT.commandManager:addCommandType(className, class)
    end
end

function SCEN_EDIT.resolveCommand(cmdTable)
    local cmd = {}
    if cmdTable.className then
        local env = getfenv(1)
        cmd = env[cmdTable.className]()
    end
    for k, v in pairs(cmdTable) do
        if type(v) == "table" then
            cmd[k] = SCEN_EDIT.resolveCommand(v)
        else
            cmd[k] = v
        end
    end--[[
    if cmd.className == "CompoundCommand" then
        for i = 1, #cmd.commands do
            cmd.commands[i] = SCEN_EDIT.resolveCommand(cmd.commands[i])
        end
    end--]]
    return cmd
end

function SCEN_EDIT.deepcopy(t)
    if type(t) ~= 'table' then return t end
    local mt = getmetatable(t)
    local res = {}
    for k,v in pairs(t) do
        if type(v) == 'table' then
            v = SCEN_EDIT.deepcopy(v)
        end
        res[k] = v
    end
    setmetatable(res,mt)
    return res
end

function SCEN_EDIT.GiveOrderToUnit(unitId, orderType, params)
    Spring.GiveOrderToUnit(unit, CMD.INSERT,
        { -1, orderType, CMD.OPT_SHIFT, unpack(params) }, { "alt" })
end

function SCEN_EDIT.createNewPanel(input, parent)
    if input == "unit" then
        return UnitPanel:New {
            parent = parent,
        }
    elseif input == "area" then
        return AreaPanel:New {
            parent = parent,
        }
    elseif input == "trigger" then                    
        return TriggerPanel:New {
            parent = parent,
        }
    elseif input == "unitType" then
        return UnitTypePanel:New {
            parent = parent,
        }
    elseif input == "team" then
        return TeamPanel:New {
            parent = parent,
        }
    elseif input == "number" then
        return NumberPanel:New {
            parent = parent,
        }
    elseif input == "string" then
        return StringPanel:New {
            parent = parent,
        }
    elseif input == "bool" then
        return BoolPanel:New {
            parent = parent,
        }
    elseif input == "numericComparison" then
        return NumericComparisonPanel:New {
            parent = parent,
        }
    elseif input == "order" then
        return OrderPanel:New {
            parent = parent,
        }
    elseif input == "identityComparison" then
        return IdentityComparisonPanel:New {
            parent = parent,
        }
    elseif input:find("_array") then
        return GenericArrayPanel(parent, input)
    end
    Spring.Echo("No panel for this input: " .. tostring(input))
end

SCEN_EDIT.delayedGL = {}
function SCEN_EDIT.delayGL(func, params)
    table.insert(SCEN_EDIT.delayedGL, {func, params or {}})
end

function SCEN_EDIT.executeDelayed()
    for i = 1, #SCEN_EDIT.delayedGL do
        call = SCEN_EDIT.delayedGL[i]
        success, msg = pcall(call[1], unpack(call[2]))
        if not success then
            Spring.Echo(msg)
        end
    end
    SCEN_EDIT.delayedGL = {}
end
