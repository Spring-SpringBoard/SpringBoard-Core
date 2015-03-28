AbstractCommand = LCS.class{}

function AbstractCommand:init()
end

function AbstractCommand:execute()
end

-- currently this is done on the gadget side, so translation is difficult
-- TODO: a more complex method of creating things to display is needed
-- maybe i18n tables? e.g.: {"cmd-units-added", {units=5}} ?
-- supporting both tables and strings seems to be the easiest option
function AbstractCommand:display()
    return self.className .. " executed."
end