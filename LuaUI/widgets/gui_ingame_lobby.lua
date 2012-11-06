function widget:GetInfo()
  return {
    name      = "Ingame Lobby",
    desc      = "Example of an in-game lua lobby implementation",
    author    = "gajop",
    date      = "in the future",
    license   = "GPL-v2",
    layer     = 1001,
    enabled   = false,
  }
end

local lobby

function widget:Initialize()
	lobby = Spring.CreateLobby()
end