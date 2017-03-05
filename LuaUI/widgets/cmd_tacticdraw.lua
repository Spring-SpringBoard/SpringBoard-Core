function widget:GetInfo()
    return {
        name      = "Tactical Draw",
        desc      = "Draw tactical plans on the map",
        author    = "ashdnazg",
        date      = "08 Oct 2014",
        license   = "GNU GPL, v2 or later",
        layer     = 2,
        enabled   = false,
    }
end


-- Localisations
local GetMouseState       = Spring.GetMouseState
local TraceScreenRay      = Spring.TraceScreenRay
local WorldToScreenCoords = Spring.WorldToScreenCoords

local Echo                = Spring.Echo
local MarkerAddLine       = Spring.MarkerAddLine
local MarkerAddPoint      = Spring.MarkerAddPoint
local MarkerErasePosition = Spring.MarkerErasePosition

-- OpenGL
local glColor          = gl.Color
local glDrawGroundQuad = gl.DrawGroundQuad
local glPolygonMode    = gl.PolygonMode
local glPopMatrix      = gl.PopMatrix
local glPushMatrix     = gl.PushMatrix
local glRect           = gl.Rect
local glRotate         = gl.Rotate
local glShape          = gl.Shape
local glTranslate      = gl.Translate
local GL_LINES = GL.LINES
local GL_TRIANGLES = GL.TRIANGLES
local GL_LINE = GL.LINE
local GL_FRONT_AND_BACK = GL.FRONT_AND_BACK
local GL_FILL = GL.FILL


local push = table.insert
local pop = table.remove




-- Variables
local mode

local arrows
local arrowMarkers
local anchorLines
local markerQueue -- {x1, z1, x2, z2}
local existingMarkers

local startCoords
local selectedPoint
local selectedArrowID

local hasGUI
local arrowButton

--Constants
local MARKERS_PER_FRAME = 2
local LINE_WIDTH        = 1
local OUTLINE_SCALE     = 20
local MIN_WIDTH         = 20
local POINT_SIZE        = 5
local POINT_SIZE_SQ     = POINT_SIZE * POINT_SIZE
local ERROR_THRESHOLD = 10
local MAX_RECURSION = 7

local RAD_TO_DEG = (180 / 3.1415)
local COLOR_REGULAR 	= {1,1,1, 1}
local COLOR_SELECTED = {0.8, 0, 0, 1}


local MODE_NONE = 0
local MODE_DRAW = 1

local function BezierDistanceError(bezier)
    local from = bezier.from
    local to = bezier.to
    local fromAnchor = bezier.fromAnchor
    local toAnchor = bezier.toAnchor
    local dx, dy = to[1] - from[1], to[2] - from[2]


    return math.abs(((fromAnchor[1] - to[1]) * dy - (fromAnchor[2] - to[2]) * dx)) +
           math.abs(((toAnchor[1] - to[1]) * dy - (toAnchor[2] - to[2]) * dx))
end

local function FlattenBezier(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4, lineList, depth)
    local bError = math.abs(x1 + x3 - x2 - x2) +
                   math.abs(y1 + y3 - y2 - y2) +
                   math.abs(z1 + z3 - z2 - z2) +
                   math.abs(x2 + x4 - x3 - x3) +
                   math.abs(y2 + y4 - y3 - y3) +
                   math.abs(z2 + z4 - z3 - z3)

    if first then
        Echo("e: ".. bError)
    end
    if bError < ERROR_THRESHOLD or depth > MAX_RECURSION then
        push(lineList, {x1, y1, z1, x4, y4, z4})
    else
        local x12   = (x1 + x2) / 2
        local y12   = (y1 + y2) / 2
        local z12   = (z1 + z2) / 2
        local x23   = (x2 + x3) / 2
        local y23   = (y2 + y3) / 2
        local z23   = (z2 + z3) / 2
        local x34   = (x3 + x4) / 2
        local y34   = (y3 + y4) / 2
        local z34   = (z3 + z4) / 2
        local x123  = (x12 + x23) / 2
        local y123  = (y12 + y23) / 2
        local z123  = (z12 + z23) / 2
        local x234  = (x23 + x34) / 2
        local y234  = (y23 + y34) / 2
        local z234  = (z23 + z34) / 2
        local x1234 = (x123 + x234) / 2
        local y1234 = (y123 + y234) / 2
        local z1234 = (z123 + z234) / 2
        FlattenBezier(x1, y1, z1, x12, y12, z12, x123, y123, z123, x1234, y1234, z1234, lineList, depth + 1)
        FlattenBezier(x1234, y1234, z1234, x234, y234, z234, x34, y34, z34, x4, y4, z4, lineList, depth + 1)
    end
