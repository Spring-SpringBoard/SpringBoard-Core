.. _game_specific_modules:

Game-specific modules
=====================

Game-specific modules can be created to customize the editor for a specific game. It can include :ref:`extensions <extensions>` and :ref:`meta-programming  <meta_programming>`, as well as settings and widget/gadget overrides.

This is achieved by creating `mutators <https://springrts.com/wiki/Modinfo.lua#Mutator>`_ which depend on SpringBoard-Core and the actual game. The `modinfo.lua <https://github.com/Spring-SpringBoard/SpringBoard-BA/blob/master/modinfo.lua>`_ mutator for Balanced Annihilation is given below:

.. code-block:: lua

    return {
      name = 'SpringBoard BA',
      shortname = 'SB_BA',
      game = 'SpringBoard BA',
      shortGame = 'SB_BA',
      description = 'SpringBoard for Balanced Annihilation',
      version = '$VERSION',
      mutator = 'Official',
      modtype = 1,
      depend = {
        -- Order matters. Putting game second ensures its widget/gadget handler is loaded

        'rapid://sbc:test',
        --'SpringBoard Core $VERSION',

        'rapid://ba:test',
        --'Balanced Annihilation $VERSION',
      },
    }

It is possible to use both the rapid dependencies (such as ``rapid://sbc:test``, ``rapid://ba:test``) as well as for local versions (``SpringBoard Core $VERSION``, ``Balanced Annihilation $VERSION``), which are more useful for development.

.. note:: It's important to first include SpringBoard Core and then the game.

Configuration
-------------

General configuration is given in the ``sb_settings.lua`` file. It allows to configure the following behavior:

- ``startStop``: Position of the startStop button.
- ``OnStartEditingSynced``: Function to be executed in synced when editing starts.
- ``OnStopEditingSynced``: Function to be executed in synced when editing stops.
- ``OnStartEditingUnsynced``: Function to be executed in unsynced when editing starts. This is commonly used to disable widgets that would get in the way of editing.
- ``OnStopEditingUnsynced``: Function to be executed in unsynced when editing stops. This is commonly used to reenable widgets that were disabled for editing.

Balanced Annihilation version of the file is given in `sb_settings.lua <https://github.com/Spring-SpringBoard/SpringBoard-BA/blob/master/sb_settings.lua>`_

Editor mode handling
--------------------

Sometimes it's necessary to have the game's widget or gadget act differently depending on whether it's currently being edited or not. It is possible to read the current state from the GameRules' ``sb_gameMode`` parameter, like:  ``Spring.GetGameRulesParam("sb_gameMode")``. It can return three values:

- ``"dev"``: SpringBoard is currently in edit mode and game mechanics (especially those depending on time) shouldn't be happening.
- ``"test"``: SpringBoard is currently being tested and game mechanics should work as normally. Additionally debug information can be printed out and it should be possible to return to the Editor (e.g. by clicking on the *Stop* button).
- ``"play"``: SpringBoard's is currently being played, like a normal scenario. All game mechanics should work as usual, with no debug/development information printed. It is not possible to return back to the Editor.

Example of how this can be handled is given for a `SpringBoard EVO gadget <https://github.com/Spring-SpringBoard/SpringBoard-EVO/blob/master/LuaRules/gadgets/game_controlVictory.lua#L1439-L1442>`_.

Examples
--------

Repositories:

- https://github.com/Spring-SpringBoard/SpringBoard-BA
- https://github.com/Spring-SpringBoard/SpringBoard-ZK
- https://github.com/Spring-SpringBoard/SpringBoard-EVO
- https://github.com/Spring-SpringBoard/SpringBoard-S44
