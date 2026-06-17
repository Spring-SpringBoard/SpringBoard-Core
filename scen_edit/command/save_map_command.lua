SaveMapCommand = Command:extends{}
SaveMapCommand.className = "SaveMapCommand"

-- Native-only (see nativeCommandsOnly): the Rust module reads the live heightmap
-- and writes the `.data` file (LE f32 per grid point) at `path`. Lua never runs
-- execute() for this command.
function SaveMapCommand:init(path)
    self.path = path
end