end

local function GetNorm(line, width)
    local x = line[4] - line[1]
    local z = line[6] - line[3]
    local l = math.sqrt(x * x + z * z)
    return x / l * width, z / l * width
end

local function GetPerpNorm(line, width)
    local x = line[3] - line[6]
    local z = line[4] - line[1]
    local l = math.sqrt(x * x + z * z)
    return x / l * width, z / l * width
end

local function GetPerpNorm2(line1, line2, width)
    local x = line1[3] - line1[6] + line2[3] - line2[6]
    local z = line1[4] - line1[1] + line2[4] - line2[1]
    local l = math.sqrt(x * x + z * z)
    return x / l * width, z / l * width
end

local function GetOutline(lineList, width)
    local outLine = {}
    local leftx, leftz, rightx, rightz
    local lastLeftx, lastLeftz, lastRightx, lastRightz
    local perpx, perpz
    local nextLine = lineList[1]
    perpx, perpz = GetPerpNorm(nextLine, width)
    lastLeftx = nextLine[1] + perpx
    lastLeftz = nextLine[3] + perpz
    lastRightx = nextLine[1] - perpx
    lastRightz = nextLine[3] - perpz

    -- The arrow's base
    push(outLine, {lastLeftx, nextLine[2], lastLeftz, lastRightx, nextLine[2] ,lastRightz})


    -- The arrow's body
    for i = 2, #lineList do
        local line = nextLine
        nextLine = lineList[i]
        perpx, perpz = GetPerpNorm2(line, nextLine, width)
        leftx = nextLine[1] + perpx
        leftz = nextLine[3] + perpz
        rightx = nextLine[1] - perpx
        rightz = nextLine[3] - perpz
        push(outLine, {lastLeftx, line[2], lastLeftz, leftx, line[5], leftz})
        push(outLine, {lastRightx, line[2], lastRightz, rightx, line[5], rightz})
        lastLeftx, lastLeftz, lastRightx, lastRightz = leftx, leftz, rightx, rightz
    end

    perpx, perpz = GetPerpNorm(nextLine, width)
    leftx = nextLine[4] + perpx
    leftz = nextLine[6] + perpz
    rightx = nextLine[4] - perpx
    rightz = nextLine[6] - perpz

    push(outLine, {lastLeftx, nextLine[2], lastLeftz, leftx, nextLine[5] ,leftz})
    push(outLine, {lastRightx, nextLine[2], lastRightz, rightx, nextLine[5], rightz})

    -- The arrow's head
    local normx, normz = GetNorm(nextLine, width * 2)
    local headLeftx, headLeftz = leftx + perpx, leftz + perpz
    local headRightx, headRightz = rightx - perpx, rightz - perpz
    local headTipx, headTipz = nextLine[4] + normx, nextLine[6] + normz

    push(outLine, {leftx, nextLine[5], leftz, headLeftx, nextLine[5] ,headLeftz})
    push(outLine, {rightx, nextLine[5], rightz, headRightx, nextLine[5] ,headRightz})

    push(outLine, {headLeftx, nextLine[5], headLeftz, headTipx, nextLine[5], headTipz})
    push(outLine, {headRightx, nextLine[5], headRightz, headTipx, nextLine[5], headTipz})

    return outLine
end

