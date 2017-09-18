.. _api:

API
==========

Full API can be found at `API <./_static/index.html>`_.

View
----

The API describing the View elements is described in the various `Field <./_static/modules/view.fields.field.html>`_ pages and and the `Editor class <./_static/modules/view.editor.html>`_.


State
-----

The State API consists of an `Abstract State class <./_static/modules/state.abstract_state.html>`_ which should be subclasses when implementing new behaviors, and the `State Manager class <./_static/modules/state.state_manager.html>`_ that can be invoked to read and modify current state.

Command
-------

The Command API is split into three parts, the base `Command interface <./_static/modules/command.command.html>`_, the `CompoundCommand class <./_static/modules/command.compound_command.html>`_ for grouping multiple commands into a single one and the the `CommandManager class <./_static/modules/command.command_manager.html>`_ for invoking execution of commands.

Model
-----

TODO
