local Chili = nil
if WG ~= nil then
	Chili= WG.Chili
end

function CallListeners(listeners, ...)
    for i = 1, #listeners do
        local listener = listeners[i]
        listener(...)
    end
end

function MakeConfirmButton(dialog, btnConfirm)
    dialog.OnConfirm = {}
    btnConfirm.OnClick = {
        function()
            CallListeners(dialog.OnConfirm)
            dialog:Dispose()
        end
    }
end

function CreateNameMapping(origArray)
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
	local viableExpressions = SCEN_EDIT.model.conditionTypesByOutput[dataType]
	if viableExpressions then
		local stackPanel = MakeComponentPanel(parent)
		local cbExpressions = Chili.Checkbox:New {
            caption = "Expression: ",
            right = 100 + 10,
            x = 1,
            checked = false,
            parent = stackPanel,
        }
		local btnExpressions = Chili.Button:New {
			caption = 'Expression',
			right = 1,
			width = 100,
			height = SCEN_EDIT.model.B_HEIGHT,
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
    for i = 1, #variablesOfType do
        local variable = variablesOfType[i]
		table.insert(variableNames, variable.name)
		table.insert(variableIds, variable.id)
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
            height = SCEN_EDIT.model.B_HEIGHT,
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

function PassToGadget(prefix, tag, data)
	newTable = { tag = tag, data = data }
	local msg = prefix .. "|table" .. table.show(newTable)	
	Spring.SendLuaRulesMsg(msg)
end

function SCEN_EDIT.humanExpression(data, exprType)
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
			local condHumanName = SCEN_EDIT.model.conditionTypes[data.conditionTypeName].humanName
			return condHumanName .. " (" .. firstExpr .. " " .. relation .. " " .. secondExpr .. ")"
		end
	elseif exprType == "action" then
		local action = SCEN_EDIT.model.actionTypes[data.actionTypeName]
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
			return tostring(data.id)
		elseif data.type == "spec" then
			return data.name
		elseif data.type == "expr" then
			-- TODO
        elseif data.orderTypeName then
            local orderType = SCEN_EDIT.model.orderTypes[data.orderTypeName]
            local humanName = orderType.humanName
            for i = 1, #orderType.input do
                local input = orderType.input[i]
                humanName = humanName .. SCEN_EDIT.humanExpression(data[input.name], "value") .. " "
            end
            return humanName
        end
		return "nothing"
	elseif exprType == "numeric_comparison" then
		return SCEN_EDIT.model.numericComparisonTypes[data.cmpTypeId]
	elseif exprType == "identity_comparison" then
		return SCEN_EDIT.model.identityComparisonTypes[data.cmpTypeId]
	end
	return data.humanName
end

function GenerateTeamColor()
    return 1, 1, 1, 1 --yeah, ain't it great
end

function GetTeams()
    local playerNames = {}
    local playerTeamIds = {}
	local playerColors = {}
	
    local teamIds = Spring.GetTeamList()
	
    for i = 1, #teamIds do
        local id, _, _, name = Spring.GetAIInfo(teamIds[i])
		table.insert(playerTeamIds, teamIds[i])
		local teamName = "Team " .. teamIds[i]
        if id ~= nil then
            teamName = teamName .. ": " .. name
		end
		table.insert(playerNames, teamName)
		local r, g, b, a = GenerateTeamColor()--Spring.GetTeamColor(teamIds[i])
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
--    Spring.Echo(cmdTable.className)
    local cmd = WidgetAddAreaCommand()
    cmd = "return " .. cmdTable.className
    env = getfenv(1)
    local cmd = env[cmdTable.className]()
--    local cmd = loadstring("return " .. cmdTable.className)()
--    local cmd = _G[cmdTable.className]()
    for k, v in pairs(cmdTable) do
        if type(v) == "table" and v.className ~= nil then
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