local function RecalcMarkers(arrowID)
    local arrow = arrows[arrowID]
    local from = arrow.from
    local to = arrow.to
    local fromAnchor = arrow.fromAnchor
    local toAnchor = arrow.toAnchor
    --arrowMarkers[arrowID] = {{from[1], from[2], from[3], to[1], to[2], to[3]}}
    local lineList = {}
    FlattenBezier(from[1], from[2], from[3], fromAnchor[1], fromAnchor[2], fromAnchor[3],
                  toAnchor[1], toAnchor[2], toAnchor[3], to[1], to[2], to[3], lineList, 1)
    local dx, dz = to[1] - from[1], to[3] - from[3]
    local dist = math.sqrt(dx * dx + dz * dz)
    local width = math.max(MIN_WIDTH, dist / OUTLINE_SCALE)

    local outLine = GetOutline(lineList, width)

    arrowMarkers[arrowID] = outLine

    anchorLines[arrowID] = {{from[1], from[2], from[3], fromAnchor[1], fromAnchor[2], fromAnchor[3]},
                            {to[1], to[2], to[3], toAnchor[1], toAnchor[2], toAnchor[3]}}
end

local function EraseMarkers()
    for _, marker in pairs(existingMarkers) do
        MarkerErasePosition(marker[1], marker[2], marker[3])
    end
    existingMarkers = {}
end

local function EnterDrawMode()
    mode = MODE_DRAW
    if hasGUI then
        arrowButton.backgroundColor = COLOR_SELECTED
        arrowButton:Invalidate()
    end
end

local function ExitDrawMode()
    mode = MODE_NONE
    if hasGUI then
        arrowButton.backgroundColor = COLOR_REGULAR
        arrowButton:Invalidate()
    end
end

local function SendMarkers()
    for i = 1, #arrowMarkers do
        local markerList = arrowMarkers[i]
        for j=1, #markerList do
            push(markerQueue, markerList[j])
        end
        push(markerQueue, arrows[i].to)
    end
    arrowMarkers = {}
    anchorLines = {}
    arrows = {}
end

