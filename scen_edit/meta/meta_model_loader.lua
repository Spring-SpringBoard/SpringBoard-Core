MetaModelLoader = LCS.class{}

function MetaModelLoader:AttemptToLoadFile(metaModelFile)
    local data = metaModelFile.data
	local success, data = pcall(function() return assert(loadstring(data))() end)
	if not success then
		Spring.Echo("Failed to parse file " .. metaModelFile .. ": " .. metaModelFile.data)
		return nil
	end
	
	return data
end

function MetaModelLoader:Load()
    local metaModelFiles = SCEN_EDIT.conf:GetMetaModelFiles()
    local metaTypes = {"functions", "actions", "orders", "events"}
    local metaModels = {}

    -- load files
    for _, metaModelFile in pairs(metaModelFiles) do
        Spring.Echo("Using file: " .. metaModelFile.name)
        local metaModel = {}

        for _, metaType in pairs(metaTypes) do
            metaModel[metaType] = {}
        end
		
        local data = self:AttemptToLoadFile(metaModelFile)

		if data ~= nil then
			for _, metaType in pairs(metaTypes) do
				if data[metaType] ~= nil then
					--Spring.Echo("Loading " .. metaType)
					local values = {}
					if type(data[metaType]) == "table" then
						values = data[metaType]
					elseif type(data[metaType]) == "function" then
						setfenv(data[metaType], getfenv())
						values = data[metaType]()
					else
						Spring.Echo("Unexeptected data type when parsing meta model file", type(data[metaModel]))
					end
					for _, value in pairs(values) do
                        if type(value) == "table" then
--                            if metaType == "functions" and value.output == nil or type(value.output) ~= "table" or #value.output == 0 then
--                                Spring.Echo("Error parsing " .. metaModelFile.name .. ", expected output 
                            table.insert(metaModel[metaType], value)
                        else
                            Spring.Echo("Error parsing " .. metaModelFile.name .. ", expected table for " .. metaType .. ", but got " .. type(value) .. ", for element: " .. tostring(value))
                        end
					end
				end
			end
			table.insert(metaModels, metaModel)
		end
    end

    -- merge meta models
    local mergedMetaModel = {}
    for _, metaType in pairs(metaTypes) do
        mergedMetaModel[metaType] = {}
    end

    for _, metaModel in pairs(metaModels) do
        for _, metaType in pairs(metaTypes) do
            for _, value in pairs(metaModel[metaType]) do
                table.insert(mergedMetaModel[metaType], value)
            end
        end
    end

    mergedMetaModel.events = {
        {
            humanName = "Game started",
            name = "GAME_START",
        }, 
        {
            humanName = "Game ends",
            name = "GAME_END",
        }, 
        {
            humanName = "Team died",
            name = "TEAM_DIE",
        }, 
        {
            humanName = "Unit created",
            name = "UNIT_CREATE",
        },
        {
            humanName = "Unit damaged",
            name = "UNIT_DAMAGE",
        },
        {
            humanName = "Unit destroyed",
            name = "UNIT_DESTROY",
        },
        {
            humanName = "Unit finished",
            name = "UNIT_FINISH",
        },
        {
            humanName = "Unit enters area",
            name = "UNIT_ENTER_AREA",
        },
        {
            humanName = "Unit leaves area",
            name = "UNIT_LEAVE_AREA",
        },
    }

    Spring.Echo("Event types: " .. #mergedMetaModel.events)
    Spring.Echo("Function types: " .. #mergedMetaModel.functions)
    Spring.Echo("Action types: " .. #mergedMetaModel.actions)
    Spring.Echo("Order types: " .. #mergedMetaModel.orders)
    SCEN_EDIT.metaModel:SetEventTypes(mergedMetaModel.events)
    SCEN_EDIT.metaModel:SetFunctionTypes(mergedMetaModel.functions)
    SCEN_EDIT.metaModel:SetActionTypes(mergedMetaModel.actions)
    SCEN_EDIT.metaModel:SetOrderTypes(mergedMetaModel.orders)
end
