.. _comparison:

Feature comparison
==================

Here we present a comparison between SpringBoard and other scenario editing software.

Spring tools
------------

The most popular alternative for a scenario editor in the SpringRTS ecosystem is the Zero-K Mission Editor (ZKME) `(link) <https://zero-k.info/Wiki/MissionEditorStartPage>`_.
It is primarily designed for Zero-K, but it has basic support for other games with similar mechanics.

Comparing SpringBoard to ZKME:

- ZKME runs as an external tool, while SpringBoard runs in-engine. This allows SpringBoard to offer WYSIWYG kind of editing, and also use camera controls that players are already familiar with.

- ZKME doesn't support expressions in functions and actions. This makes it hard to write complex conditions and actions, which limits expressibility.

- ZKME doesn't support variables which makes writing logic that depends on state difficult.

- ZKME only runs on Windows, while SpringBoard supports all platforms that work with the SpringRTS engine.

- ZKME isn't extensible, while SpringBoard has meta-programming which can be used to expose custom functionality to the GUI.

Other tools
-----------

Starcraft 2 and Warcraft 3 scenario editors are editors for the popular Starcraft 2 and Warcraft 3 games made by Blizzard entertainment.

Comparing them to SpringBoard:

- They are made for one game specifically, while SpringBoard can be used for any game using the SpringRTs engine.

- They are released under a proprietary license, and need to be paid to be used. SpringBoard is free and open source.

- They offer extensibility in terms of coding, while SpringBoard supports it with meta-programming. The SpringBoard approach allows extensions to be created by more experienced developers and they are seamlessly integrated within the editor, which makes them usable by novices.

SpringBoard, ZKME and Starcraft 2/Warcraft 3 editors all use a event/condition/action system, and that seems to be the most popular approach for defining scenarios.
