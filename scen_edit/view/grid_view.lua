GridView = LCS.class{}

function GridView:init(tbl)
	local defaults = {
		selectable = true,
		multiSelect = false,
		autosize = true,
		autoArrangeH = false,
		autoArrangeV = false,
		centerItems  = false,
		itemMargin   = {1, 1, 1, 1},
		iconX = 88,
		iconY = 88,
		useRTT = true,
	}
	tbl = Table.Merge(tbl, defaults)
    self.items = {}

	self.iconX = tbl.iconX
	self.iconY = tbl.iconY

	-- we're using the fake control to handle skin-based rendering
	self._fakeControl = ImageListView:New{}

	self.control = LayoutPanel:New(tbl)
	self.control.HitTest = function(ctrl, x,y)
		local cx,cy = ctrl:LocalToClient(x,y)
		local obj = LayoutPanel.HitTest(ctrl,cx,cy)
		if (obj) then return obj end
		if ctrl.cells == nil then
			return
		end
		local itemIdx = ctrl:GetItemIndexAt(cx,cy)
		return (itemIdx>=0) and ctrl
	end

	self.control.DrawItemBkGnd = function(ctrl, index)
		local cell = ctrl._cells[index]
		local itemPadding = ctrl.itemPadding

		if ctrl.selectedItems[index] then
			self._fakeControl:DrawItemBackground(cell[1] - itemPadding[1], cell[2] - itemPadding[2], cell[3] + itemPadding[1] + itemPadding[3], cell[4] + itemPadding[2] + itemPadding[4], "selected")
		else
			self._fakeControl:DrawItemBackground(cell[1] - itemPadding[1], cell[2] - itemPadding[2], cell[3] + itemPadding[1] + itemPadding[3], cell[4] + itemPadding[2] + itemPadding[4], "normal")
		end
	end
end

-- This stuff should be used from the Chili skin instead

function GridView:Select(indx)
end

function GridView:AddItem(caption, image, tooltip)
    local imgCtrl = Image:New {
        width  = self.iconX,
        height = self.iconY,
        file = image,
    }
    local lblCtrl = Label:New {
        width = self.iconX + 30,
        height = 20,
        align = 'center',
        autosize = false,
        --autosize = true,
        caption = caption,
        --fontsize = 12,
    }
	local item = LayoutPanel:New{
		width  = self.iconX+10,
		height = self.iconY+20,
		padding = {0,0,0,0},
		itemPadding = {0,0,0,0},
		itemMargin = {0,0,0,0},
		rows = 2,
		columns = 1,
		tooltip = tooltip,
		useRTT = false,

		children = {
			imgCtrl,
            lblCtrl,
		},
        imgCtrl = imgCtrl,
        lblCtrl = lblCtrl,
	}
	self.control:AddChild(item)
    table.insert(self.items, item)
	return item
end
