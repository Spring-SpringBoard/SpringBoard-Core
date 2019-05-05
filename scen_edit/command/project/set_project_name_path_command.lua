SetProjectNamePathCommand = Command:extends{}
SetProjectNamePathCommand.className = "SetProjectNamePathCommand"

function SetProjectNamePathCommand:init(name, path)
    self.name = name
    self.path = path
end

function SetProjectNamePathCommand:execute()
    -- Also modify the dependency mutator as necessary
    if SB.project.name ~= nil then
        for i = 1, #SB.project.mutators do
            local mutator = SB.project.mutators[i]
            if String.Starts(mutator, SB.project.name) then
                SB.project.mutators[i] = self.name .. ' 1.0'
            end
        end
    end

    SB.project.name = self.name
    SB.project:SetPath(self.path)
end
