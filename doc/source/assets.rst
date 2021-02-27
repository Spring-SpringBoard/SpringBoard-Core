.. _assets:

Assets
==========

Assets can be added to SpringBoard in order to include new art for editing. They should be added in the ``springboard/assets`` folder, and each asset pack should have its own directory structure.

SpringBoard supports the following asset types:

- **Brush patterns** */brush_patterns*. These should be black images with an alpha determining the value.
- **Materials** */materials*. Materials consist of multiple different textures (``diffuse``, ``specular`` and ``normal``), which should be contained in different image files, in the ``name_$texType.png`` format, e.g. ``cement_diffuse.png`` and ``cement_specular.png``.
- **Skyboxes** */skyboxes*. These should be ``.dds`` skybox textures.
- **Detail textures** */detail*. These are the usual Spring detail textures.

A set of core assets are available. You can download them either via the launcher's ``Asset Download`` option (recommended), or manually via a `direct link <https://content.spring-launcher.com/core_v1.zip>`_. In case of a manual download, you need to extract them to ``springboard/assets/core/``.