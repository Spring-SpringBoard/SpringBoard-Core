.. _map_features:

Map Features
============

s11n export should be used if you want to export game objects (units, features, etc.) and load them in your standalone map.
Install s11n as you would normally:

1. Copy the `s11n <https://github.com/Spring-SpringBoard/SpringBoard-Core/tree/master/libs_sb/s11n>`_ and `LCS <https://github.com/Spring-SpringBoard/SpringBoard-Core/tree/master/libs_sb/lcs>`_ folders to the ``libs/s11n`` and ``libs/LCS`` folders of the map (create destination directories as necessary).

2. Copy `s11n_gadget_load.lua <https://github.com/Spring-SpringBoard/SpringBoard-Core/blob/master/libs_sb/s11n/s11n_gadget_load.lua>`_ from the ``s11n`` folder to ``LuaGaia/Gadgets/`` of the map folder.

Then setup s11n to load your exported objects:

1. Copy your exported s11n model file to map's ``mapconfig`` folder.

2. Copy `s11n_load_map_features.lua <https://github.com/Spring-SpringBoard/SpringBoard-Core/blob/master/libs_sb/s11n/s11n_load_map_features.lua>`_ to map's ``LuaGaia/Gadgets/`` folder.

3. Set the `file path <https://github.com/Spring-SpringBoard/SpringBoard-Core/blob/master/libs_sb/s11n/s11n_load_map_features.lua#L15>`_ to your s11n model file in the newly copied ``s11n_load_map_features.lua``
