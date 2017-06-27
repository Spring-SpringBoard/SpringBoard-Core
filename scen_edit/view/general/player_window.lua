SB.Include(SB_VIEW_DIR .. "editor.lua")

PlayerWindow = Editor:extends{}

function PlayerWindow:init(team)
    self:super("init")

    self.team = team

    self:AddField(StringField({
        name = "name",
        title = "Name:",
        tooltip = "Team name",
        value = team.name,
    }))

    self:AddField(BooleanField({
        name = "ai",
        title = "AI:",
        tooltip = "Is AI controlled",
        value = not not team.ai,
    }))

    local metal, metalMax = Spring.GetTeamResources(team.id, "metal")
    if metal == nil then
        metal = team.metal or 1000
    end
    if metalMax == nil then
        metalMax = team.metalMax or 1000
    end
    self:AddControl("metal-sep", {
        Label:New {
            caption = "Metal",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddField(GroupField({
        NumericField({
            name = "metal",
            title = "Metal:",
            tooltip = "Metal",
            value = metal,
            step = 0.2,
            width = 200,
        }),
        NumericField({
            name = "metalStorage",
            title = "Storage:",
            tooltip = "Metal storage",
            value = metalMax,
            step = 0.2,
            width = 200,
        }),
    }))

    local energy, energyMax = Spring.GetTeamResources(team.id, "energy")
    if energy == nil then
        energy = team.energy or 1000
    end
    if energyMax == nil then
        energyMax = team.energyMax or 1000
    end
    self:AddControl("energy-sep", {
        Label:New {
            caption = "Energy",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddField(GroupField({
        NumericField({
            name = "energy",
            title = "Energy:",
            tooltip = "Energy",
            value = energy,
            step = 0.2,
            width = 200,
        }),
        NumericField({
            name = "energyStorage",
            title = "Storage:",
            tooltip = "Energy storage",
            value = energyMax,
            step = 0.2,
            width = 200,
        }),
    }))


    self:AddField(ColorField({
        name = "color",
        title = "Color:",
        value = {team.color.r, team.color.g, team.color.b, team.color.a},
        tooltip = "Team color",
    }))

    self:AddField(AreaField({
        name = "startPos",
        title = "Start area:",
        value = team.startPos,
        tooltip = "Team starting position",
    }))

    local children = {}
    table.insert(children,
        ScrollPanel:New {
            x = 0,
            y = 0,
            bottom = 0,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        }
    )

    self:Finalize(children, {notMainWindow = true})

    table.insert(self.window.OnDispose, function()
        local newTeam = SB.deepcopy(team)
        newTeam.name        = self.fields["name"].value
        local clbColor      = self.fields["color"].value
        newTeam.color.r     = clbColor[1]
        newTeam.color.g     = clbColor[2]
        newTeam.color.b     = clbColor[3]
        newTeam.color.a     = clbColor[4] or 1
        newTeam.ai          = self.fields["ai"].value
        newTeam.metal       = self.fields["metal"].value or energyMax
        newTeam.metalMax    = self.fields["metalStorage"].value or metalMax
        newTeam.energy      = self.fields["energy"].value or energy
        newTeam.energyMax   = self.fields["energyStorage"].value or energyMax
        newTeam.startPos    = self.fields["startPos"].value
        local cmd = UpdateTeamCommand(newTeam)
        SB.commandManager:execute(cmd)
    end)
end
