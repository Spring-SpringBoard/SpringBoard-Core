return {
    actions = function()
        local variableAssignments = {}
        allTypes = SCEN_EDIT.coreTypes()
        for i = 1, #allTypes do
            local type = allTypes[i]

            if type.canBeVariable ~= false then
                local variableAssignment = {
                    humanName = "Assign " .. type.humanName,
                    name = type.name .. "_VARIABLE_ASSIGN",
                    tags = {"Variable"},
                    input = { 
                        {
                            name = "variable",
                            rawVariable = "true",
                            sources = "variable",
                            type = type.name,
                        },
                        {
                            name = type.name,
                            type = type.name,
                        },
                    },
                    execute = function(input)
                        --local unitModelId = SCEN_EDIT.model.unitManager:getModelUnitId(input.unit)
                        local newValue = SCEN_EDIT.deepcopy(input.variable)
                        newValue.value.id = input[type.name]
                        SCEN_EDIT.model.variableManager:setVariable(input.variable.id, newValue)

                        --local array = input[arrayType]
                        --local index = input.number
                        --return array[index]
                    end,
                }

                table.insert(variableAssignments, variableAssignment)

                local arrayType = type.name .. "_array"
                local addToArray = {
                    humanName = "Add to " .. arrayType,
                    name = "ADD_TO" .. arrayType,
                    tags = {"Variable"},
                    input = { 
                        {
                            name = "variable",
                            rawVariable = "true",
                            sources = "variable",
                            type = arrayType,
                        },
                        {
                            name = type.name,
                            type = type.name,
                        },
                    },
                    execute = function(input)
                        table.insert(input.variable, input[type.name])
                    end,
                }
                table.insert(variableAssignments, addToArray)
                local removeFromArray = {
                    humanName = "Remove from " .. arrayType,
                    name = arrayType .. "_REMOVE",
                    tags = {"Variable"},
                    input = { 
                        {
                            name = "array",
                            rawVariable = "true",
                            sources = "variable",
                            type = arrayType,
                        },
                        {
                            name = "index",
                            type = "number",
                        },
                    },
                    execute = function(input)
                        table.remove(input.array, input.index)
                    end,
                }
                table.insert(variableAssignments, removeFromArray)
            end
        end

        return {
            {
                humanName = "Enable trigger", 
                name = "ENABLE_TRIGGER",
                input = { "trigger" },
                tags = {"Trigger"},
                execute = function (input)
                    local trigger = input.trigger
                    SCEN_EDIT.model.triggerManager:enableTrigger(trigger.id)
                end
            },
            {
                humanName = "Disable trigger",
                name = "DISABLE_TRIGGER",
                input = { "trigger" },
                tags = {"Trigger"},
                execute = function (input)
                    local trigger = input.trigger
                    SCEN_EDIT.model.triggerManager:disableTrigger(trigger.id)
                end
            },
            {
                humanName = "Save checkpoint",
                name = "SAVE_CHECKPOINT",
                tags = {"Other"},
                execute = function (input)
                    SCEN_EDIT.savedModel = SCEN_EDIT.model:Serialize()
                end
            },
            {
                humanName = "Load checkpoint",
                name = "LOAD_CHECKPOINT",
                tags = {"Other"},
                execute = function (input)
                    if SCEN_EDIT.savedModel ~= nil then
                        SCEN_EDIT.model:Load(SCEN_EDIT.savedModel)
                    else
                        Spring.Log("Scened", LOG.ERROR, "There's no checkpoint to load from")
                    end
                end
            },
            {
                humanName = "Kill team", 
                name = "KILL_TEAM",
                input = "team",
                tags = {"Game"},
                execute = function (input)
                    Spring.KillTeam(input.team)
                end
            },
            {
                humanName = "Win game", 
                name = "WIN_GAME",
                input = "team_array",
                tags = {"Game"},
                execute = function (input)
                    local allyTeamsMap = {}
                    for _, team in pairs(input.team_array) do
                        local _, _, _, _, _, allyTeam = Spring.GetTeamInfo(team)
                        allyTeamsMap[allyTeam] = true
                    end
                    local allyTeams = {}
                    for allyTeam, _ in pairs(allyTeamsMap) do
                        table.insert(allyTeams, allyTeam)
                    end
                    Spring.GameOver(allyTeams)
                end
            },
            {
                humanName = "Lose game", 
                name = "LOSE_GAME",
                tags = {"Game"},
                execute = function (input)
                    Spring.GameOver()
                end
            },
            {
                humanName = "Add resources", 
                name = "ADD_TEAM_RESOURCES",
                input = {"team", "string", "number"},
                tags = {"Resources"},
                execute = function (input)
                    Spring.AddTeamResources(input.team, input.string, input.number)
                end
            },
            {
                humanName = "Remove resources", 
                name = "REMOVE_TEAM_RESOURCES",
                input = {"team", "string", "number"},
                tags = {"Resources"},
                execute = function (input)
                    Spring.UseTeamResources(input.team, input.string, input.number)
                end
            },
            {
                humanName = "Set team resources", 
                name = "SET_TEAM_RESOURCES",
                input = {"team", "string", "number"},
                tags = {"Resources"},
                execute = function (input)
                    Spring.SetTeamResources(input.team, input.string, input.number)
                end
            },
            {
                humanName = "Make allied", 
                name = "MAKE_ALLIED",
                input = { 
                    {
                        name = "team1", 
                        type = "team",
                    },
                    {
                        name = "team2", 
                        type = "team",
                    },
                },
                tags = {"Alliance"},
                execute = function (input)
                    local _, _, _, _, _, allyTeam1 = Spring.GetTeamInfo(input.team1)
                    local _, _, _, _, _, allyTeam2 = Spring.GetTeamInfo(input.team2)
                    Spring.SetAlly(allyTeam1, allyTeam2, true)
                end
            },
            {
                humanName = "Make enemies", 
                name = "MAKE_ENEMIES",
                input = { 
                    {
                        name = "team1", 
                        type = "team",
                    },
                    {
                        name = "team2", 
                        type = "team",
                    },
                },
                tags = {"Alliance"},
                execute = function (input)
                    local _, _, _, _, _, allyTeam1 = Spring.GetTeamInfo(input.team1)
                    local _, _, _, _, _, allyTeam2 = Spring.GetTeamInfo(input.team2)
                    Spring.SetAlly(allyTeam1, allyTeam2, false)
                end
            },
            {
                humanName = "Create unit", 
                name = "CREATE_UNIT",
                input = { "unitType", "team", "position" },
                tags = {"Unit"},
                execute = function (input)
                    local unitType = input.unitType
                    local team = input.team
                    local x = input.position.x
                    local z = input.position.z
                    local y = Spring.GetGroundHeight(x, z)                                                
                    local id = Spring.CreateUnit(unitType, x, y, z, 0, team)

                    local color = SCEN_EDIT.model.teamManager:getTeam(team).color
                    SCEN_EDIT.displayUtil:displayText("Spawned", {x, y, z}, color )
                end
            },
            {
                humanName = "Remove unit", 
                name = "REMOVE_UNIT",
                input = { "unit" },
                tags = {"Unit"},
                execute = function (input)
                    local unit = input.unit                
                    local x, y, z = Spring.GetUnitPosition(unit)

                    local color = SCEN_EDIT.model.teamManager:getTeam(Spring.GetUnitTeam(unit)).color
                    Spring.DestroyUnit(unit, false, true)
                    SCEN_EDIT.displayUtil:displayText("Removed", {x, y, z}, color)
                end
            },
            {
                humanName = "Destroy unit", 
                name = "DESTROY_UNIT",
                input = { "unit" },
                tags = {"Unit"},
                execute = function (input)
                    local unit = input.unit                
                    local x, y, z = Spring.GetUnitPosition(unit)

                    local color = SCEN_EDIT.model.teamManager:getTeam(Spring.GetUnitTeam(unit)).color
                    Spring.DestroyUnit(unit, false, false)
                    SCEN_EDIT.displayUtil:displayText("Destroyed", {x, y, z}, color)
                end
            },
            {
                humanName = "Self destruct unit", 
                name = "SELFD_UNIT",
                input = { "unit" },
                tags = {"Unit"},
                execute = function (input)
                    local unit = input.unit                
                    local x, y, z = Spring.GetUnitPosition(unit)

                    local color = SCEN_EDIT.model.teamManager:getTeam(Spring.GetUnitTeam(unit)).color
                    Spring.DestroyUnit(unit, true, false)
                    SCEN_EDIT.displayUtil:displayText("Self Destruct", {x, y, z}, color)
                end
            },
            {
                humanName = "Transfer unit", 
                name = "TRANSFER_UNIT",
                input = { "unit", "team" },
                tags = {"Unit"},
                execute = function (input)
                    local unit = input.unit
                    local team = input.team
                    Spring.TransferUnit(unit, team, false)
                end
            },
            {
                humanName = "Set unit health", 
                name = "SET_UNIT_HEALTH",
                input = { "unit", "number" },
                tags = {"Unit"},
                execute = function (input)
                    Spring.SetUnitHealth(input.unit, input.number)
                end
            },
            {
                humanName = "Set unit max health", 
                name = "SET_UNIT_MAX_HEALTH",
                input = { "unit", "number" },
                tags = {"Unit"},
                execute = function (input)
                    Spring.SetUnitMaxHealth(input.unit, input.number)
                end
            },
            {
                humanName = "Damage unit", 
                name = "DAMAGE_UNIT",
                input = { "unit", "number" },
                tags = {"Unit"},
                execute = function (input)
                    Spring.AddUnitDamage(input.unit, input.number)
                end
            },
            {
                humanName = "Set unit stockpile", 
                name = "SET_UNIT_STOCKPILE",
                input = { "unit", "number" },
                tags = {"Unit"},
                execute = function (input)
                    Spring.SetUnitStockpile(input.unit, input.number)
                end
            },
            {
                humanName = "Set unit target", 
                name = "SET_UNIT_TARGET",
                input = { 
                    {
                        name="unit",
                        type="unit", 
                    },
                    {
                        name="target",
                        type="unit", 
                    },
                },
                tags = {"Unit"},
                execute = function (input)                
                    Spring.SetUnitTarget(input.unit, input.target)
                end
            },
            {
                humanName = "Move unit", 
                name = "MOVE_UNIT",
                input = { "unit", "position" },
                tags = {"Unit"},
                execute = function (input)
                    local unit = input.unit
                    local position = input.position
                    local x, y, z = position.x, position.y, position.z
                    Spring.SetUnitPosition(unit, x, y, z)
                    Spring.GiveOrderToUnit(unit, CMD.STOP, {}, {})
                end
            },
            {
                humanName = "Send message", 
                name = "SEND_MESSAGE",
                input = "string",
                tags = {"Message"},
                execute = function (input)
                    Spring.SendMessage(input.string)
                end
            },
            {
                humanName = "Send message to team", 
                name = "SEND_MESSAGE_TEAM",
                input = { "string",  "team" },
                tags = {"Message"},
                execute = function (input)
                    Spring.SendMessageToTeam(input.team, input.string)
                end
            },
            {
                humanName = "Send message to spectators", 
                name = "SEND_MESSAGE_SPECTATORS",
                input = "string",
                tags = {"Message"},
                execute = function (input)
                    Spring.SendMessageToSpectators(input.string)
                end
            },
            {
                humanName = "Add Marker", 
                name = "MARKER_ADD_POINT",
                input = {"position", "string"},
                tags = {"Marker"},
                execute = function (input)
                    local position = input.position
                    local x = position.x
                    local y = position.y
                    local z = position.z
                    Spring.MarkerAddPoint(x, y, z, input.string)
                end
            },
            {
                humanName = "Play sound",
                name = "PLAY_SOUND_FILE",
                input = { "string" },
                tags = {"Sound"},
                execute = function (input)
                    Spring.PlaySoundStream(input.string)
                end
            },
            {
                humanName = "Select unit",
                name = "SELECT_UNIT",
                input = "unit",
                tags = {"Selection"},
                execute = function (input)
                    Spring.SelectUnitArray({input.unit})
                end
            },
            {
                humanName = "Select units",
                name = "SELECT_UNIT_ARRAY",
                input = "unit_array",
                tags = {"Selection"},
                execute = function (input)
                    Spring.SelectUnitArray(input.unit_array)
                end
            },
            {
                humanName = "Camera follow unit",
                name = "CAMERA_FOLLOW_UNIT",
                input = { "unit" },
                tags = { "Camera"},
                execute = function (input)
                    SCEN_EDIT.displayUtil:followUnit(input.unit)
                end
            },
            {
                humanName = "Camera target",
                name = "SET_CAMERA_TARGET",
                input = { "position" },
                tags = { "Camera"},
                execute = function (input)
                    local position = input.position
                    local x = position.x
                    local y = position.y
                    local z = position.z
                    Spring.SetCameraTarget(x, y, z)
                end
            },

            {
                humanName = "Issue order", 
                name = "ISSUE_ORDER",
                input = { "unit", "order" },
                tags = {"Order"},
                execute = function (input)
                    local orderTypeName = input.order.orderTypeName
                    local newInput = {
                        unit = input.unit,
                        params = input.order.input,
                    }

                    Spring.GiveOrderToUnit(input.unit, CMD.STOP, {}, {})
                    SCEN_EDIT.metaModel.orderTypes[orderTypeName].execute(newInput)
                    local x, y, z = Spring.GetUnitPosition(input.unit)
                    local color = SCEN_EDIT.model.teamManager:getTeam(Spring.GetUnitTeam(input.unit)).color
                    SCEN_EDIT.displayUtil:displayText("Issued order", {x, y, z}, color )
                end
            },
            {
                humanName = "Add order", 
                name = "ADD_ORDER",
                input = { "unit", "order" },
                tags = {"Order"},
                execute = function (input)
                    local orderTypeName = input.order.orderTypeName
                    local newInput = {
                        unit = input.unit,
                        params = input.order.input,
                    }

                    SCEN_EDIT.metaModel.orderTypes[orderTypeName].execute(newInput)
                    local x, y, z = Spring.GetUnitPosition(input.unit)
                    local color = SCEN_EDIT.model.teamManager:getTeam(Spring.GetUnitTeam(input.unit)).color
                    SCEN_EDIT.displayUtil:displayText("Added order", {x, y, z}, color )
                end
            },
            {
                humanName = "Issue order to units", 
                name = "ISSUE_ORDER_TO_UNITS",
                input = { "unit_array", "order" },
                tags = {"Order"},
                execute = function (input)
                    for i = 1, #input.unit_array do
                        local unit = input.unit_array[i]
                        local orderTypeName = input.order.orderTypeName
                        local newInput = {
                            unit = unit,
                            params = input.order.input,
                        }
                        SCEN_EDIT.metaModel.orderTypes[orderTypeName].execute(newInput)
                    end
                end
            },
            unpack(variableAssignments),
            --[[
            --TODO.. variables, yeah..
            {
            humanName = "Assign variable",
            name = "VARIABLE_ASSIGN",
            input = { 
            {
            name = "variable",
            rawVariable = "true",
            type = "unit",
            },
            {
            name = "unit",
            type = "unit"
            },
            },
            execute = function(input)
            local unitModelId = SCEN_EDIT.model.unitManager:getModelUnitId(input.unit)
            local newValue = SCEN_EDIT.deepcopy(input.variable)
            newValue.value.id = unitModelId
            SCEN_EDIT.model.variableManager:setVariable(variable.id, newValue)
            end,
            },--]]
        }
    end,

    functions = function()
        local functions = {}
        local coreTypes = SCEN_EDIT.coreTypes()
        local allTypes = coreTypes

        for i = 1, #allTypes do
            local basicType = allTypes[i]        
            if basicType.canCompare == nil or basicType.canCompare == true then
                local relType
                if basicType.name == "number" then
                    relType = "numericComparison"
                else
                    relType = "identityComparison"
                end
                local compareCond = {
                    humanName = "Compare " .. basicType.name,
                    name = "compare_" .. basicType.name,
                    tags = {"Compare"},
                    input = {
                        {
                            name = "first",
                            type = basicType.name,
                            allowNil = true,
                        },
                        {
                            name = "relation",
                            type = relType,
                        },
                        {
                            name = "second",
                            type = basicType.name,
                            allowNil = true,
                        },
                    },
                    execute = function(input) 
                        local first = input.first
                        local second = input.second
                        local relation = input.relation
                        if relation == "is" or relation == "is not" then
                            local isSame = false
                            -- note: we want nil to be ~= to nil
                            if first ~= nil and second ~= nil then
                                if basicType.name ~= "area" then
                                    isSame = first == second
                                else
                                    isSame = first[1] == second[1] and first[2] == second[2] and
                                    first[3] == second[3] and first[4] == second[4]
                                end
                            end
                            return isSame == (relation == "is")
                        else
                            -- FIXME: slow, ugly..
                            if relation == "==" then
                                return first == second
                            elseif relation == "~=" then
                                return first ~= second
                            elseif relation == ">" then
                                return first > second
                            elseif relation == "<" then
                                return first < second
                            elseif relation == ">=" then
                                return first >= second
                            elseif relation == "<=" then
                                return first <= second
                            else
                                Spring.Echo("unexpected comparison", relation)
                            end
                        end
                    end,
                    output = "bool",
                }
                table.insert(functions, compareCond)
            end
        end
        local coreTransforms = {
	     {
                humanName = "Get team resources", 
                name = "Get_TEAM_RESOURCES",
		output = "number",
                input = {"team", "string"},		
                tags = {"Resources"},
                execute = function (input)
                    return Spring.GetTeamResources(input.team, input.string)
                end
            },
	    {
                humanName = "Get team resource income", 
                name = "Get_TEAM_RESOURCE_INCOME",
		output = "number",
                input = {"team", "string"},		
                tags = {"Resources"},
                execute = function (input)
                    local _, _, _, income = Spring.GetTeamResources(input.team, input.string)
		    return income
                end
            },
            {
                humanName = "God mode enabled",
                name = "GOD_MODE_ENABLED",
                output = "bool",
                tags = { "Game State" },
                execute = function(input)
                    return Spring.IsGodModeEnabled()
                end
            },
            {
                humanName = "Cheating enabled",
                name = "CHEATING_ENABLED",
                output = "bool",
                tags = { "Game State" },
                execute = function(input)
                    return Spring.IsCheatingEnabled()
                end
            },
            {
                humanName = "Helper AIs enabled",
                name = "HELPER_AIS_ENABLED",
                output = "bool",
                tags = { "Game State" },
                execute = function(input)
                    return Spring.AreHelperAIsEnabled()
                end
            },
            {
                humanName = "Fixed allies",
                name = "FIXED_ALLIES",
                output = "bool",
                tags = { "Game State" },
                execute = function(input)
                    return Spring.FixedAllies()
                end
            },
            {
                humanName = "Game over",
                name = "GAME_OVER",
                output = "bool",
                tags = { "Game State" },
                execute = function(input)
                    return Spring.IsGameOver()
                end
            },

            {
                humanName = "Game speed",
                name = "GAME_SPEED",
                output = "number",
                tags = { "Time" },
                execute = function(input)
                    return Spring.GetGameSpeed()
                end
            },
            {
                humanName = "Game frame",
                name = "GAME_FRAME",
                output = "number",
                tags = { "Time" },
                execute = function(input)
                    return Spring.GetGameFrame()
                end
            },
            {
                humanName = "Game seconds",
                name = "GAME_SECONDS",
                output = "number",
                tags = { "Time" },
                execute = function(input)
                    return Spring.GetGameSeconds()
                end
            },
            {
                humanName = "Random",
                name = "INTEGER_RANDOM",
                input = {
                    {
                        name = "min", 
                        humanName = "Min",
                        type = "number",
                    },
                    {
                        name = "max", 
                        humanName = "Max",
                        type = "number",
                    },
                },
                output = "number",
                execute = function(input)
                    return math.random(input.min, input.max)
                end
            },
            {
                humanName = "Team alliance",
                name = "TEAMS_ALLIED",
                input = {
                    {
                        name = "team1", 
                        humanName = "Team 1",
                        type = "team",
                    },
                    {
                        name = "team2", 
                        humanName = "Team 2",
                        type = "team",
                    },
                },
                output = "bool",
                tags = {"Team"},
                execute = function(input)
                    return Spring.AreTeamsAllied(input.team1, input.team2)
                end
            },
            {
                humanName = "All units",
                name = "ALL_UNITS",
                output = "unit_array",
                tags = {"Units"},
                execute = function()
                    return Spring.GetAllUnits()
                end
            },
            {
                humanName = "Team units",
                name = "TEAM_UNITS",
                input = "team",
                output = "unit_array",
                tags = {"Units"},
                execute = function(input)
                    return Spring.GetTeamUnits(input.team)
                end
            },
            {
                humanName = "Team units by type",
                name = "TEAM_UNITS_BY_TYPE",
                input = { "team", "unitType" },
                output = "unit_array",
                tags = {"Units"},
                execute = function(input)
                    return Spring.GetTeamUnitsByDefs(input.team, input.unitType)
                end
            },
            {
                humanName = "Units in Area",
                name = "UNITS_IN_AREA",
                input = "area",
                output = "unit_array",
                tags = {"Units"},
                execute = function(input)
                    return Spring.GetUnitsInRectangle(unpack(input.area))
                end,
            },
            {
                humanName = "Unit's nearest ally",
                name = "UNIT_NEAREST_ALLY",
                input = "unit",
                output = "unit",
                tags = {"Unit"},
                execute = function(input)
                    return Spring.GetUnitNearestAlly(input.unit)
                end,
            },
            {
                humanName = "Unit's nearest enemy",
                name = "UNIT_NEAREST_ENEMY",
                input = "unit",
                output = "unit",
                tags = {"Unit"},
                execute = function(input)
                    return Spring.GetUnitNearestEnemy(input.unit)
                end,
            },
            {
                humanName = "Unit alive",
                name = "UNIT_ALIVE",
                input = { 
                    {
                        name = "unit",
                        type = "unit",
                        allowNil = true,
                    },
                },
                output = "bool",
                tags = {"Unit"},
                execute = function(input)
                    return input.unit and not Spring.GetUnitIsDead(input.unit)
                end,
            },
            {
                humanName = "Unit type",
                name = "UNIT_TYPE",
                input = "unit",
                output = "unitType",
                tags = {"Unit"},
                execute = function(input)
                    return Spring.GetUnitDefID(input.unit)
                end,
            },
            {
                humanName = "Unit team",
                name = "UNIT_TEAM",
                input = "unit",
                output = "team",            
                tags = {"Unit"},
                execute = function(input)
                    return Spring.GetUnitTeam(input.unit)
                end,
            },
            {
                humanName = "Unit Health",
                name = "UNIT_HEALTH",
                input = "unit",
                output = "number",            
                tags = {"Unit"},
                execute = function(input)
                    return Spring.GetUnitHealth(input.unit)
                end,
            },
            {
                humanName = "Unit Health %",
                name = "UNIT_HEALTH_PERCENT",
                input = "unit",
                output = "number",            
                tags = {"Unit"},
                execute = function(input)
                    local hp, maxHp = Spring.GetUnitHealth(input.unit)
                    return hp / maxHp
                end,
            },
            {
                humanName = "Unit stunned",
                name = "UNIT_STUNNED",
                input = "unit",
                output = "bool",
                tags = {"Unit"},
                execute = function(input)
                    local _, isStunned = Spring.GetUnitIsStunned(input.unit)
                    return isStunned
                end,
            },
            {
                humanName = "Unit experience",
                name = "UNIT_EXPERIENCE",
                input = "unit",
                output = "number",
                tags = {"Unit"},
                execute = function(input)
                    return Spring.GetUnitExperience(input.unit)
                end,
            },
            {
                humanName = "Unit being built by",
                name = "UNIT_BEING_BUILT",
                input = "unit",
                output = "unit",
                tags = {"Unit"},
                execute = function(input)
                    return Spring.GetUnitIsBuilding(input.unit)
                end,
            },
            {
                humanName = "Unit's last attacker",
                name = "UNIT_LAST_ATTACKER",
                input = "unit",
                output = "unit",
                tags = {"Unit"},
                execute = function(input)
                    return Spring.GetUnitLastAttacker(input.unit)
                end,
            },


            {
                humanName = "Center of Area",
                name = "CENTER_OF_AREA",
                input = "area",
                output = "position",
                execute = function(input)
                    local area = input.area
                    local x = (area[1] + area[3]) / 2
                    local z = (area[2] + area[4]) / 2
                    local y = Spring.GetGroundHeight(x, z)
                    return {x=x, y=y, z=z}
                end
            },
            {
                humanName = "Unit is in Area",
                name = "UNIT_IS_IN_AREA",
                input = { "area", "unit" },
                output = "bool",
                execute = function(input)
                    local units = Spring.GetUnitsInRectangle(unpack(input.area))
                    for _, id in pairs(units) do
                        if id == input.unit then
                            return true
                        end
                    end
                    return false
                end,
            },
            {
                humanName = "Trigger disabled",
                name = "TRIGGER_DISABLED",
                input = { "trigger" },
                tags = {"Trigger"},
                output = "bool",
                execute = function(input)
                    return not input.trigger.enabled
                end,
            },
            {
                humanName = "Trigger enabled",
                name = "TRIGGER_ENABLED",
                input = { "trigger" },
                output = "bool",
                tags = {"Trigger"},
                execute = function(input)
                    return input.trigger.enabled
                end,
            },
            {
                humanName = "Not",
                name = "NOT_CONDITION",
                input = { "bool" },
                output = "bool",
                tags = {"Logical"},
                execute = function(input)
                    return not input.bool
                end,
            },
            {
                humanName = "Or",
                name = "OR_CONDITIONS",
                input = { "bool_array" },
                output = "bool",
                tags = {"Logical"},
                execute = function(input)
					for i = 1, #input.bool_array do
						local bool = input.bool_array[i]
						if bool then
							return true
						end
					end
                    return false
                end,
            },
            {
                humanName = "And",
                name = "AND_CONDITIONS",
                input = { "bool_array" },
                output = "bool",
                tags = {"Logical"},
                execute = function(input)
                    for i = 1, #input.bool_array do
						local bool = input.bool_array[i]
						if not bool then
							return false
						end
					end
                    return #input.bool_array > 0
                end,
            },        
        }
        for i = 1, #coreTransforms do
            local coreTransform = coreTransforms[i]
            table.insert(functions, coreTransform)
        end

        local arrayTypes = {}
        for i = 1, #allTypes do
            local type = allTypes[i]
            local arrayType = type.name .. "_array"

            if type.canBeVariable ~= false then
                local itemFromArray = {
                    humanName = type.humanName .. " in array at position",
                    name = arrayType .. "_INDEXING",
                    input = { arrayType, "number" },
                    output = type.name,
                    tags = {"Array"},
                    execute = function(input)
                        local array = input[arrayType]
                        local index = input.number
                        return array[index]
                    end,
                }
                table.insert(functions, itemFromArray)
                local countArray = {
                    humanName = "Element count in " .. type.humanName .. " array",
                    name = arrayType .. "_COUNT",
                    input = { arrayType },
                    output = "number",
                    tags = {"Array"},
                    execute = function(input)
                        return #input[arrayType]
                    end,
                }
                table.insert(functions, countArray)
            end
        end
        return functions
    end,
    orders = function()
        return {
            {
                humanName = "Move to position",
                name = "MOVE_POSITION",
                input = { "position" },
                execute = function(input)
                    local unit = input.unit
                    local position = input.params.position
                    local x, y, z = position.x, position.y, position.z

                    Spring.GiveOrderToUnit(unit, CMD.MOVE, { x, y, z }, {"shift"})
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
                    local unit = input.unit
                    local target = input.params.target

                    Spring.GiveOrderToUnit(unit, CMD.ATTACK, { target }, {"shift"})
                end,
            },
            {
                humanName = "Cancel current order",
                name = "CANCEL_ORDER",
                input = {},
                execute = function(input)
                    local unit = input.unit

                    Spring.GiveOrderToUnit(unit, CMD.STOP, {}, {"shift"})
                end,
            },
            {
                humanName = "Wait with current order",
                name = "WAIT_ORDER",
                input = {},
                execute = function(input)
                    local unit = input.unit

                    Spring.GiveOrderToUnit(unit, CMD.WAIT, {}, {"shift"})
                end,
            },
            {
                humanName = "Patrol to position",
                name = "PATROL_POSITION",
                input = { "position" },
                execute = function(input)
                    local unit = input.unit
                    local position = input.params.position
                    local x, y, z = position.x, position.y, position.z

                    Spring.GiveOrderToUnit(unit, CMD.PATROL, { x, y, z }, {"shift"})
                end,
            },
            {
                humanName = "Fight to position",
                name = "FIGHT_POSITION",
                input = { "position" },
                execute = function(input)
                    local unit = input.unit
                    local position = input.params.position
                    local x, y, z = position.x, position.y, position.z

                    Spring.GiveOrderToUnit(unit, CMD.FIGHT, { x, y, z }, {"shift"})
                end,
            },
            {
                humanName = "Guard unit",
                name = "GUARD_UNIT",
                input = {                
                    {
                        name = "target",
                        type = "unit",
                        humanName = "Target unit",
                    },
                },
                execute = function(input)
                    local unit = input.unit
                    local target = input.params.target

                    Spring.GiveOrderToUnit(unit, CMD.GUARD, { target }, {"shift"})
                end,
            },
            {
                humanName = "Repair unit",
                name = "REPAIR_UNIT",
                input = {                
                    {
                        name = "target",
                        type = "unit",
                        humanName = "Target unit",
                    },
                },
                execute = function(input)
                    local unit = input.unit
                    local target = input.params.target

                    Spring.GiveOrderToUnit(unit, CMD.REPAIR, { target }, {"shift"})
                end,
            },
            {
                humanName = "Repair position",
                name = "REPAIR_POSITION",
                input = { type = "position" },
                execute = function(input)
                    local unit = input.unit
                    local position = input.params.position
                    local x, y, z = position.x, position.y, position.z

                    Spring.GiveOrderToUnit(unit, CMD.REPAIR, { x, y, z }, {"shift"})
                end,
            },
        }
    end

}
