function SCEN_EDIT.coreTypes()
	return {
		"unit",
		"unitType",
		"team",
		"area",
		"order",
		"trigger",
		"bool",
		"string",
		"number",
		"numericComparison",
		"identityComparison",
	}
end

function SCEN_EDIT.parseData(data)
	local newData = {}
	local dataTypes = {}
	-- verify unnamed objects
	for i = 1, #data do
		local d = data[i]		
		if type(d) == "string" then
			if dataTypes[d] ~= nil then
				Spring.Echo("Warning, two data of same type present without being named")
			else
				table.insert(newData, 
					{
						name = d,
						type = d,
					}
				)
				dataTypes[d] = d
			end
		elseif type(d) == "table" then
			if not d.name then
				Spring.Echo("Warning, missing name of data ")
			elseif not d.type then
				Spring.Echo("Warning, missing type of data " .. d.type)
			else
				table.insert(newData, d)
			end
		else
			Spring.Echo("Unexpected data " .. d .. " of type " .. type(d))
		end		
	end
	-- verify named objects
	local finalData = {}
	local dataNames = {}
	for i = 1, #newData do
		local d = newData[i]
		if dataNames[d.name] then
			Spring.Echo("Data of name " .. d.name .. " already exists ")
		else
			table.insert(finalData, d)
		end
	end
	return finalData
end

function SCEN_EDIT.coreActions()
	return {
		{
			humanName = "Spawn unit", 
			name = "SPAWN_UNIT",
			input = { "unitType", "team", "area" },
		},
		{
			humanName = "Issue order", 
			name = "ISSUE_ORDER",
			input = { "unit", "order" },
		},
		{
			humanName = "Destroy unit", 
			name = "DESTROY_UNIT",
			input = { "unit" },
		},
		{
			humanName = "Move unit", 
			name = "MOVE_UNIT",
			input = { "unit", "area" },
		},
		{
			humanName = "Transfer unit", 
			name = "TRANSFER_UNIT",
			input = { "unit", "team" },
		},
		{
			humanName = "Enable trigger", 
			name = "ENABLE_TRIGGER",
			input = { "trigger" },
		},
		{
			humanName = "Disable trigger",
			name = "DISABLE_TRIGGER",
			input = { "trigger" },
		},
	}
end

function SCEN_EDIT.coreOrders()
	return {
		{
			humanName = "Move to area",
			name = "MOVE_AREA",
			input = { "area" },
		},
		{
			humanName = "Attack unit",
			name = "ATTACK_UNIT",
			input = {				
				{
					name = "target",
					type = "unit",
					humanName = "Target unit",
				},
			},
		},
	}
end

function SCEN_EDIT.coreConditions()
	local conditions = {}
	local coreTypes = SCEN_EDIT.coreTypes()
	for i = 1, #coreTypes do
		local coreType = coreTypes[i]
		local blackList = { numericComparison = true, identityComparison = true, trigger = true, order = true }
		if not blackList[coreType] then
			local relType
			if coreType == "number" then
				relType = "numericComparison"
			else
				relType = "identityComparison"
			end
			local compareCond = {
				humanName = "Compare " .. coreType,
				name = "compare_" .. coreType,
				input = {
					{
						name = "first",
						type = coreType,
					},
					{
						name = "relation",
						type = relType,
					},
					{
						name = "second",
						type = coreType,
					},
				},
				output = "bool",
			}
			table.insert(conditions, compareCond)
		end
	end
	local coreTransforms = SCEN_EDIT.coreTransforms()	
	for i = 1, #coreTransforms do
		local coreTransform = coreTransforms[i]
		table.insert(conditions, coreTransform)
	end
	return conditions
end

function SCEN_EDIT.coreTransforms()
	return {
		{
			humanName = "Unit type",
			name = "unitType",
			input = { "unit" },
			output = "unitType",			
		},
		{
			humanName = "Unit team",
			name = "unitTeam",
			input = { "unit" },
			output = "team",			
		},
		{
			humanName = "Unit HP",
			name = "unitHp",
			input = { "unit" },
			output = "number",			
		},
		{
			humanName = "Unit HP%",
			name = "unitHP%",
			input = { "unit" },
			output = "number",			
		},
	}
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
		return TypePanel:New {
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
	end
	Spring.Echo("No panel for this input: " .. input)
end

function SCEN_EDIT.complexExpressions()
	expressions = {}
	average = {
		inputClass = "complex",
		basicExpression = "number",
		output = "number",
		text = "Average",	
	}
	table.insert(expressions, average)
	return expressions
end