AbstractMainWindowPanel = LCS.class.abstract{}
--subclasses of this class should assign a layoutpanel to the self.control variable

function AbstractMainWindowPanel:init()
	self.control = LayoutPanel:New {
		x = 0,
		y = 0,
		bottom = 0,
		right = 0,
		padding = {10, 0, 0, 0},
		itemPadding = {0, 10, 10, 10},
        itemMargin = {0, 0, 0, 0},
		children = {},
		centerItems = false,
	}
end

function AbstractMainWindowPanel:getControl()
	return self.control
end