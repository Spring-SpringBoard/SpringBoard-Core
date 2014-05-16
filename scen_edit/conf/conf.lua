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

function Conf:initializeListOfMetaModelFiles()
	local files = VFS.DirList("triggers")
	for i = 1, #files do
		local file = files[i]
		self.metaModelFiles[#self.metaModelFiles + 1] = file
	end
end

function Conf:getMetaModelFiles()
    return self.metaModelFiles
end
