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
	-- verify unnamed objects
	for i = 1, #data do
		local d = data[i]		
		if type(d) == "string" then
			d = {
				name = d,
				type = d,
			}
		end			
		if type(d) == "table" then
			local continue = true --lua has no continue and i don't want deep nesting
			if continue and not d.type then
				Spring.Echo("Error, missing type of data " .. d.type)
				continue = false
			end
			if continue and d.name == nil then
				d.name = d.type				
			end
			if continue then
				for j = 1, #newData do
					local d2 = newData[j]
					if d.name == d2.name then
						Spring.Echo("Error, name field is duplicate")
						continue = false
					end
				end
			end
			if continue	then
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
			execute = function (input)
				local unitType = input.unitType
				local area = input.area
				local team = input.team
				local x = (area[1] + area[3]) / 2				
				local z = (area[2] + area[4]) / 2
				local y = Spring.GetGroundHeight(x, z)												
				Spring.CreateUnit(unitType, x, y, z, 0, team.id)
				
				local color = SCEN_EDIT.rtModel.model.teams[team.id].color
				SCEN_EDIT.displayUtil:displayText("Spawned", {x, y, z}, color )
			end
		},
		{
			humanName = "Issue order", 
			name = "ISSUE_ORDER",
			input = { "unit", "order" },
			execute = function (input)
				table.echo(input)
				local orderTypeName = input.order.orderTypeName
				local newInput = {
					unit = input.unit,
					params = input.order.input,
				}
				SCEN_EDIT.rtModel.model.orderTypes[orderTypeName].execute(newInput)
			end
		},
		{
			humanName = "Remove unit", 
			name = "REMOVE_UNIT",
			input = { "unit" },
			execute = function (input)
				local unit = input.unit				
				local x, y, z = Spring.GetUnitPosition(unit)
				
				local color = SCEN_EDIT.rtModel.model.teams[Spring.GetUnitTeam(unit)].color				
				Spring.DestroyUnit(unit, false, true)
				SCEN_EDIT.displayUtil:displayText("Removed", {x, y, z}, color)
			end
		},
		{
			humanName = "Move unit", 
			name = "MOVE_UNIT",
			input = { "unit", "area" },
			execute = function (input)
				local unit = input.unit
				local area = input.area
				local x = (area[1] + area[3]) / 2
				local y = 0
				local z = (area[2] + area[4]) / 2
				Spring.SetUnitPosition(unit, x, y, z)
				Spring.GiveOrderToUnit(unit, CMD.STOP, {}, {})
			end
		},
		{
			humanName = "Transfer unit", 
			name = "TRANSFER_UNIT",
			input = { "unit", "team" },
			execute = function (input)
				local unit = input.unit
				local team = input.team
				Spring.TransferUnit(unit, team, false)
			end
		},
		{
			humanName = "Enable trigger", 
			name = "ENABLE_TRIGGER",
			input = { "trigger" },
			execute = function (input)
				local trigger = input.trigger
				trigger.enabled = true
			end
		},
		{
			humanName = "Disable trigger",
			name = "DISABLE_TRIGGER",
			input = { "trigger" },
			execute = function (input)
				local trigger = input.trigger
				trigger.enabled = false
			end
		},
		--TODO.. variables, yeah..
		{
			humanName = "Assign variable",
			name = "VARIABLE_ASSIGN",
			input = { 
				{
					name = "variable",
					variable = "true",
					type = "unit",
				},
			}
		},
	}
end

function SCEN_EDIT.coreOrders()
	return {
		{
			humanName = "Move to area",
			name = "MOVE_AREA",
			input = { "area" },
			execute = function(input)
				table.echo(input)
				local unit = input.unit
				local area = input.params.area
				local x = (area[1] + area[3]) / 2
				local y = 0
				local z = (area[2] + area[4]) / 2
				
				Spring.Echo(unit)
				Spring.GiveOrderToUnit(unit, CMD.MOVE, { x, y, z }, {})
			end,
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
			execute = function(input)
			end,
		},
	}
end

function SCEN_EDIT.coreConditions()
	local conditions = {}
	local coreTypes = SCEN_EDIT.coreTypes()
	local blackList = { numericComparison = true, identityComparison = true, trigger = true, order = true }
	for i = 1, #coreTypes do
		local coreType = coreTypes[i]		
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
				execute = function(input) 
					local first = input.first
					local second = input.second
					local relation = input.relation
					if relation == "is" or relation == "is not" then
						local isSame = false
						if coreType ~= "area" then
							isSame = first == second
						else
							isSame = first[1] == second[1] and first[2] == second[2] and
								first[3] == second[3] and first[4] == second[4]
						end
						return isSame == (relation == "is")
					end
				end,
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
	
	local arrayTypes = {}
	for i = 1, #coreTypes do
		local coreType = coreTypes[i]
		local arrayType = coreType .. "_array"
		local itemFromArray = {
			humanName = coreType .. " in array at position",
			name = arrayType .. "_indexing",
			input = { arrayType, "number" },
			output = coreType,			
		}
		table.insert(conditions, itemFromArray)
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
	elseif input:find("_array") then
		return GenericArrayPanel(parent, input)
	end
	Spring.Echo("No panel for this input: " .. tostring(input))
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