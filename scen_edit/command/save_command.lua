SaveCommand = AbstractCommand:extends{}
SaveCommand.className = "SaveCommand"

function SaveCommand:init(path)
    self.className = "SaveCommand"
    self.path = path
end

local function HeightMapSave(path)
    Spring.Echo("HEIGHTMAP SAVE")
    local file = assert(io.open(path, "wb"))
    local data = {}
    local totalChanged = 0

    local bufferSize = 1000
    local bufferFlush = function()
        if #data == 0 then
            return
        end
        --Spring.Echo("Packing...")
        local str = VFS.PackF32(data)
        --Spring.Echo("Unpacking...")
        local newData = VFS.UnpackF32(str, 1, #str / 4)
        --Spring.Echo(#data, #newData)
        if #data ~= #newData then
            --Spring.Echo("Different size!: ", #data, #newData)
        end
        local diffCount = 0
        for i = 1, math.min(#data, #newData) do
            if data[i] ~= newData[i] then
                diffCount = diffCount + 1
                --Spring.Echo("DIFF:", data[i], newData[i])
            end
            if diffCount > 100 then
                break
            end
        end
        file:write(str)
    end
    local addData = function(chunk)
        data[#data + 1] = chunk                                
        totalChanged = totalChanged + 1
        if #data >= bufferSize then
            bufferFlush()
            data = {}
        end
    end
    for x = 0, Game.mapSizeX, Game.squareSize do
        local lastChanged = false
        for z = 0, Game.mapSizeZ, Game.squareSize do
            local groundHeight = Spring.GetGroundHeight(x, z)
            local origGroundHeight = Spring.GetGroundOrigHeight(x, z)
            local deltaHeight = groundHeight - origGroundHeight
            if deltaHeight ~= 0 then
                --Spring.Echo(x, z)
                if lastChanged then
                    --Spring.Echo(deltaHeight)
                    if deltaHeight ~= deltaHeight then
                        --Spring.Echo(x, z)
                    end
                    addData(deltaHeight)
                else
                    --Spring.Echo(x, z, deltaHeight)
                    if deltaHeight ~= deltaHeight or x ~= x or z ~= z then
                        --Spring.Echo(x, z, deltaHeight)
                    end
                    addData(x)
                    addData(z)
                    addData(deltaHeight)
                    lastChanged = true
                end
            else
                if lastChanged then
                    --Spring.Echo(0)
                    addData(0)
                    lastChanged = false
                end
            end
        end
    end
    bufferFlush()
    if totalChanged == 0 then
        Spring.Echo("Heightmap unchanged")
    end
    Spring.Echo("Floats: " .. totalChanged)
    Spring.Echo("HEIGHTMAP SAVE DONE")
    assert(file:close())
end

local function ModelSave(path)
    Spring.Echo("calling model save...")
    success, msg = pcall(Model.Save, SCEN_EDIT.model, path)
    if not success then 
        Spring.Echo(msg)
    end
end

local function GenerateModInfo()
    local modInfo = 
[[
local modinfo = {
    name = "Air Force Command r4",
    description = "Mission Mutator",
    modtype = "1",
    shortname =     "Air Force Command",
    depend = {
        "Zero-K v1.0.7.2"
    },
}      
return modinfo]]
    return modInfo
end

function SaveCommand:execute()
    assert(not VFS.FileExists(self.path), "File already exists")
   
    Spring.Echo("creating dir...")
    --create a temporary directory
    local tempDirBaseName = "_scen_edit_tmp_"
    local tempDirName = nil
    local indx = 1
    repeat
        tempDirName = tempDirBaseName .. tostring(indx)
    until not VFS.FileExists(tempDirName)
    Spring.CreateDir(tempDirName)

    Spring.Echo("saving files...")
    --save into a temporary directory
    ModelSave(tempDirName .. "/model.lua")
    HeightMapSave(tempDirName .. "/heightmap.data")

    Spring.Echo("compressing folder...")
    --create an archive from the directory
    VFS.CompressFolder(tempDirName, "zip", self.path)

    --remove the temporary directory
    os.remove(tempDirName)
end