local function AddArrow(x1, y1, z1, x2, y2, z2)
    local ox, oy, oz = (x2 - x1) / 4, (y2 - y1) / 4, (z2 - z1) / 4
    push(arrows, {from       = {x1, y1, z1},
                  to         = {x2, y2, z2},
                  fromAnchor = {x1 + ox, y1 + oy, z1 + oz},
                  toAnchor   = {x2 - ox, y2 - oy, z2 - oz}})
    RecalcMarkers(#arrows)
    ExitDrawMode()
end

local function SelectPoint(mx, my, pointName, arrow, arrowID)
    local x, y, z = WorldToScreenCoords(unpack(arrow[pointName]))
    local dx, dy = mx - x, my - y
    local distsq = dx^2 + dy^2
    if distsq < POINT_SIZE_SQ then
        selectedPoint = pointName
        selectedArrowID = arrowID
        return true
    end
    return false
end

local function IsCursorOnPoint(mx, my)
    selectedArrowID = nil
    selectedPoint = nil
    for arrowID, arrow in pairs(arrows) do
        if SelectPoint(mx, my, "fromAnchor", arrow, arrowID) or
           SelectPoint(mx, my, "toAnchor", arrow, arrowID) or
           SelectPoint(mx, my, "to", arrow, arrowID) or
           SelectPoint(mx, my, "from", arrow, arrowID) then
            return true
        end
    end
    return false
end

local function DrawLineList(lineList)
    for _, markerList in pairs(lineList) do
        for _, coords in pairs(markerList) do
            local startx, starty, startz = WorldToScreenCoords(coords[1], coords[2], coords[3])
            local endx, endy, endz = WorldToScreenCoords(coords[4], coords[5], coords[6])
            local dx, dy = endx - startx, endy - starty
            local rotation = math.atan2(dx, dy)
            local distance = math.sqrt(dx^2 + dy^2)
            glPushMatrix()
                glTranslate(startx, starty, 0)
                glRotate(rotation * RAD_TO_DEG, 0, 0, -1)
                glRect(-LINE_WIDTH, 0, LINE_WIDTH, distance)
            glPopMatrix()
        end
    end
end

local function DrawPoints(pointName)
    local vertices = {}
    for _, arrow in pairs(arrows) do
        local x, y, z = WorldToScreenCoords(unpack(arrow[pointName]))
        local minx, maxx = x - POINT_SIZE, x + POINT_SIZE
        local miny, maxy = y - POINT_SIZE, y + POINT_SIZE

        push(vertices, {v = {minx, miny, 0}})
        push(vertices, {v = {minx, maxy, 0}})
        push(vertices, {v = {maxx, maxy, 0}})
        push(vertices, {v = {maxx, miny, 0}})
    end
    glShape(GL.QUADS, vertices)
end

local function ClearArrows()
    arrowMarkers = {}
    anchorLines = {}
    arrows = {}
    ExitDrawMode()
end

local function InitGUI()
    local Chili = WG.Chili


    arrowButton = Chili.Button:New{y = 20, width = 80, caption = "Arrow", OnClick = {function(self) EnterDrawMode() end}}

    local window0 = Chili.Window:New{
		caption = "Drawing Board",
		y = "30%",
        right = 10,
		width  = 200,
		height = 200,
		parent = Chili.Screen0,
		autosize = true,
		savespace = true,
		--debug = true,
		children = {
			arrowButton,
            Chili.Button:New{y = 40, width = 80, caption = "Clear", OnClick = {function(self) ClearArrows() end}},
            Chili.Button:New{y = 60, width = 80, caption = "Erase", OnClick = {function(self) EraseMarkers() end}},
            Chili.Button:New{y = 80, width = 80, caption = "Send", OnClick = {function(self) SendMarkers() end}},
		},
	}
end


--------------
--  CALLINS --
--------------

function widget:DrawScreen()
    glColor(0, 255, 0, 1)
    DrawLineList(arrowMarkers)
    DrawPoints("from")
    DrawPoints("to")
    glColor(255, 0, 0, 1)
    DrawLineList(anchorLines)
    DrawPoints("fromAnchor")
    DrawPoints("toAnchor")
end



function widget:MousePress(mx, my, button)
    if button == 1 then
        if mode == MODE_DRAW then
            local what
            what, startCoords = TraceScreenRay(mx, my, true)
            if what then
                return true
            else
                return false
            end
        else
            return IsCursorOnPoint(mx, my)
        end
    elseif button == 3 then
        ExitDrawMode()
        if not hasGUI then
            SendMarkers()
        end
    end
    return false
end

function widget:MouseMove(mx, my, dx, dy, button)
    if selectedArrowID then
        local coords
        _, coords = TraceScreenRay(mx, my, true)
        if coords then
            arrows[selectedArrowID][selectedPoint] = coords
            RecalcMarkers(selectedArrowID)
        end
    end
end

function widget:MouseRelease(mx, my, button)
    if mode == MODE_DRAW then
        local endCoords
        _, endCoords = TraceScreenRay(mx, my, true)
        if endCoords then
            AddArrow(startCoords[1], startCoords[2], startCoords[3], endCoords[1], endCoords[2], endCoords[3])
        end
    elseif selectedArrowID then
        local coords
        _, coords = TraceScreenRay(mx, my, true)
        if coords then
            arrows[selectedArrowID][selectedPoint] = coords
            RecalcMarkers(selectedArrowID)
        end
        selectedArrowID = nil
        selectedPoint = nil
    end
end


function widget:TextCommand(command)
    if (string.find(command, 'tacticdraw') == 1) then
        EnterDrawMode()
    end
end

function widget:Initialize()
	-- if (Spring.IsReplay()) then -- no need to draw in replays, right?
		-- widgetHandler:RemoveWidget(self)
		-- return
	-- end

    arrows = {}
    markerQueue = {}
    arrowMarkers = {}
    existingMarkers = {}
    anchorLines = {}
    mode = MODE_NONE

    local chili = WG.Chili
    if chili then
        hasGUI = true
        InitGUI()
    else
        hasGUI = false
    end
end


function widget:Update(dt)
    if #markerQueue > 0 then
        for i = 1, math.min(#markerQueue, MARKERS_PER_FRAME) do
            local marker = markerQueue[1]
            local x1,y1,z1,x2,y2,z2 = unpack(marker)
            if x2 then
                MarkerAddLine(x1, y1, z1, x2, y2, z2)
            else
                MarkerAddPoint(x1, y1, z1)
            end
            push(existingMarkers, marker)
            pop(markerQueue, 1)
        end
    end
end
