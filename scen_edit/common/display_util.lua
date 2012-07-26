DisplayUtil = LCS.class{}

local fontSize = 12

function DisplayUtil:init(isWidget)
	self.isWidget = isWidget
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
local Chili = WG.Chili
local screen0 = Chili.Screen0
	local textHeight, _, numLines = gl.GetTextHeight(str)
	textHeight = textHeight*fontSize*numLines
	local textWidth = gl.GetTextWidth(str)*fontSize

	local ux, uy, uz = Spring.GetUnitBasePosition(unitID)
	uy = uy + height
	local x,y,z = Spring.WorldToScreenCoords(ux, uy, uz)
	if not invert then
		y = screen0.height - y
	end
	
	return textWidth, textHeight, x, y, height
end

function DisplayUtil:AddUnitSay(text, unitId, time)
local Chili = WG.Chili
local screen0 = Chili.Screen0
	local height = Spring.GetUnitHeight(unitId)
	
	local textWidth, textHeight, x, y = GetTipDimensions(unitId, text, height)

	local img = Chili.Image:New {
		width = textWidth + 4,
		height = textHeight + 4 + fontSize,
		x = x - (textWidth+8)/2,
		y = y - textHeight - 4 - fontSize,
		keepAspect = false,
		file = "LuaUI/images/scenedit/speechbubble.png",
		parent = screen0,
	}
	local textBox = Chili.TextBox:New {
		parent  = img,
		text    = text,
		height	= textHeight,
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
    table.insert(self.unitSays, {
        text = text,
        unitId = unitId,
        time = time,
        img = img,
        height = height,
    })
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
	
	for i = 1, #toDelete do
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
	
	for i = 1, #toDelete do
        self.unitSays[toDelete[i]].img:Dispose()
		table.remove(self.unitSays, toDelete[i])
	end

    local Chili = WG.Chili
    local screen0 = Chili.Screen0
	-- chili code
	for _, unitSay in pairs(self.unitSays) do
		if Spring.IsUnitInView(unitSay.unitId) then
			local textWidth, textHeight, x, y = GetTipDimensions(unitSay.unitId, unitSay.text, unitSay.height)
			
			local img = unitSay.img
			if img.hidden then
				screen0:AddChild(img)
				img.hidden = false
			end
			
			--img.x = x - (textWidth+8)/2
			--img.y = y - textHeight - 4 - fontSize
			--img:Invalidate()
			
			img:SetPos(x - (textWidth+8)/2, y - textHeight - 4 - fontSize)
		elseif not unitSay.img.hidden then
			screen0:RemoveChild(unitSay.img)
			unitSay.img.hidden = true
		end
	end
end

function DisplayUtil:Draw()
	for i = 1, #self.texts do	
		local text = self.texts[i]
		gl.PushMatrix()
		gl.Translate(text.coords[1], text.coords[2], text.coords[3])
		gl.Color(text.color.r, text.color.g, text.color.b, 1)
		gl.Text(text.text, 0, 300 - text.time, 12)
		gl.PopMatrix()
	end
    for i = 1, #self.unitSays do

        --local coords = {Spring.GetUnitPosition(unit)}
    end
end

function DisplayUtil:displayText(text, coords, color)
	if self.isWidget then
		self:AddText(text, coords, color, 300)
	else
        local cmd = WidgetDisplayTextCommand(text, coords, color)
        SCEN_EDIT.commandManager:execute(cmd, true)
	end
end

function DisplayUtil:unitSay(unit, text)
    if self.isWidget then
        self:AddUnitSay(text, unit, 300)
    else
        local cmd = WidgetUnitSayCommand(unit, text)
        SCEN_EDIT.commandManager:execute(cmd, true)
    end
end
