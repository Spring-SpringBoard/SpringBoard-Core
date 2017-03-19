-- used to isoloate all spring kernel variables
__SK = {
	LOG_SECTION = "kernel",
	JSON = VFS.Include(KERNEL_FOLDER .. "json.lua"),
	json = {},
}

function __SK.json.encode(...)
	return __SK.JSON:encode(...)
end

function __SK.json.decode(...)
	return __SK.JSON:decode(...)
end

function __SK.explode(div,str)
	if (div=='') then return false end
	local pos,arr = 0,{}
	-- for each divider found
	for st,sp in function() return string.find(str,div,pos,true) end do
		table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
		pos = sp + 1 -- Jump past current divider
	end
	table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
	return arr
end

function __SK._isarray(t)
	local i = 0
 	for _ in pairs(t) do
    	i = i + 1
		if t[i] == nil then return false end
  	end
  	return true
end
function __SK._size(t)
	local size = 0
	for _ in pairs(t) do
    	size = size + 1
	end
	return size
end
__SK._MAX_LEVEL = 3
function __SK._tostring(value, valArg, level)
	level = level or 0
	if level >= __SK._MAX_LEVEL and type(value) == "table" then
		return "{ ... }"
	end
	local str = ""
	if type(value) == "table" then
		if valArg then
			str = ""
		else
			str = "{"
		end
		local _start = true
		local isArray
		local size
		if valArg then
			isArray = true
			size = value.n
			value.n = nil
		else
			isArray = __SK._isarray(value)
			size = __SK._size(value)
		end

		local indx = 1

		local max_indx_head = 100
		local min_indx_tail = 10
		local switch_print = 0
		if isArray then
			for indx = 1, size do
				local v = value[indx]
				if switch_print == 0 and indx > max_indx_head and size - min_indx_tail > indx then
					switch_print = 1
					str = str .. " ... "
					_start = true
				elseif switch_print == 1 and indx > size - min_indx_tail then
					switch_print = 2
				end
				if switch_print ~= 1 then
					if not _start then
						str = str .. ", "
					end
					if isArray then
						str = str .. __SK._tostring(v, false, level+1)
					else
						str = str .. tostring(k) .. "=" .. __SK._tostring(v, false, level+1)
					end
					_start = false
				end
			end
		else
			for k, v in pairs(value) do
				indx = indx + 1
				if switch_print == 0 and indx > max_indx_head and size - min_indx_tail > indx then
					switch_print = 1
					str = str .. " ... "
					_start = true
				elseif switch_print == 1 and indx > size - min_indx_tail then
					switch_print = 2
				end
				if switch_print ~= 1 then
					if not _start then
						str = str .. ", "
					end
					if isArray then
						str = str .. __SK._tostring(v, false, level+1)
					else
						str = str .. tostring(k) .. "=" .. __SK._tostring(v, false, level+1)
					end
					_start = false
				end
			end
		end
		if not valArg then
			str = str .. "}"
		end
		return str
	else
		return tostring(value)
	end
end

__SK._echoOutput = ""
function _p(...)
	local args = { n = select("#", ...); ... }
	__SK._echoOutput = __SK._echoOutput .. __SK._tostring(args, true) .. "\n"
	--Spring.Echo(...)
end
function __SK.getEchoOutput()
	local output = __SK._echoOutput
	__SK._echoOutput = ""
	return output
end


function __SK.ExecuteLuaCommand(luaCommandStr)
-- 			if not luaCommandStr:gsub("==", "_"):gsub("~=", "_"):gsub(">=", "_"):gsub("<=", "_"):find("=") then
-- 				luaCommandStr = "return " .. luaCommandStr
-- 			end
	local luaCommand, msg = loadstring(luaCommandStr)
	if not luaCommand then
		return false, msg
	else
		setfenv(luaCommand, getfenv())
		local success, msg = pcall(luaCommand)
		-- 	pcall(function()
		-- 	local msg = {luaCommand()}
		-- 	if #msg > 0 then
		-- 		return msg[1] -- unpack(msg)
		-- 	end
		-- end)
		if not success then
			return false, msg
		end
	end
	return true
end

-- returns information about a function
function _source(f)
    if type(f) ~= "function" then
        return "Not a function"
    end
	if not debug then
		return "Cannot get function information in this state: " .. tostring(Script.GetName()) .. ", synced: " .. tostring(Script.GetSynced())
	end
    local info = debug.getinfo(f)
    if info.what == 'Lua' then
        local f = VFS.LoadFile(info.source, nil, VFS.DEF)
		if not f then
			return "No code available for Lua function."
		end
        local lines = __SK.explode('\n', f)
        local code = ""
        for i = info.linedefined, info.lastlinedefined do
            code = code .. lines[i] .. "\n"
        end
        return code
    else
        return "No code preview available for engine function"
    end
end

function _s(f)
	_p(_source(f))
end

__SK.WRITE_DATA_DIR = nil
-- extremely ugly way to find our data dir absolute path
function __SK.GetWriteDataDir()
	if __SK.WRITE_DATA_DIR then
		return __SK.WRITE_DATA_DIR
	end

	local dataDirStr = "write data directory: "
	lines = __SK.explode("\n", VFS.LoadFile("infolog.txt", nil, VFS.RAW))
	dataDir = ""
	for i, line in pairs(lines) do
	    if line:find(dataDirStr) then
	        dataDir = line:sub(line:find(dataDirStr) + #dataDirStr)
	        break
	    end
	end
	__SK.WRITE_DATA_DIR = dataDir
	return __SK.WRITE_DATA_DIR
end
