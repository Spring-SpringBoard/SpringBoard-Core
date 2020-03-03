LauncherImageExporter = {
	asyncCommandMap = {},
	id = 0
}

function LauncherImageExporter:Export(name, command)
	if command.outPath == nil then
		Log.Error("No output path specified for image export")
		return false
	end

	local promise = Promise()
	self.id = self.id + 1
	self.asyncCommandMap[self.id] = promise
	command.id = self.id

	WG.Connector.Send(name, command)

	return promise
end

function LauncherImageExporter:_OnFinished(command)
	local id = command.id
	if id == nil then
		Log.Error("No command ID for event TransformSBImageFinished")
		return
	end
	local promise = self.asyncCommandMap[id]
	if promise == nil then
		Log.Warning("No registered object for event TransformSBImageFinished: " .. tostring(id))
		return
	end

	self.asyncCommandMap[id] = nil
	promise:resolve()
end

function LauncherImageExporter:_OnFailed(command)
	local id = command.id
	if id == nil then
		Log.Error("No command ID for event TransformSBImageFailed")
		return
	end
	local error = command.error
	local promise = self.asyncCommandMap[id]
	if promise == nil then
		Log.Warning("No registered object for event TransformSBImageFailed: " .. tostring(id))
		return
	end

	self.asyncCommandMap[id] = nil
	promise:reject(error)
end

WG.Connector.Register("TransformSBImageFinished", function(command)
	Log.Notice("Image export complete: " .. tostring(command.path))
	LauncherImageExporter:_OnFinished(command)
end)
WG.Connector.Register("TransformSBImageFailed", function(command)
	Log.Notice("Image export failed: " .. tostring(command.error))
	LauncherImageExporter:_OnFailed(command)
end)

Log.Notice("Initialized support for launcher map export.")