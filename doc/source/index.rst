.. SpringBoard documentation master file, created by
   sphinx-quickstart2 on Mon May 26 09:24:41 2014.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

SpringBoard: Editor for Spring
==============================

SpringBoard is an in-game editor for the `SpringRTS <https://springrts.com/>`_ engine, and it can be used to develop maps and scenarios.

Installing
----------
The production version can be obtained from rapid, via:
``pr-downloader sbc:test``

The development version can be obtained from this repository, by cloning it in your game folder:
``git clone https://github.com/Spring-SpringBoard/SpringBoard-Core SB-C.sdd``

Game-specific modules
---------------------
This is the core module, you may still want to get additional game-specific modules if you're making a scenario.

Some examples:

- https://github.com/Spring-SpringBoard/SpringBoard-BA
- https://github.com/Spring-SpringBoard/SpringBoard-ZK
- https://github.com/Spring-SpringBoard/SpringBoard-EVO

Assets
------

Any assets (texture files, skyboxes, etc.) should be put in the "springboard/assets" folder, located inside the Spring data directory.

Core assets can be obtained from the following
`link <https://drive.google.com/file/d/0B9FQjbVMFgL2LTM2Z1VVaGRZRDQ/view?usp=sharing>`_. Once downloaded, they should be extracted, with the resulting folder structure of "springboard/assets/core/".

Contents
--------

.. toctree::
   :maxdepth: 2

   installing
   getting_started
   gui_programming
   meta_programming
   extensions
   assets
   hot_keys
   api
