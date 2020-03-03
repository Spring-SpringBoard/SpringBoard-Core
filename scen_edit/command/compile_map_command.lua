CompileMapCommand = Command:extends{}
CompileMapCommand.className = "CompileMapCommand"

local compileInProgress = nil

function CompileMapCommand:init(opts)
    self.opts = opts
end

function CompileMapCommand:execute()
	compileInProgress = Promise()
	WG.Connector.Send("CompileMap", {
		heightPath = VFS.GetFileAbsolutePath(self.opts.heightPath),
		diffusePath = VFS.GetFileAbsolutePath(self.opts.diffusePath),
		metalPath = VFS.GetFileAbsolutePath(self.opts.metalPath),
		outputPath = self.opts.outputPath,
	})
	return compileInProgress
end

if Script.GetName() ~= "LuaUI" then
	return
end

WG.Connector.Register("CompileMapFinished", function()
	local promise = compileInProgress
	compileInProgress = nil
	promise:resolve()
end)

WG.Connector.Register("CompileMapError", function(command)
	local promise = compileInProgress
	compileInProgress = nil
	promise:reject("Failed to compile: " .. tostring(command.msg))
end)