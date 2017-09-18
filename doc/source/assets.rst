.. _assets:

Assets
==========

Assets can be added to SpringBoard in order to include new art for editing. They should be added in the `springboard/assets` folder, and each asset pack should have its own directory structure.

SpringBoard supports the following asset types:

- **Brush patterns** */brush_patterns*. These should be black images with an alpha determining the value.
- **Materials** */materials*. Materials consist of multiple different textures (`diffuse`, `specular` and `normal`), which should be contained in different image files, in the "name_$texType.png" format, e.g. `cement_diffuse.png` and `cement_specular.png`.
- **Skyboxes** */skyboxes*. These should be `.dds` skybox textures.
- **Detail textures** */detail*. These are the usual Spring detail textures.

Core assets can be obtained from the following `link <https://drive.google.com/file/d/0B9FQjbVMFgL2LTM2Z1VVaGRZRDQ/view?usp=sharing>`_. Once downloaded, they should be extracted, with the resulting folder structure of ``springboard/assets/core/``.
