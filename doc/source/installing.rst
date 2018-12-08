.. _installing:

Installing
==========

Using packaged builds
---------------------

The simplest way to install SpringBoard is to download one of the packaged builds. These builds will automatically download all of the needed resources (engine, editor archives, maps) and setup files, and launch SpringBoard. They will also check for updates on launch and keep the editor updated.

Packages:

- `Windows build <http://spring-launcher.ams3.digitaloceanspaces.com/Spring-SpringBoard/SpringBoard-Core/SpringBoard%201.1013.0.exe>`_

- `Linux build <http://spring-launcher.ams3.digitaloceanspaces.com/Spring-SpringBoard/SpringBoard-Core/SpringBoard%201.1013.0.AppImage>`_

Once you have downloaded the zip files, extract them and run the SpringBoard executable. This will open a window that will download the necessary files and launch SpringBoard itself.

Manual setup
------------

It is also possible to manually setup SpringBoard. Please refer to the SpringRTS documentation for `downloading <https://springrts.com/wiki/Download>`_ and installing the engine and using `pr-downloader <https://springrts.com/wiki/Pr-downloader>`_.

The production version can be obtained from rapid, via:
``pr-downloader sbc:test``

The development version can be obtained from this repository, by cloning it in your game folder:
``git clone https://github.com/Spring-SpringBoard/SpringBoard-Core SB-C.sdd``

.. note:: Games can distribute their packages differently. Some games might include the editor as part of the ingame lobby. For more information, consult the game manual.

Hardware requirements
---------------------

SpringBoard runs on most machines that support the SpringRTS engine, with the requirements described `here <https://springrts.com/wiki/About#System_requirements>`_. The only additional requirement is that the Graphics Card drivers must support basic OpenGL Shaders (GLSL). Most modern GPUs should be usable, but it is necessary to ensure the system has newest OpenGL drivers (see `this <https://www.khronos.org/opengl/wiki/Getting_Started#Downloading_OpenGL>`_ for download instructions).

Additionally, for better performance having a good GPU will make terrain texture editing more efficient, while having a decent CPU and more RAM will make heightmap editing and scenario editing work more smoothly.

Software requirements
---------------------

Besides having OpenGL installed, it is necessary to install additional software on Linux:

- SDL (Ubuntu package: `libsdl2-2.0-0`)

- OpenAL (Ubuntu package: `libopenal1`)

- libCurl (Ubuntu package: `libcurl3`)
