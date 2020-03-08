CompileMapCommand = Command:extends{}
CompileMapCommand.className = "CompileMapCommand"

local compileInProgress = nil

function CompileMapCommand:init(opts)
    self.opts = opts
end

function CompileMapCommand:execute()
	compileInProgress = Promise()
	local metalAbsPath
	if self.opts.metalPath ~= nil then
		metalAbsPath = VFS.GetFileAbsolutePath(self.opts.metalPath)
	end
	WG.Connector.Send("CompileMap", {
		heightPath = VFS.GetFileAbsolutePath(self.opts.heightPath),
		diffusePath = VFS.GetFileAbsolutePath(self.opts.diffusePath),
		metalPath = metalAbsPath,
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