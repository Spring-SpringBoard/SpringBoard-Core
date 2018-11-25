Array = Array or {}

local dtypeMap = {
    uint8 = {
        pack     = VFS.PackU8,
        unpack   = VFS.UnpackU8,
        size     = 1,
    },
    uint16 = {
        pack     = VFS.PackU16,
        unpack   = VFS.UnpackU16,
        size     = 2,
    },
    uint32 = {
        pack     = VFS.PackU32,
        unpack   = VFS.UnpackU32,
        size     = 4,
    },
    int8 = {
        pack     = VFS.PackS8,
        unpack   = VFS.UnpackS8,
        size     = 1,
    },
    int16 = {
        pack     = VFS.PackS16,
        unpack   = VFS.UnpackS16,
        size     = 2,
    },
    int32 = {
        pack     = VFS.PackS32,
        unpack   = VFS.UnpackS32,
        size     = 4,
    },
    float32 = {
        pack     = VFS.PackF32,
        unpack   = VFS.UnpackF32,
        size     = 4,
    },
}

-- -- TODO
-- function Array.Save(file, array, dtype)
--     dtype = dtype or "float32"
--     local packFunc = dtypeToPackMap[dtype]
--     assert(packFunc, "dtype not supported: " .. tostring(dtype))
--
-- end

local BUFFER_SIZE = 100000
function Array.SaveFunc(file, lua_function, dtype)
    dtype = dtype or "float32"
    assert(dtypeMap[dtype], "dtype not supported: " .. tostring(dtype))
    local packFunc = dtypeMap[dtype].pack

    file = assert(io.open(file, "wb"))

    local data = {}

    local arrayWriter = {}
    arrayWriter.Write = function(point)
        data[#data + 1] = point
        if #data >= BUFFER_SIZE then
            file:write(packFunc(data))
            data = {}
        end
    end

    lua_function(arrayWriter)

    if #data > 0 then
        file:write(packFunc(data))
    end

    assert(file:close())
end

-- FIXME: first arg string or file? (we need more functions)
function Array.LoadFunc(str, lua_function, dtype)
    dtype = dtype or "float32"
    assert(dtypeMap[dtype], "dtype not supported: " .. tostring(dtype))
    local unpackFunc = dtypeMap[dtype].unpack
    local dtypeSize  = dtypeMap[dtype].size

    local bufferSize = 100000 * dtypeSize
    local segmentNum = 0
    local totalSegments = math.ceil(#str / bufferSize)
    -- FIXME: error?
    -- local dataSize = #str / dtypeSize

    local fetchSegment = function()
        if segmentNum >= totalSegments then
            return {}
        end
        local startIndx = 1 + segmentNum * bufferSize
        segmentNum = segmentNum + 1
        local substr = str:sub(startIndx, startIndx + bufferSize)
        return unpackFunc(substr, 1, bufferSize / dtypeSize) or {}
--            return VFS.UnpackF32(self.deltaMap, startIndx, bufferSize / floatSize) or {}
    end
    local data = fetchSegment()
    local i = 1
    local getData = function()
        local chunk = data[i]
        i = i + 1
        if i > #data then
            data = fetchSegment()
            i = 1
        end
        return chunk
    end

    local arrayReader = {}
    arrayReader.Get = getData

    lua_function(arrayReader)
end
