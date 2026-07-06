ExportS11NCommand = NativeCommand:extends{}
ExportS11NCommand.className = "ExportS11NCommand"

function ExportS11NCommand:init(path)
    self.path = path
    if Path.GetExt(self.path) ~= ".lua" then
        self.path = self.path .. ".lua"
    end
end
