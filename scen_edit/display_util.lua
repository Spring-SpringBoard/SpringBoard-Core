DisplayUtil = LCS.class{}

local fontSize = 12

function DisplayUtil:init()
    self.__isWidget = Script.GetName() == "LuaUI"
    self.texts = {}
    self.unitSays = {}
end

function DisplayUtil:AddText(text, coords, color, time)
    table.insert(self.texts, {
        text = text,
        coords = coords,
        color = color,
        time = time,
    })
end

local function GetTipDimensions(unitID, str, height, invert)
    local textHeight, _, numLines = gl.GetTextHeight(str)
    textHeight = textHeight * fontSize * numLines
    local textWidth = gl.GetTextWidth(str) * fontSize + 4

    local x, y = -1, -1
    if Spring.IsUnitInView(unitID) and height ~= nil then
        local ux, uy, uz = Spring.GetUnitBasePosition(unitID)
        uy = uy + height
        x, y, _ = Spring.WorldToScreenCoords(ux, uy, uz)
        if not invert then
            y = screen0.height - y
        end
    end

    return textWidth, textHeight, x, y, height
end

function DisplayUtil:AddUnitSay(text, unitID, time)
    local height = Spring.GetUnitHeight(unitID)

    local textWidth, textHeight, x, y = GetTipDimensions(unitID, text, height)

    local img = Image:New {
        width = textWidth + 4,
        height = textHeight + 4 + fontSize,
        x = x - (textWidth+8)/2,
        y = y - textHeight - 4 - fontSize,
        keepAspect = false,
        file = "LuaUI/images/scenedit/speechbubble.png",
        parent = screen0,
    }
    local textBox = TextBox:New {
        parent  = img,
        text    = text,
        height    = textHeight,
        width   = textWidth,
        x = 4,
        y = 4,
        valign  = "center",
        align   = "left",
        font    = {
        --font   = font,
            size   = fontSize,
            color  = {0,0,0,1},
        },
    }
    if x == -1 and y == -1 and z == -1 and not img.hidden then
        screen0:RemoveChild(img)
        img.hidden = true
    end
    table.insert(self.unitSays, {
        text = text,
        unitID = unitID,
        time = time,
        img = img,
        height = height,
    })
end

function DisplayUtil:Update()
    if self.follow then
        if not Spring.ValidUnitID(self.follow) or Spring.GetUnitIsDead(self.follow) or self.follow == nil then
            self.follow = nil
        else--if Spring.IsUnitVisible(self.follow) then
            local x, y, z = Spring.GetUnitViewPosition(self.follow)
            Spring.SetCameraTarget(x, y, z)
            Spring.SelectUnitArray({self.follow})
        end
    end
end

function DisplayUtil:OnFrame()
    local toDelete = {}

    for i = 1, #self.texts do
        local text = self.texts[i]
        text.time = text.time - 1
        if text.time <= 0 then
            table.insert(toDelete, i)
        end
    end

    for i = #toDelete, 1, -1 do
        table.remove(self.texts, toDelete[i])
    end

    toDelete = {}
    for i = 1, #self.unitSays do
        local text = self.unitSays[i]
        text.time = text.time - 1
        if text.time <= 0 then
            table.insert(toDelete, i)
        end
    end

    for i = #toDelete, 1, -1 do
        local del = toDelete[i]
        if self.unitSays[del].img then
            self.unitSays[del].img:Dispose()
        end
        table.remove(self.unitSays, i)
    end

    -- chili code
    for _, unitSay in pairs(self.unitSays) do
        if Spring.IsUnitInView(unitSay.unitID) then
            local textWidth, textHeight, x, y = GetTipDimensions(unitSay.unitID, unitSay.text, unitSay.height)

            local img = unitSay.img
            if img.hidden then
                screen0:AddChild(img)
                img.hidden = false
            end


            img:SetPos(x - (textWidth+8)/2, y - textHeight - 4 - fontSize)
        elseif not unitSay.img.hidden then
            screen0:RemoveChild(unitSay.img)
            unitSay.img.hidden = true
        end
    end
end

function DisplayUtil:Draw()
    if SB.view == nil or not SB.view.displayDevelop then
        return
    end
    for i = 1, #self.texts do
        local text = self.texts[i]
        gl.PushMatrix()
        gl.Translate(text.coords[1], text.coords[2], text.coords[3])
        gl.Color(text.color.r, text.color.g, text.color.b, 1)
        gl.Text(text.text, 0, 300 - text.time, 12)
        gl.PopMatrix()
    end
end

function DisplayUtil:displayText(text, coords, color)
    if self.__isWidget then
        self:AddText(text, coords, color, 300)
    else
        local cmd = WidgetDisplayTextCommand(text, coords, color)
        SB.commandManager:execute(cmd, true)
    end
end

function DisplayUtil:unitSay(unit, text)
    if self.__isWidget then
        self:AddUnitSay(text, unit, 300)
    else
        local cmd = WidgetUnitSayCommand(unit, text)
        SB.commandManager:execute(cmd, true)
    end
end

function DisplayUtil:followUnit(unit)
    if self.__isWidget then
        self.follow = unit
    else
        local cmd = WidgetFollowUnitCommand(unit)
        SB.commandManager:execute(cmd, true)
    end
end
