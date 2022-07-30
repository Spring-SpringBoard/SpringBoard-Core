.. _installing:

Installing
==========

Using packaged builds
---------------------

The simplest way to download SpringBoard is by using one of the provided installers. They will automatically download all of the needed resources (engine, editor archives, maps) and setup files, and launch SpringBoard. They will also check for updates on launch and keep the editor updated.

Packages:

- `Windows build <https://github.com/Spring-SpringBoard/SpringBoard-Core/releases/download/v1.1335.0/SpringBoard-1.1335.0.exe>`_

- `Linux build <https://github.com/Spring-SpringBoard/SpringBoard-Core/releases/download/v1.1335.0/SpringBoard-1.1335.0.AppImage>`_

Once you have downloaded one of the above files, simply run them and install as necessary. After installation, it will download the necessary files and launch SpringBoard itself.

.. note:: Linux users need to make the downloaded .AppImage file executable, by doing ``chmod +x SpringBoard.AppImage``

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

Linux has additional software requirements:

- SDL (Ubuntu package: `libsdl2-2.0-0`)

- OpenAL (Ubuntu package: `libopenal1`)
