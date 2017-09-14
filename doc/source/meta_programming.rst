.. _meta_programming:

Meta programming
================

Trigger functionalities can be extended with Meta programming. It is possible to customize the following:

- :ref:`Events <events>`
- :ref:`Functions <functions>`
- :ref:`Actions <actions>`
- :ref:`Data types <data_types>`

Meta-model file format:

.. code-block:: lua

    return {
        dataTypes = ..., -- table (or Lua function that returns a table) consisting of action types
        events = ..., -- table (or Lua function that returns a table) consisting of action types
        actions = ..., -- table (or Lua function that returns a table) consisting of action types
        functions = ..., -- table (or Lua function that returns a table) consisting of function types
    }

.. _events:

Events
------

Events invoke triggers, and are caused by various Spring callins.

They have the following fields:

- **humanName** (mandatory). Human readable name for display in the UI.
- **name** (mandatory). Unique identifier that is used to produce readable models.
- **param** (optional). Additional, event data sources that are available to the entire trigger.
- **tags** (optional). List of human-readable tags used for grouping in the UI.


Example of event programming:

.. code-block:: lua

    {
        humanName = "Unit enters area",
        name = "UNIT_ENTER_AREA",
        param = { "unit", "area" },
    }

.. _actions:

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


.. _functions:

Functions
---------

The real power of the meta programming comes with the introduction of function types. Function types produce an output (result of the function), which often depends on the input.

.. TODO: Explain the difference, give a reference to the function type definition.

.. note:: There's a difference between a *Lua* function and a function type in the *meta model*. The *function type* represents a component in the meta model and is defined with a table.

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

.. _data_types:

Data types
----------

Example of the *Person* data type:

.. code-block:: lua

    {
        humanName = "Person",
        name = "person",
        input = {
            {
                name = "first_name",
                humanName = "First name",
                type = "string",
            },
            {
                name = "last_name",
                humanName = "Last name",
                type = "string",
            }
        }
    },
