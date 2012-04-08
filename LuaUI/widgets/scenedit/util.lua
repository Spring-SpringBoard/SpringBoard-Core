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