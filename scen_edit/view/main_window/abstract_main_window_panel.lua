AbstractMainWindowPanel = LCS.class.abstract{}
--subclasses of this class should assign a layoutpanel to the self.control variable

function TabbedPanelButton(tbl)
	return Button:New(Table.Merge({
		width = SB.conf.TOOLBOX_ITEM_WIDTH,
		height = SB.conf.TOOLBOX_ITEM_HEIGHT,
		caption = '',
		padding = {0, 0, 0, 0},
	}, tbl))
end

function TabbedPanelImage(tbl)
	return Image:New(Table.Merge({
		width = SB.conf.TOOLBOX_ITEM_WIDTH / 2,
		height = SB.conf.TOOLBOX_ITEM_HEIGHT / 2,
		margin = {0, 0, 0, 0},
		x = SB.conf.TOOLBOX_ITEM_WIDTH / 4,
		y = SB.conf.TOOLBOX_ITEM_HEIGHT / 8,
	}, tbl))
end

function TabbedPanelLabel(tbl)
	return Label:New(Table.Merge({
		bottom = SB.conf.TOOLBOX_ITEM_HEIGHT / 8,
		width = SB.conf.TOOLBOX_ITEM_WIDTH,
		align = "center",
		font = {
			size = math.floor(SB.conf.TOOLBOX_ITEM_WIDTH / 5),
		},
	}, tbl))
end

function AbstractMainWindowPanel:init()
	self.control = LayoutPanel:New {
		x = 0,
		y = 0,
		bottom = 0,
		right = 0,
		padding = { 5, 5, 0, 0},
		itemPadding = {0, 0, 0, 0},
        itemMargin = {0, 0, 0, 0},
		children = {},
		centerItems = false,
	}
end

function AbstractMainWindowPanel:getControl()
	return self.control
end
