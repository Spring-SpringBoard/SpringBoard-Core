Meta programming
================

Meta programming consists of defining a meta model which is later used in GUI programming, and it provides a way of extending the Scenario Editor trigger functionality to suite a specfic game or scenario. This is done by creating meta model files that define custom action and function types. 

A metal model file has the following format:

.. code-block:: lua

    return {
        actions = ..., -- table (or Lua function that returns a table) consisting of action types
        functions = ..., -- table (or Lua function that returns a table) consisting of function types
    }

.. TODO: Explain the difference, give a reference to the function type definition.
.. note:: There's a difference between a *Lua* function and a function type in the *meta model*. The *function type* represents a component in the meta model and is defined with a table.

Actions
-------

Example of a meta programming file:

.. code-block:: lua
    
    return {
        actions = {
            {
                humanName = "Hello world",
                name = "MY_HELLO_WORLD",
                execute = function()
                    Spring.Echo("Hello world")
                end,
            },
        },
    }

This file defines a single action. The *name* and *humanName* properties of the action define the machine (must be unique) and display name respectively. The *execute* property defines the function to be executed when the trigger is successfully fired. When used in the editor, this action would print a *Hello World* on the screen.

It is common for actions to receive *input* that defines its behavior. One such example would be:

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
    
As one might guess, this action would take the specified *unit* as *input* and print out its position. The GUI editor will parse the input type and the user (GUI programmer) will be able to specify the unit when creating an instance of this action. Normally in Lua this would look like:

.. code-block:: lua

    PRINT_UNIT_POSITION(unit)

Functions
---------

The real power of the meta programming comes with the introduction of function types. Function types produce an output (result of the function), which often depends on the input. 

.. note:: Function types should not have a side effect (they shouldn't cause any changes to the game state), but they don't have to be pure (they don't need to produce the same output for the same input).

Example of a function type:

.. code-block:: lua

    {
        humanName = "Unit Health",
        name = "UNIT_HEALTH",
        input = "unit",
        output = "number"
        execute = function(input)
            return Spring.GetUnitHealth(input.unit)
        end,
    }

This function type takes a *unit* as *input* and produce a *number* as *output*. A special class of these function types are those that return *bool* as *output*, and they represent *conditions* in the GUI programming.
