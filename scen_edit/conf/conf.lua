Conf = LCS.class{}

function Conf:init()
    self.C_HEIGHT = 16
    self.B_HEIGHT = 26
    self.BTN_ADD_COLOR = {0.36, 0.72, 0.36, 1}
    self.BTN_OK_COLOR = {0.26, 0.54, 0.79, 1}
    self.BTN_CANCEL_COLOR = {0.84, 0.31, 0.30, 1}
    self.TOOLBOX_ITEM_WIDTH = 70
    self.TOOLBOX_ITEM_HEIGHT = 70
    self.SHOW_BASIC_CONTROLS = true
    self.metaModelFiles = {} -- { "core.lua" } default
    self:initializeListOfMetaModelFiles()
    self.tabOrder = {
        Objects = 1,
        Map = 2,
        Env = 3,
        Logic = 4,
        Misc = 5,
    }
end

function Conf:LoadMetaModelFile(metaModelFile)
    local success, data = pcall(function() return VFS.LoadFile(metaModelFile) end)
    if not success then
        Log.Error("Failed to load file " .. metaModelFile .. ": " .. data)
        return nil
    end
    return data
end

function Conf:initializeListOfMetaModelFiles()
    self.metaModelFiles = {}

    local files = VFS.DirList("triggers")
    for i = 1, #files do
        local file = files[i]
        local data = self:LoadMetaModelFile(file)
        if data ~= nil then
            self.metaModelFiles[#self.metaModelFiles + 1] = {
                name = file,
                data = data,
            }
        end
    end

    Log.Notice("Project dir:", SB.projectDir)
    if SB.projectDir ~= nil then
        files = VFS.DirList(SB.projectDir .. "/triggers/", "*", VFS.RAW)
        for i = 1, #files do
            local file = files[i]
            local data = self:LoadMetaModelFile(file)
            if data ~= nil then
                self.metaModelFiles[#self.metaModelFiles + 1] = {
                    name = file,
                    data = data,
                }
            end
        end
    end
end

function Conf:GetMetaModelFiles()
    return self.metaModelFiles
end

function Conf:SetMetaModelFiles(metaModelFiles)
    self.metaModelFiles = metaModelFiles
end

function Conf:GetTabOrder(tabName)
    return self.tabOrder[tabName] or math.huge
end
