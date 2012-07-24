DisplayUtil = class()

function DisplayUtil:__init(isWidget)
	self.isWidget = isWidget
	self.texts = {}
end

function DisplayUtil:AddText(text, coords, color, time)
	table.insert(self.texts, {
		text = text, 
		coords = coords, 
		color = color,
		time = time,
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
end

function DisplayUtil:displayText(text, coords, color)
	if self.isWidget then
		self:AddText(text, coords, color, 300)
	else
        local cmd = WidgetDisplayTextCommand(text, coords, color)
        SCEN_EDIT.commandManager:execute(cmd, true)
	end
end
