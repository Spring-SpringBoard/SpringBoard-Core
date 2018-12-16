local cmdConfig = {}
local contextParser = {}
local contextNameMapping = {}
local currentContext, defaultContext

-- extension API
function GetDefaultContext()
	return defaultContext
end
function SetDefaultContext(context)
	defaultContext = context
	if GetCurrentContext() == nil then
		SetContext(defaultContext)
	end
end
function GetCurrentContext()
	return currentContext
end
function ResetCurrentContext()
	currentContext = defaultContext
	ShowContext()
end
function SetContext(context)
	local oldContextName
	if currentContext then
		oldContextName = currentContext.name
	end

	currentContext = context

	if oldContextName ~= context.name then
		EnterCurrentContext(GetText())
	end
end

-- this is used to identify the current command used in Sync
local currentCmd = ""
function Sync(...)
	local x = {...}
	local msg = "chonsole|" .. currentCmd
	for _, v in pairs(x) do
		msg = msg .. "|" .. v
	end
	Spring.SendLuaRulesMsg(msg)
end
-- extension API end


function InitializeExtensions()
	i18n = WG.i18n
	if not i18n then
		-- optional support for i18n
		i18n = function(key, data)
			data = data or {}
			return data.default or key
		end
	end
end

function LoadTranslations()
	-- Load global translations
	if WG.i18n then
		VFS.Include(CHONSOLE_FOLDER .. "/i18n.lua", nil, VFS.DEF_MODE)
		if translations ~= nil then
			i18n.load(translations)
		end
	end
end

function LoadExtensions()
	-- Load extensions
	for _, f in pairs(VFS.DirList(CHONSOLE_FOLDER .. "/exts", "*", VFS.DEF_MODE)) do
		-- Load translations first
		if WG.i18n then
			local fname = ExtractFileName(f)
			local fdir = ExtractDir(f)
			local i18nFile = fdir .. "i18n/" .. fname
			if VFS.FileExists(i18nFile, nil, VFS.DEF_MODE) then
				local success, err = pcall(function() VFS.Include(i18nFile, nil, VFS.DEF_MODE) end)
				if not success then
					Spring.Log("Chonsole", LOG.ERROR, "Error loading translation file: " .. f)
					Spring.Log("Chonsole", LOG.ERROR, err)
				end
				if translations ~= nil then
					i18n.load(translations)
				end
			end
		end
		-- Load extension
		commands = nil
		local success, err = pcall(function() VFS.Include(f, nil, VFS.DEF_MODE) end)
		if not success then
			Spring.Log("Chonsole", LOG.ERROR, "Error loading extension file: " .. f)
			Spring.Log("Chonsole", LOG.ERROR, err)
		else
			if commands ~= nil then
				for _, cmd in pairs(commands) do
					table.insert(cmdConfig, cmd)
				end
			end
			if context ~= nil then
				for _, parser in pairs(context) do
					table.insert(contextParser, parser)
				end
			end
		end
	end

	for _, context in pairs(contextParser) do
		contextNameMapping[context.name] = context
	end
end

function GetExtensions()
	return cmdConfig
end

function ExecuteCustomCommand(cmd, command, cmdParts)
	currentCmd = cmd.command
	local success, err = pcall(function() cmd.exec(command, cmdParts) end)
	if not success then
		Spring.Log("Chonsole", LOG.ERROR, "Error executing custom command: " .. tostring(cmd.command))
		Spring.Log("Chonsole", LOG.ERROR, err)
	end
	currentCmd = ""
end


function GetContexts()
	return contextParser
end

local function _TryContextCall(context, fname, ...)
	if context[fname] == nil then
		return false
	end
	local varargs = {...}
	succ, result = xpcall(
		function()
			return context[fname](unpack(varargs)) end,
		function(err)
			Spring.Log("Chonsole", LOG.ERROR, "Error invoking " .. fname .. " custom context: " .. tostring(context.name))
			Spring.Log("Chonsole", LOG.ERROR, debug.traceback(err))
		end
	)
	if succ then
		return result
	end
end

function TryEnterContext(txt)
	for _, context in pairs(GetContexts()) do
		local newContext = _TryContextCall(context, "tryEnter", txt)
		if newContext then
			SetContext(newContext)
			return true
		end
	end
end

function KeyPressContext(...)
	for _, context in pairs(GetContexts()) do
		local result = _TryContextCall(context, "keyPress", ...)
		if result then
			return result
		end
	end
end

function ParseKeyContext(...)
	for _, context in pairs(GetContexts()) do
		local result = _TryContextCall(context, "parseKey", ...)
		if result then
			return result
		end
	end
end

function ExecuteCurrentContext(txt)
	local context = contextNameMapping[currentContext.name]
	if not context then
		return false
	end
	_TryContextCall(context, "exec", txt, currentContext)
	return true
end

function EnterCurrentContext(txt)
	local context = contextNameMapping[currentContext.name]
	if not context or context.enter == nil then
		return false
	end
	_TryContextCall(context, "enter", txt, currentContext)
	return true
end
