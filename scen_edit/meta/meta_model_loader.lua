MetaModelLoader = LCS.class{}

function MetaModelLoader:AttemptToLoadFile(metaModelFile)
    local dataStr = metaModelFile.data
    local success, data = pcall(function()
        return assert(loadstring(data))()
    end)
    if not success then
        Log.Error("Failed to parse file " .. metaModelFile.name .. ": ")
        Log.Error(loadstring(metaModelFile.data))
        return nil
    end

    return data
end

function MetaModelLoader:_LoadMetaModelFile(metaModelFile, metaTypes)
    local metaModel = {}

    for _, metaType in pairs(metaTypes) do
        metaModel[metaType] = {}
    end

    local data = self:AttemptToLoadFile(metaModelFile)
    if data == nil then
        return
    end

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
    return metaModel
end

function MetaModelLoader:_MergeMetaModels(metaModels, metaTypes)
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
    return mergedMetaModel
end

function MetaModelLoader:_LoadDataTypes(metaModelFiles)
    local metaModels = {}
    -- load files
    for _, metaModelFile in pairs(metaModelFiles) do
        Log.Notice("Loading data types from meta-model file: " .. metaModelFile.name)
        local metaModel = self:_LoadMetaModelFile(metaModelFile, {"dataTypes"})
        if metaModel ~= nil then
            table.insert(metaModels, metaModel)
        end
    end
    -- merge meta models
    local mergedMetaModel = self:_MergeMetaModels(metaModels, {"dataTypes"})
    return mergedMetaModel.dataTypes
end

function MetaModelLoader:_LoadMetaModels(metaModelFiles, metaTypes)
    local metaModels = {}
    -- load files
    for _, metaModelFile in pairs(metaModelFiles) do
        Log.Notice("Loading meta-model file: " .. metaModelFile.name)
        local metaModel = self:_LoadMetaModelFile(metaModelFile, metaTypes)
        if metaModel ~= nil then
            table.insert(metaModels, metaModel)
        end
    end
    -- merge meta models
    local mergedMetaModel = self:_MergeMetaModels(metaModels, metaTypes)
    return mergedMetaModel
end

function MetaModelLoader:Load()
    local metaModelFiles = SB.conf:GetMetaModelFiles()
    local metaTypes = {"functions", "actions", "orders", "events"}

    Log.Notice("Loading meta-model files...")

    -- We first load data types as they can be used in other meta-models
    Log.Notice("Loading data types...")
    local dataTypes = self:_LoadDataTypes(metaModelFiles)
    Log.Notice("Data types: " .. #dataTypes)
    SB.metaModel:SetCustomDataTypes(dataTypes)
    SB.metaModel:GenerateVariableTypes()

    Log.Notice("Loading meta-triggers...")
    local mergedMetaModel = self:_LoadMetaModels(metaModelFiles, metaTypes)

    Log.Notice("Event types: " .. #mergedMetaModel.events)
    Log.Notice("Function types: " .. #mergedMetaModel.functions)
    Log.Notice("Action types: " .. #mergedMetaModel.actions)
    Log.Notice("Order types: " .. #mergedMetaModel.orders)
    SB.metaModel:SetEventTypes(mergedMetaModel.events)
    SB.metaModel:SetFunctionTypes(mergedMetaModel.functions)
    SB.metaModel:SetActionTypes(mergedMetaModel.actions)
    SB.metaModel:SetOrderTypes(mergedMetaModel.orders)
end
