-- this basically just exposes some widgetHandler methods to SB

function widget:GetInfo()
	return {
        name      = "HANDLER_SpringBoard_widget",
        desc      = "HANDLER_Game-independent editor (widget)",
        author    = "gajop",
        license   = "MIT",
		layer     = -2000,
		enabled   = true,  --  loaded by default?
		handler   = true,
		api       = true,
		hidden    = true,
	}
end

function widget:Initialize()
    WG.SB_widgetHandler = widgetHandler
end
