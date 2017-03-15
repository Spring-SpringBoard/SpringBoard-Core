Log = Log or {}

LOG_SECTION = "SpringBoard"

-- simplified Spring.Log, see https://springrts.com/wiki/Lua_UnsyncedCtrl#Ingame_Console

function Log.Error(...)
	Spring.Log(LOG_SECTION, LOG.ERROR, ...)
end

function Log.Warning(...)
	Spring.Log(LOG_SECTION, LOG.WARNING, ...)
end

-- this should perhaps be the default and replace Spring.Echo
-- tempted to call this Info, but the actual info (LOG.INFO doesn't get printed out by default)
function Log.Notice(...)
	Spring.Log(LOG_SECTION, LOG.NOTICE, ...)
end

-- enable debug printout in dev builds? (Spring.SetLogSectionFilterLevel)
function Log.Debug(...)
	Spring.Log(LOG_SECTION, LOG.DEBUG, ...)
end
