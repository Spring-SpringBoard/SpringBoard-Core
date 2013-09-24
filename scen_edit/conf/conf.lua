Conf = LCS.class{}

function Conf:init()
    self.C_HEIGHT = 16
    self.B_HEIGHT = 26    
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
