GridView = LCS.class{}

function GridView:init(tbl)
	local defaults = {
		ctrl = {
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
		},
		OnSelectItem = {},
	}

	tbl = Table.Merge(tbl, defaults)
	local ctrl = tbl.ctrl
	tbl.ctrl = nil

	for k, v in pairs(tbl) do
		self[k] = v
	end

	self.iconX = ctrl.iconX
	self.iconY = ctrl.iconY

	self.items = {}

	-- we're using the fake control to handle skin-based rendering
	self._fakeControl = ImageListView:New{}

	self.control = LayoutPanel:New(ctrl)
	self.control.HitTest = function(ctrl, x,y)
		local cx,cy = ctrl:LocalToClient(x,y)
		local obj = LayoutPanel.HitTest(ctrl,cx,cy)
		if (obj) then return obj end
		if ctrl._cells == nil then
			return
		end
		local itemIdx = ctrl:GetItemIndexAt(cx,cy)
		return (itemIdx>=0) and ctrl
	end

	self.control.DrawItemBkGnd = function(ctrl, index)
		local cell = ctrl._cells[index]
		local itemPadding = ctrl.itemPadding

		local child = ctrl.children[index]
		if child.__no_background then
			return
		end

		if ctrl.selectedItems[index] then
			self._fakeControl:DrawItemBackground(cell[1] - itemPadding[1], cell[2] - itemPadding[2], cell[3] + itemPadding[1] + itemPadding[3], cell[4] + itemPadding[2] + itemPadding[4], "selected")
		else
			self._fakeControl:DrawItemBackground(cell[1] - itemPadding[1], cell[2] - itemPadding[2], cell[3] + itemPadding[1] + itemPadding[3], cell[4] + itemPadding[2] + itemPadding[4], "normal")
		end
	end

	self.control.OnSelectItem = {
		function(...)
			self:_OnSelectItem(...)
		end
	}
end

function GridView:_OnValidateSelectItem(obj, itemIdx, selected)
	if itemIdx == 0 then
		return
	end
	local item = self.control.children[itemIdx]
	return item
end

function GridView:_OnSelectItem(obj, itemIdx, selected)
	local item = self:_OnValidateSelectItem(obj, itemIdx, selected)
	if item then
		CallListeners(self.OnSelectItem, item, selected)
	end
end

function GridView:GetAllItems()
	return self.items
end

function GridView:GetSelectedItems()
	local items = {}
	for itemIdx, selected in pairs(self.control.selectedItems) do
		if selected then
			local item = self.control.children[itemIdx]
			table.insert(items, item)
		end
	end
	return items
end

function GridView:GetItem(itemIdx)
	return self.control.children[itemIdx]
end

function GridView:GetItemIndex(item)
	for itemIdx, child in pairs(self.contrl.children) do
		if child == item then
			return itemIdx
		end
	end
end

function GridView:SelectItem(itemIdx)
	self.control:SelectItem(itemIdx)
end

function GridView:DeselectAll()
	self.control:DeselectAll()
end

function GridView:NewItem(tbl)
	local defaults = {
		width  = self.iconX,
		height = self.iconY,
		padding = {0,0,0,0},
		itemPadding = {0,0,0,0},
		itemMargin = {0,0,0,0},
		useRTT = false,
	}
	tbl = Table.Merge(tbl, defaults)
	local item = Control:New(tbl)

	self.control:AddChild(item)
	table.insert(self.items, item)
	return item
end

function GridView:AddItem(caption, image, tooltip)
	local children = {}

	local imgCtrl, lblCtrl
	if image then
		local bottom = 0
		if caption then
			bottom = bottom + 20
		end
		imgCtrl = Image:New {
			x = 0,
			y = 0,
			right = 0,
			bottom = bottom,
			file = image,
		}
		table.insert(children, imgCtrl)
	end
	if caption then
	    lblCtrl = Label:New {
	        width = "100%",
			x = 0,
			height = 20,
			right = 0,
			bottom = 0,
	        align = 'center',
	        autosize = false,
	        caption = caption,
	        --fontsize = 12,
	    }
		table.insert(children, lblCtrl)
	end

	local item = self:NewItem({
		tooltip = tooltip,
		children = children,
        imgCtrl = imgCtrl,
        lblCtrl = lblCtrl,
	})
	return item
end

function GridView:ClearItems()
	self.items = {}
    --self.control:DeselectAll()
    self.control:ClearChildren()
end

function GridView:StartMultiModify()
	self.control:DisableRealign()
end

function GridView:EndMultiModify()
	self.control:EnableRealign()
    self.control:RequestRealign()
    if self.control.parent then
        self.control.parent:RequestRealign()
        self.control.parent:Invalidate()
    end
    self.control:UpdateLayout()
    self.control:Invalidate()
end
