Conf = LCS.class{}

function Conf:init()
    self.C_HEIGHT = 16
    self.B_HEIGHT = 26
    self.BTN_ADD_COLOR = {0.36, 0.72, 0.36, 1}
    self.BTN_OK_COLOR = {0.26, 0.54, 0.79, 1}
    self.BTN_CANCEL_COLOR = {0.84, 0.31, 0.30, 1}
	self.metaModelFiles = {} -- { "core.lua" } default	
	self:initializeListOfMetaModelFiles()
end

function Conf:LoadMetaModelFile(metaModelFile)
    local success, data = pcall(function() return VFS.LoadFile(metaModelFile) end)
    if not success then
        Spring.Echo("Failed to load file " .. metaModelFile .. ": " .. data)
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

    if SCEN_EDIT.model ~= nil then
        files = VFS.DirList(SCEN_EDIT.model:GetProjectDir() .. "/triggers/", "*", VFS.RAW)
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
	self:initializeListOfMetaModelFiles()
    return self.metaModelFiles
end

function Conf:SetMetaModelFiles(metaModelFiles)
    self.metaModelFiles = metaModelFiles
end
