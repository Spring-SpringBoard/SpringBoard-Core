local function OffsetCoords(tCoord, offsetX, offsetY)
    for i = 1, #tCoord, 2 do
        tCoord[i    ] = tCoord[i    ] + offsetX
        tCoord[i + 1] = tCoord[i + 1] + offsetY
    end
end

local function ScaleCoords(tCoord, scaleX, scaleY)
    for i = 1, #tCoord, 2 do
        tCoord[i    ] = tCoord[i    ] * scaleX
        tCoord[i + 1] = tCoord[i + 1] * scaleY
    end
end

local function rotate(x, y, angle)
    return x * math.cos(angle) - y * math.sin(angle),
           x * math.sin(angle) + y * math.cos(angle)
end

local function RotateCoords(tCoord, angle)
    -- rotate center
    local tdx = tCoord[5] - tCoord[1]
    local tdz = tCoord[4] - tCoord[2]
    for i = 1, #tCoord, 2 do
        tCoord[i    ]            = tCoord[i    ] - tdx
        tCoord[i + 1]            = tCoord[i + 1] - tdz
        tCoord[i], tCoord[i + 1] = rotate(tCoord[i], tCoord[i + 1], angle)
        tCoord[i    ]            = tCoord[i    ] + tdx
        tCoord[i + 1]            = tCoord[i + 1] + tdz
    end
end

function __GenerateMapCoords(mx, mz, mSizeX, mSizeZ)
    local mCoord = {
        mx,          mz,
        mx,          mz + mSizeZ,
        mx + mSizeX, mz + mSizeZ,
        mx + mSizeX, mz
    }
    local vCoord = {} -- vertex coords
    for i = 1, #mCoord do
        vCoord[i] = mCoord[i] * 2 - 1
    end

    return mCoord, vCoord
end

function __GenerateTextureCoords(x, z, sizeX, sizeZ, opts)
    local tCoord = {
        x,         z,
        x,         z + sizeZ,
        x + sizeX, z + sizeZ,
        x + sizeX, z
    }

    if opts.texOffsetX then
        OffsetCoords(tCoord, opts.texOffsetX * sizeX, opts.texOffsetY * sizeZ)
    end
    if opts.texScale then
        ScaleCoords(tCoord, opts.texScale, opts.texScale)
    end
    if opts.rotation then
        RotateCoords(tCoord, opts.rotation)
    end
    return tCoord
end

local function DrawQuads(mCoord, tCoord, vCoord)
    gl.MultiTexCoord(0, mCoord[1], mCoord[2])
    gl.MultiTexCoord(1, 0, 0)
    gl.MultiTexCoord(2, tCoord[1], tCoord[2])
    gl.Vertex(vCoord[1], vCoord[2])

    gl.MultiTexCoord(0, mCoord[3], mCoord[4])
    gl.MultiTexCoord(1, 0, 1)
    gl.MultiTexCoord(2, tCoord[3], tCoord[4])
    gl.Vertex(vCoord[3], vCoord[4])

    gl.MultiTexCoord(0, mCoord[5], mCoord[6])
    gl.MultiTexCoord(1, 1, 1)
    gl.MultiTexCoord(2, tCoord[5], tCoord[6])
    gl.Vertex(vCoord[5], vCoord[6])

    gl.MultiTexCoord(0, mCoord[7], mCoord[8])
    gl.MultiTexCoord(1, 1, 0)
    gl.MultiTexCoord(2, tCoord[7], tCoord[8])
    gl.Vertex(vCoord[7], vCoord[8])
end

function ApplyTexture(mCoord, tCoord, vCoord)
    -- TODO: move all this to a vertex shader?
    gl.BeginEnd(GL.QUADS, DrawQuads, mCoord, tCoord, vCoord)
end

local function DrawQuadsDNTS(mCoord, vCoord)
    gl.MultiTexCoord(0, mCoord[1], mCoord[2])
    gl.MultiTexCoord(1, 0, 0)
    gl.Vertex(vCoord[1], vCoord[2])

    gl.MultiTexCoord(0, mCoord[3], mCoord[4])
    gl.MultiTexCoord(1, 0, 1)
    gl.Vertex(vCoord[3], vCoord[4])

    gl.MultiTexCoord(0, mCoord[5], mCoord[6])
    gl.MultiTexCoord(1, 1, 1)
    gl.Vertex(vCoord[5], vCoord[6])

    gl.MultiTexCoord(0, mCoord[7], mCoord[8])
    gl.MultiTexCoord(1, 1, 0)
    gl.Vertex(vCoord[7], vCoord[8])
end

function ApplyDNTSTexture(mCoord, vCoord)
    -- TODO: move all this to a vertex shader?
    gl.BeginEnd(GL.QUADS, DrawQuadsDNTS, mCoord, vCoord)
end

----------------
-- API
----------------

function Graphics:DrawBrush(brush, renderTextures)
    -- 0. Get textures and push undo stack textures?
    -- 1. Make copies of target texture(s)
    -- 2. Setup custom shader and its uniforms
    -- 3. Bind textures (brush and material textures)
    -- 4. Perform draw
    -- 5. Unbind shader and textures
end

function Graphics:DrawDNTS()
end