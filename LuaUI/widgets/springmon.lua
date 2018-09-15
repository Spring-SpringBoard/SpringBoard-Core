function widget:GetInfo()
	return {
        name      = "springmon",
        desc      = "Spring File autoreloader",
        author    = "gajop",
        date      = "in the future",
        license   = "GPL-v2",
		layer     = -1000,
		enabled   = true,
		handler   = true,
		api       = true,
		hidden    = true,
	}
end

function widget:Initialize()
	WG.Connector.Register("FileChanged", function(command)
		local path = command.path
		local widgetName
		for k, w in pairs(WG.SB_widgetHandler.knownWidgets) do
			-- Spring.Echo("Widget", k, w)
			if path:find(w.filepath) then
				widgetName = w.name
				break
			end
		end
		if not widgetName then
			return
		end
		widgetHandler:DisableWidget(widgetName)
		widgetHandler:EnableWidget(widgetName)
	end)
end
