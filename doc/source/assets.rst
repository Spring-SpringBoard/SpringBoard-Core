.. _assets:

Assets
==========

Assets can be added to SpringBoard in order to include new art for editing. They should be added in the `springboard/assets` folder, and each asset pack should have its own directory structure.

SpringBoard supports the following asset types:

- **Brush patterns** _/brush_patterns/_. These should be black images with an alpha determining the value.
- **Materials** _/materials/_. Materials consist of multiple different textures (`diffuse`, `specular` and `normal`), which should be contained in different image files, in the "name_$texType.png" format, e.g. `cement_diffuse.png` and `cement_specular.png`.
- **Skyboxes** _/skyboxes/_. These should be `.dds` skybox textures.
- **Detail textures** _/detail/_. These are the usual Spring detail textures.
