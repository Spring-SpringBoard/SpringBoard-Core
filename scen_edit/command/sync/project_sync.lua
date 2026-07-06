----------------------------------------------------------
-- Widget callback commands
-- Rust owns project name/path/mutators (ProjectManager). It notifies the
-- Lua SB.project mirror here (in both states) so SB.project stays in sync
-- without re-implementing the name/path/mutator-rewrite logic in Lua.
----------------------------------------------------------
WidgetSetProjectCommand = Command:extends{}
WidgetSetProjectCommand.className = "WidgetSetProjectCommand"

function WidgetSetProjectCommand:init(name, path, mutators)
    self.name = name
    self.path = path
    self.mutators = mutators
end

function WidgetSetProjectCommand:execute()
    if SB.project == nil then
        return
    end
    if self.name ~= nil then
        SB.project.name = self.name
    end
    if self.path ~= nil then
        SB.project:SetPath(self.path)
    end
    SB.project.mutators = self.mutators or {}
end
