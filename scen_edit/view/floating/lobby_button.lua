LobbyButton = LCS.class{}

function LobbyButton:init()
    local luaMenu = Spring.GetMenuName and Spring.SendLuaMenuMsg and Spring.GetMenuName()
    if not luaMenu or luaMenu == "" then
        return
    end

    Spring.SendLuaMenuMsg("disableLobbyButton")
    self.btnMenu = Button:New {
        x = 5,
        y = 35,
        width = 100,
        height = 50,
        font = {
            size = 22,
            outline = true,
        },
        parent = screen0,
        caption = "Menu",
        OnClick = {
            function()
                Spring.SendLuaMenuMsg("showLobby")
            end
        }
    }
end
