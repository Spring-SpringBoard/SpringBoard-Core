Conf = LCS.class{}

function Conf:init()
    self.C_HEIGHT = 16
    self.B_HEIGHT = 26
    self.metaModelFiles = { "core.lua" } -- default
end

function Conf:getMetaModelFiles()
    return self.metaModelFiles
end
