local Chili = WG.Chili

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

function PassToGadget(tag, data)
	newTable = { tag = tag, data = data }
	local msg = "scenedit|table" .. table.show(newTable)	
	Spring.SendLuaRulesMsg(msg)
end