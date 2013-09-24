MetaModelLoader = LCS.class{}

function MetaModelLoader:init()
    self.metaModelFiles = SCEN_EDIT.conf:getMetaModelFiles()
end

function MetaModelLoader:AttemptToLoadFile(metaModelFile)
	local success, data = pcall(function() return VFS.LoadFile(metaModelFile) end)
	if not success then
		Spring.Echo("Failed to load file " .. metaModelFile .. ": " .. data)
		return nil
	end
	
	local success, data = pcall(function() return assert(loadstring(data))() end)
	if not success then
		Spring.Echo("Failed to load file " .. metaModelFile .. ": " .. data)
		return nil
	end
	
	return data
end

function MetaModelLoader:Load()
    local metaTypes = {"functions", "actions", "orders", "events"}
    local metaModels = {}

    -- load files
    for _, metaModelFile in pairs(self.metaModelFiles) do
        local metaModel = {}

        for _, metaType in pairs(metaTypes) do
            metaModel[metaType] = {}
        end
		
        local data = self:AttemptToLoadFile(metaModelFile)

		if data ~= nil then
			for _, metaType in pairs(metaTypes) do
				if data[metaType] then
					--Spring.Echo("Loading " .. metaType)
					local values = {}
					if type(data[metaType]) == "table" then
						values = data[metaType]
					elseif type(data[metaType]) == "function" then
						setfenv(data[metaType], getfenv())
						values = data[metaType]()
					else
						Spring.Echo(type(data[metaModel]))
					end
					for i = 1, #values do
						local value = values[i]
						table.insert(metaModel[metaType], value)
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
            humanName = "Player died",
            name = "PLAYER_DIE",
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
    SCEN_EDIT.metaModel:LoadEventTypes(mergedMetaModel.events)
    SCEN_EDIT.metaModel:LoadFunctionTypes(mergedMetaModel.functions)
    SCEN_EDIT.metaModel:LoadActionTypes(mergedMetaModel.actions)
    SCEN_EDIT.metaModel:LoadOrderTypes(mergedMetaModel.orders)
end
