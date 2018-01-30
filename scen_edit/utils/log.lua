Log = Log or {}

local LOG_SECTION = "SpringBoard"

-- Whether Log.Debug should use the LOG.INFO level.
-- This can be helpful to set to true as engine is often compiled with LOG.INFO as the minimum
local LOG_DEBUG_WITH_INFO = false
function Log.DebugWithInfo(enabled)
    LOG_DEBUG_WITH_INFO = enabled
end

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

function Log.Info(...)
    Spring.Log(LOG_SECTION, LOG.INFO, ...)
end

-- enable debug printout in dev builds? (Spring.SetLogSectionFilterLevel)
function Log.Debug(...)
    if LOG_DEBUG_WITH_INFO then
        Spring.Log(LOG_SECTION, LOG.INFO, ...)
    else
        Spring.Log(LOG_SECTION, LOG.DEBUG, ...)
    end
end
