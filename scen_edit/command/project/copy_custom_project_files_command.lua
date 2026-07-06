CopyCustomProjectFilesCommand = NativeCommand:extends{}
CopyCustomProjectFilesCommand.className = "CopyCustomProjectFilesCommand"

function CopyCustomProjectFilesCommand:init(src, dest)
	self.src = src
	self.dest = dest
	self.blockUndo = true
end
