CompileMapCommand = Command:extends{}
CompileMapCommand.className = "CompileMapCommand"

function CompileMapCommand:init(opts)
    self.opts = opts
end

function CompileMapCommand:execute()
	return WG.Connector.Send("CompileMap", {
		heightPath = self.opts.heightPath,
		diffusePath = self.opts.diffusePath,
		metalPath = self.opts.metalPath,
		outputPath = self.opts.outputPath,
		-- TODO1: rename to minimapPath
		-- TODO2: avoid Path.Join() like with the other arguments
		minimap = Path.Join(SB.DIRS.WRITE_PATH, self.opts.diffusePath),
	}, {
		waitForResult = true
	})
end

if Script.GetName() ~= "LuaUI" then
	return
end