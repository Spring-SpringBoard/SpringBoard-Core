CompileMapCommand = Command:extends{}
CompileMapCommand.className = "CompileMapCommand"

function CompileMapCommand:init(opts)
    self.opts = opts
end

function CompileMapCommand:execute()
	local metalAbsPath
	return WG.Connector.Send("CompileMap", {
		heightPath = self.opts.heightPath,
		diffusePath = self.opts.diffusePath,
		metalPath = self.opts.metalPath,
		outputPath = self.opts.outputPath,
	}, {
		waitForResult = true
	})
end

if Script.GetName() ~= "LuaUI" then
	return
end