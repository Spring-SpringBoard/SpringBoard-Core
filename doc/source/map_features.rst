.. _map_features:

Map Features
============

s11n export should be used if you want to export game objects (units, features, etc.) and load them in your standalone map.
Install s11n as you would normally:

1. Copy the ``s11n`` folder to the ``libs/s11n`` folder of the map (create one if necessary).

2. Copy ``s11n_gadget_load.lua`` from the ``s11n`` folder to ``LuaGaia/Gadget``s of the map folder.

Then setup s11n to load your exported objects:

1. Copy your exported s11n model file to map's ``mapconfig`` folder.

2. Copy ``s11n_load_map_features.lua`` to map's ``LuaGaia/Gadgets``.

3. Set the file to your s11n model file in the newly copied ``s11n_load_map_features.lua``
