//! One module per editor view. Each registers itself with the shell's editor
//! registry, so adding (or merging) a view touches nothing else.

mod brush;
mod env_lighting;
mod env_sky;
mod env_water;
mod map_grass;
mod map_metal;
mod map_settings;
mod map_terrain;
mod map_texture;
mod misc_info;
mod misc_teams;
mod object_defs;
mod objects_features;
mod objects_properties;
mod objects_units;
