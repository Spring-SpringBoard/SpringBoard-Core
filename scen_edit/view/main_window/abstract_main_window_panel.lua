AbstractMainWindowPanel = LCS.class.abstract{}
--subclasses of this class should assign a layoutpanel to the self.control variable

function TabbedPanelButton(tbl)
	return Button:New(table.merge({
		width = SCEN_EDIT.conf.TOOLBOX_ITEM_WIDTH,
		height = SCEN_EDIT.conf.TOOLBOX_ITEM_HEIGHT,
		caption = '',
		padding = {0, 0, 0, 0},
	}, tbl))
end

function TabbedPanelImage(tbl)
	return Image:New(table.merge({
		width = SCEN_EDIT.conf.TOOLBOX_ITEM_WIDTH / 2,
		height = SCEN_EDIT.conf.TOOLBOX_ITEM_HEIGHT / 2,
		margin = {0, 0, 0, 0},
		x = SCEN_EDIT.conf.TOOLBOX_ITEM_WIDTH / 4,
		y = SCEN_EDIT.conf.TOOLBOX_ITEM_HEIGHT / 8,
	}, tbl))
end

function TabbedPanelLabel(tbl)
	return Label:New(table.merge({
		bottom = SCEN_EDIT.conf.TOOLBOX_ITEM_HEIGHT / 8,
		width = SCEN_EDIT.conf.TOOLBOX_ITEM_WIDTH,
		align = "center",
		font = {
			size = math.floor(SCEN_EDIT.conf.TOOLBOX_ITEM_WIDTH / 5),
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