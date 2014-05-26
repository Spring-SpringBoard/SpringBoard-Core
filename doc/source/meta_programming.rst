Meta programming
================

Meta programming consists of writing a meta model to be used in GUI programming. It is done by defining custom action and condition types, which are then used in the editor.
An example of meta programming would be defining an action such as:

.. code-block:: lua

    {
        humanName = "Hello world",
        name = "MY_HELLO_WORLD",
        execute = function()
            Spring.Echo("Hello world")
        end,
    }

The *name* and *humanName* properties define the machine (must be unique) and display name respectively. The *execute* property defines the function to be executed when the trigger is successfully fired. When used in the editor, this action would print a Hello World in the screen.

Additionally actions can receive *input*, which will be used in most cases. One such example would be:

.. code-block:: lua

    {
        humanName = "Print unit position",
        name = "PRINT_UNIT_POSITION",
        input = "unit",
        execute = function(input)
            local x, y, z = Spring.GetUnitPosition(input.unit)
            Spring.Echo("Unit position: ", x, y, z)
        end,
    }
    
As one might guess, this action would take the given *unit* as *input* and print out its position. The editor will automatically detect the input type and the user (GUI programmer) will be able to specify the unit when creating an instance of this action.
