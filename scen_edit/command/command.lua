-- Abstract, root command that specifies the Command interface
Command = LCS.class.abstract{}

function Command:init()
end

function Command:execute()
end

-- Specify the :unexecute() to provide the inverse action (for undo)
-- function Command:unexecute()
-- end

-- currently this is done on the gadget side, so translation is difficult
-- TODO: a more complex method of creating things to display is needed
-- maybe i18n tables? e.g.: {"cmd-units-added", {units=5}} ?
-- supporting both tables and strings seems to be the easiest option
function Command:display()
    return self.className
end

-- Specify the onMerge command to execute for multipleCommandMode
-- function Command:onMerge()
-- end
