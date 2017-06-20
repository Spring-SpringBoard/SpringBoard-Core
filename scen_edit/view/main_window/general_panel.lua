GeneralPanel = AbstractMainWindowPanel:extends{}

function GeneralPanel:init()
	self:super("init")
	self:AddElement({
		caption = "Info",
		tooltip = "Edit project info",
		image = SB_IMG_DIR .. "info.png",
		ViewClass = ScenarioInfoView,
		viewName = "scenarioInfoView",
	})
	self:AddElement({
		caption = "Alliances",
		tooltip = "Edit alliances",
		image = SB_IMG_DIR .. "shaking-hands.png",
		ViewClass = DiplomacyWindow,
		viewName = "diplomacyWindow",
	})
	self:AddElement({
		caption = "Teams",
		tooltip = "Edit teams",
		image = SB_IMG_DIR .. "person.png",
		ViewClass = PlayersWindow,
		viewName = "playersWindow",
	})
end
