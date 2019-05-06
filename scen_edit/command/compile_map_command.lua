CompileMapCommand = Command:extends{}
CompileMapCommand.className = "CompileMapCommand"

function CompileMapCommand:init(opts)
    self.opts = opts
end

function CompileMapCommand:execute()
	WG.Connector.Send("CompileMap", {
		heightPath = VFS.GetFileAbsolutePath(self.opts.heightPath),
		diffusePath = VFS.GetFileAbsolutePath(self.opts.diffusePath),
		outputPath = self.opts.outputPath,
	})
end