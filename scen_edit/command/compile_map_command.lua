CompileMapCommand = NativeCommand:extends{}
CompileMapCommand.className = "CompileMapCommand"

function CompileMapCommand:init(opts)
    self.opts = opts
    self.opts.writePath = self.opts.writePath or SB.DIRS.WRITE_PATH
    self.opts.minimap = self.opts.minimap or Path.Join(SB.DIRS.WRITE_PATH, self.opts.diffusePath)
    self.blockUndo = true
end

if Script.GetName() ~= "LuaUI" then
	return
end
