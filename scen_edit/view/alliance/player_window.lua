PlayerWindow = LCS.class{}

function PlayerWindow:init(team)
    self.team = team

    self.lblName = Label:New {
        x = 5,
        y = 15,
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = 50,
        caption = "Name:",
    }
    self.ebName = EditBox:New {
        x = 65,
        y = 15,
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = 200,
        text = team.name,
    }

    self.cbAI = Checkbox:New {
        x = 5,
        y = SCEN_EDIT.conf.B_HEIGHT + 25,
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = 70,
        checked = not not team.ai,
        caption = "AI",
    }
	
	local metal, metalMax = Spring.GetTeamResources(team.id, "metal")
	if metal == nil then
		metal = team.metal or 1000
	end
	if metalMax == nil then
		metalMax = team.metalMax or 1000
	end
	self.lblMetal = Label:New {
        x = 5,
        y = 2 * SCEN_EDIT.conf.B_HEIGHT + 35,
        height = 60,
        width = 50,
        caption = "Metal:",
    }
    self.ebMetal = EditBox:New {
        x = 65,
        y = 2 * SCEN_EDIT.conf.B_HEIGHT + 35,
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = 100,
		text = tostring(metal),
    }
	self.lblMetalMax = Label:New {
        x = 175,
        y = 2 * SCEN_EDIT.conf.B_HEIGHT + 35,
        height = 60,
        width = 30,
        caption = "Max:",
    }
    self.ebMetalMax = EditBox:New {
        x = 220,
        y = 2 * SCEN_EDIT.conf.B_HEIGHT + 35,
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = 100,
		text = tostring(metalMax),
    }
			
	local energy, energyMax = Spring.GetTeamResources(team.id, "energy")
	if energy == nil then
		energy = team.energy or 1000
	end
	if energyMax == nil then
		energyMax = team.energyMax or 1000
	end	
	self.lblEnergy = Label:New {
        x = 5,
        y = 3 * SCEN_EDIT.conf.B_HEIGHT + 45,
        height = 60,
        width = 50,
        caption = "Energy:",
    }
    self.ebEnergy = EditBox:New {
        x = 65,
        y = 3 * SCEN_EDIT.conf.B_HEIGHT + 45,
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = 100,
		text = tostring(energy),
    }
	self.lblEnergyMax = Label:New {
        x = 175,
        y = 3 * SCEN_EDIT.conf.B_HEIGHT + 45,
        height = 60,
        width = 30,
        caption = "Max:",
    }
    self.ebEnergyMax = EditBox:New {
        x = 220,
        y = 3 * SCEN_EDIT.conf.B_HEIGHT + 45,
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = 100,
		text = tostring(energyMax),
    }

    self.lblColor = Label:New {
        x = 5,
        y = 4 * SCEN_EDIT.conf.B_HEIGHT + 55,
        height = 60,
        width = 50,
        caption = "Color:",
    }
    self.clbColor = Colorbars:New {
        x = 65,
        y = 4 * SCEN_EDIT.conf.B_HEIGHT + 55,
        height = 60,
        width = 300,
        color = {team.color.r, team.color.g, team.color.b, team.color.a},
    }
	
    self.btnClose = Button:New {
        caption = 'Close',
        width = 100,
        right = 1,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        OnClick = { function() self.window:Dispose() end }
    }
    self.window = Window:New {
        width = 400,
        height = 320,
        resizable = false,
        parent = screen0,
        caption = "Player",
        x = 500,
        y = 200,
        children = {
            self.lblName,
            self.ebName,
			self.lblMetal,
			self.ebMetal,
			self.lblMetalMax,
			self.ebMetalMax,
			self.lblEnergy,
			self.ebEnergy,
			self.lblEnergyMax,
			self.ebEnergyMax,
            self.cbAI,
            self.lblColor,
            self.clbColor,
            self.btnClose,
        },
        OnDispose = { 
            function()
                local newTeam = SCEN_EDIT.deepcopy(team)
                newTeam.name = self.ebName.text
                local clbColor = self.clbColor.color
                newTeam.color.r = clbColor[1]
                newTeam.color.g = clbColor[2]
                newTeam.color.b = clbColor[3]
                newTeam.color.a = clbColor[4]
                newTeam.ai = self.cbAI.checked				
				newTeam.metal = tonumber(self.ebMetal.text) or energyMax
				newTeam.metalMax = tonumber(self.ebMetalMax.text) or metalMax
				newTeam.energy = tonumber(self.ebEnergy.text) or energy
				newTeam.energyMax = tonumber(self.ebEnergyMax.text) or energyMax				
                local cmd = UpdateTeamCommand(newTeam)
                SCEN_EDIT.commandManager:execute(cmd)
            end
        },
    }
end
