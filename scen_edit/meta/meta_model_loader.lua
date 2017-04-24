MetaModelLoader = LCS.class{}

function MetaModelLoader:AttemptToLoadFile(metaModelFile)
    local data = metaModelFile.data
	local success, data = pcall(function() return assert(loadstring(data))() end)
	if not success then
		Log.Error("Failed to parse file " .. metaModelFile.name .. ": ")
        Log.Error(loadstring(metaModelFile.data))
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
        Log.Notice("Using file: " .. metaModelFile.name)
        local metaModel = {}

        for _, metaType in pairs(metaTypes) do
            metaModel[metaType] = {}
        end

        local data = self:AttemptToLoadFile(metaModelFile)

		if data ~= nil then
			for _, metaType in pairs(metaTypes) do
				if data[metaType] ~= nil then
					local values = {}
					if type(data[metaType]) == "table" then
						values = data[metaType]
					elseif type(data[metaType]) == "function" then
						setfenv(data[metaType], getfenv())
						values = data[metaType]()
					else
						Log.Error("Unexeptected data type when parsing meta model file", type(data[metaModel]))
					end
					for _, value in pairs(values) do
                        if type(value) == "table" then
--                            if metaType == "functions" and value.output == nil or type(value.output) ~= "table" or #value.output == 0 then
                            table.insert(metaModel[metaType], value)
                        else
                            Log.Error("Error parsing " .. metaModelFile.name .. ", expected table for " .. metaType .. ", but got " .. type(value) .. ", for element: " .. tostring(value))
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

    Log.Notice("Event types: " .. #mergedMetaModel.events)
    Log.Notice("Function types: " .. #mergedMetaModel.functions)
    Log.Notice("Action types: " .. #mergedMetaModel.actions)
    Log.Notice("Order types: " .. #mergedMetaModel.orders)
    SCEN_EDIT.metaModel:SetEventTypes(mergedMetaModel.events)
    SCEN_EDIT.metaModel:SetFunctionTypes(mergedMetaModel.functions)
    SCEN_EDIT.metaModel:SetActionTypes(mergedMetaModel.actions)
    SCEN_EDIT.metaModel:SetOrderTypes(mergedMetaModel.orders)
end
