ExportMapInfoCommand = NativeCommand:extends{}
ExportMapInfoCommand.className = "ExportMapInfoCommand"

function ExportMapInfoCommand:init(path)
    self.path = path
    if Path.GetExt(self.path) ~= ".lua" then
        self.path = self.path .. ".lua"
    end
end
