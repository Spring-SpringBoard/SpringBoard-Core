SyncFileCommand = Command:extends{}
SyncFileCommand.className = "SyncFileCommand"

function SyncFileCommand:init(fileData)
    self.fileData = fileData
end

function SyncFileCommand:execute()
    loadstring(self.fileData)()
end
