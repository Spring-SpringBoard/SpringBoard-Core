.. _extensions:

Extensions
==========

SpringBoard support editor extensions. They should be created in separate folders, in the ``springboard/exts`` folder, and they consist of two subfolders:

- **ui**. This is where you should place all strictly unsynced extensions, like the Editor GUI and States.
- **cmd**. This folder should contain files that should be shared by both synced and unsynced extensions, like Command and Model.

Example
-------

We present a full example of a SpringBoard extension consisting of *ui* and *cmd* modules.
This example is located in the `exts/example <https://github.com/Spring-SpringBoard/SpringBoard-Core/tree/master/exts/example>`_ folder of the repository.

First we will define the UI elements, given in the `ui/example.lua <https://github.com/Spring-SpringBoard/SpringBoard-Core/tree/master/exts/example/ui/example.lua>`_ file.
At the top of the file, we will include the *Editor* class and make a new *ExampleEditor* subclass out of it, with which we will define our custom *Editor*.

.. code-block:: lua

    SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

    ExampleEditor = Editor:extends{}

We will then register the newly defined class to make it accessible in the SpringBoard interface.

.. code-block:: lua

    Editor.Register({
        name = "exampleEditor",
        editor = ExampleEditor,
        tab = "Example",
        caption = "Example",
        tooltip = "Example editor",
        image = SB_IMG_DIR .. "globe.png",
    })

Then in the init method, we will define the fields. We create two *NumericFields*: *example* and *undoable*, and we add them to the *Editor*.

.. code-block:: lua

    function ExampleEditor:init()
        self:super("init")

        self.initializing = true

        self:AddField(NumericField({
            name = "example",
            title = "Example:",
            tooltip = "Example value tooltip.",
            width = 140,
            minValue = -10,
            maxValue = 5,
        }))

        -- Note: as we are setting the value in synced only, we won't see the effect of undo in the editor.
        -- Consider using game rules if you want to be able to read in the UI as well.
        self:AddField(NumericField({
            name = "undoable",
            title = "Undoable:",
            tooltip = "This value can be used with undo/redo.",
            width = 140,
            minValue = -3,
            maxValue = 12,
        }))

        local children = {
            ScrollPanel:New {
                x = 0,
                y = 0,
                bottom = 30,
                right = 0,
                borderColor = {0,0,0,0},
                horizontalScrollbar = false,
                children = { self.stackPanel },
            },
        }

        self:Finalize(children)
        self.initializing = false
    end

To handle field changes, we will create an *OnFieldChange* method, and when fields change, we will create and execute appropriate *Commands*.

.. code-block:: lua

    function ExampleEditor:OnFieldChange(name, value)
        if name == "example" then
            local cmd = HelloWorldCommand(value)
            SB.commandManager:execute(cmd)
        elseif name == "undoable" then
            local cmd = UndoableExampleCommand(value)
            SB.commandManager:execute(cmd)
        end
    end

We also want to group all changes for the *UndoableExampleCommand* into a single undo/redo command on the command stack, and for that purpose we use the *SetMultipleCommandModeCommand* command.

.. code-block:: lua

    function ExampleEditor:OnStartChange(name)
        if name == "undoable" then
            SB.commandManager:execute(SetMultipleCommandModeCommand(true))
        end
    end

    function ExampleEditor:OnEndChange(name)
        if name == "undoable" then
            SB.commandManager:execute(SetMultipleCommandModeCommand(false))
        end
    end

We also need to define the two commands. This is done in separate files, in the `cmd folder <https://github.com/Spring-SpringBoard/SpringBoard-Core/tree/master/exts/example/cmd>`_, which makes the Commands accessible from both unsynced (GUI) and synced (execution).
The *HelloWorldCommand* is rather simple, and it just prints out a single line of text.

.. code-block:: lua

    HelloWorldCommand = Command:extends{}
    HelloWorldCommand.className = "HelloWorldCommand"

    function HelloWorldCommand:init(number)
        self.number = number
    end

    function HelloWorldCommand:execute()
        Spring.Echo("Hello world: " .. tostring(self.number))
    end

The *UndoableExampleCommand* is slightly more complicated as it also has a value that can be changed. In the *:unexecute()* method we revert it to its previous value.

.. code-block:: lua

    UndoableExampleCommand = Command:extends{}
    UndoableExampleCommand.className = "UndoableExampleCommand"

    local value = 0
    function UndoableExampleCommand:init(number)
        self.number = number
    end

    function UndoableExampleCommand:execute()
        Spring.Echo("Setting value: " .. tostring(self.number))
        self.old = value
        value = self.number
    end

    function UndoableExampleCommand:unexecute()
        Spring.Echo("Reverting to: " .. tostring(self.old))
        value = self.old
    end

.. note:: Displaying a synchronized value in the GUI requires additional steps. Depending on how this value is kept, things like RulesParams can be used. Refer to the Spring documentation for details: https://springrts.com/wiki/Lua_SyncedCtrl#RulesParams https://springrts.com/wiki/Lua_SyncedRead#RulesParams

.. _extension_games:

Extensions used in games
------------------------

Zero-K's `metal spot extension <https://github.com/Spring-SpringBoard/SpringBoard-ZK/tree/master/springboard/exts/metal_spots>`_.

This extension describes how the `ObjectBridge API <./_static/modules/model.object.object_bridge.html>`_ can be used to create new, custom editors for game world objects.
