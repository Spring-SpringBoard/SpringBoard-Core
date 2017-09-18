.. _installing:

Installing
==========

Using packaged builds
---------------------

The simplest way to install SpringBoard is to download one of the packaged builds. These builds will automatically download all of the needed resources (engine, editor archives, maps) and setup files, and launch SpringBoard.

Packages:

- `Windows build <https://drive.google.com/file/d/0B9FQjbVMFgL2WUYtVUJIRXpkY3M/view?usp=sharing>`_

- `Linux build <https://drive.google.com/file/d/0B9FQjbVMFgL2aE9lTElTQWVHUjg/view?usp=sharing>`_

Once you have downloaded the zip files, extract them and run the SpringBoard executable. This will open a window that will download the necessary files and launch SpringBoard itself.

Manual setup
------------

It is also possible to manually setup SpringBoard. Please refer to the SpringRTS documentation for `downloading <https://springrts.com/wiki/Download>`_ and installing the engine and using `pr-downloader <https://springrts.com/wiki/Pr-downloader>`_.

The production version can be obtained from rapid, via:
``pr-downloader sbc:test``

The development version can be obtained from this repository, by cloning it in your game folder:
``git clone https://github.com/Spring-SpringBoard/SpringBoard-Core SB-C.sdd``

.. note:: Games can distribute their packages differently. Some games might include the editor as part of the ingame lobby. For more information, consult the game's documentation.
