--- Command module

--- Command class. Inherit to implement a custom command.
-- @type Command
-- @tparam[opt=nil] function unexecute If defined, this class method should undo changes done in :execute().
-- @tparam[opt=false] boolean blockUndo If true, this will disable undo for classes that define the :unexecute() method.
-- @tparam[opt=false] boolean _execute_unsynced If true, the command will be executed in the unsynced state.
-- @tparam[opt=nil] string mergeCommand Name of the merge command class. This command is invoked to merge multiple consecutive commands into one.
-- @tparam[opt=nil] function onMerge Function to be invoked when merging multiple commands.
Command = LCS.class.abstract{}

--- Execute the command. Should not be invoked directly.
-- @see command_manager.CommandManager
function Command:execute()
end

-- Specify the :unexecute() to provide the inverse action (for undo)
-- function Command:unexecute()
-- end

--- Display the command
-- @return Text to be displayed to the user. By default, it returns the command className.
function Command:display()
    -- currently this is done on the gadget side, so translation is difficult
    -- TODO: a more complex method of creating things to display is needed
    -- maybe i18n tables? e.g.: {"cmd-units-added", {units=5}} ?
    -- supporting both tables and strings seems to be the easiest option
    return self.className
end

-- Specify the onMerge command to execute for multipleCommandMode
-- function Command:onMerge()
-- end
