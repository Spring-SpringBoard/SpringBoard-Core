//! The Type / Wreck / Terrain filters over the Objects tab's definition grids,
//! ported from `ObjectDefsPanel:IsValidUnit` / `IsValidFeature`.
//!
//! Both grids filter on *unit* traits: a unit def directly, and a feature def
//! through the unit it is the wreck of. The traits come from the engine's
//! UnitDef property table.

use spring_native::prelude::NativeInterfaceRef;

/// The filter choices, in the order Lua lists them. The captions are the items
/// of the choice fields, and the index is Lua's `...ID`.
pub(crate) const UNIT_TYPES: &[&str] = &["Units", "Buildings", "All"];
pub(crate) const FEATURE_TYPES: &[&str] = &["Other", "Wreckage", "All"];
pub(crate) const TERRAINS: &[&str] = &["Ground", "Air", "Water", "All"];

/// What a unit def is, as far as the filters care.
#[derive(Debug, Clone, Copy, Default)]
pub(crate) struct UnitTraits {
    pub is_building: bool,
    pub can_fly: bool,
    pub can_hover: bool,
    pub float_on_water: bool,
    pub can_submerge: bool,
    pub waterline: f32,
    pub min_water_depth: f32,
}

impl UnitTraits {
    /// Read the traits the filters need straight off the engine's UnitDef table.
    pub(crate) fn read(interface: &NativeInterfaceRef, unit_def_id: i32) -> UnitTraits {
        let defs = interface.unit_defs();
        let flag = |key: &str| {
            defs.get_unit_def_param_bool(unit_def_id, key)
                .unwrap_or(false)
        };
        let number = |key: &str| {
            defs.get_unit_def_param_float(unit_def_id, key)
                .unwrap_or(0.0)
        };

        UnitTraits {
            is_building: flag("isBuilding"),
            can_fly: flag("canFly"),
            can_hover: flag("canHover"),
            float_on_water: flag("floatOnWater"),
            can_submerge: flag("canSubmerge"),
            waterline: number("waterline"),
            min_water_depth: number("minWaterDepth"),
        }
    }

    /// Lua: `unitTypesID == 2 and isBuilding or unitTypesID == 1 and not isBuilding or unitTypesID == 3`.
    fn matches_type(&self, choice: &str) -> bool {
        match choice {
            "Units" => !self.is_building,
            "Buildings" => self.is_building,
            _ => true,
        }
    }

    /// Lua's terrain test. "Ground" is the absence of every other trait, so a
    /// unit that merely *can* float is not ground.
    fn matches_terrain(&self, choice: &str) -> bool {
        match choice {
            "Ground" => {
                !self.can_fly
                    && !self.float_on_water
                    && !self.can_submerge
                    && self.waterline == 0.0
                    && self.min_water_depth <= 0.0
            }
            "Air" => self.can_fly,
            "Water" => {
                self.can_hover
                    || self.float_on_water
                    || self.waterline > 0.0
                    || self.min_water_depth > 0.0
            }
            _ => true,
        }
    }
}

/// A definition, as the filters see it.
#[derive(Debug, Clone, Copy, Default)]
pub(crate) struct DefTraits {
    /// For a feature: the unit it is the wreck of, if any. For a unit: itself.
    pub unit: Option<UnitTraits>,
}

impl DefTraits {
    pub(crate) fn of_unit(interface: &NativeInterfaceRef, unit_def_id: i32) -> DefTraits {
        DefTraits {
            unit: Some(UnitTraits::read(interface, unit_def_id)),
        }
    }

    /// A feature is a wreck if its name, with `_heap`/`_dead` stripped, names a
    /// unit -- which is exactly how Lua decides it.
    pub(crate) fn of_feature(interface: &NativeInterfaceRef, feature_name: &str) -> DefTraits {
        let base = feature_name.replace("_heap", "").replace("_dead", "");
        let unit_def_id = interface
            .unit_defs()
            .get_unit_def_idby_name(&base)
            .unwrap_or(0);
        if unit_def_id <= 0 {
            return DefTraits { unit: None };
        }
        DefTraits::of_unit(interface, unit_def_id)
    }

    fn is_wreck(&self) -> bool {
        self.unit.is_some()
    }

    /// Does this unit def pass the Units view's filters?
    pub(crate) fn passes_unit_filters(&self, unit_type: &str, terrain: &str) -> bool {
        let Some(unit) = self.unit else {
            return false;
        };
        unit.matches_type(unit_type) && unit.matches_terrain(terrain)
    }

    /// Does this feature def pass the Features view's filters?
    ///
    /// Lua only applies the Wreck and Terrain filters to a *wreck*: a plain
    /// feature (a tree, a rock) has no unit behind it to test.
    pub(crate) fn passes_feature_filters(
        &self,
        feature_type: &str,
        wreck_type: &str,
        terrain: &str,
    ) -> bool {
        if feature_type == "All" {
            return true;
        }
        let wanted_wreck = feature_type == "Wreckage";
        if self.is_wreck() != wanted_wreck {
            return false;
        }
        if !wanted_wreck {
            return true;
        }
        self.passes_unit_filters(wreck_type, terrain)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ground_unit() -> UnitTraits {
        UnitTraits::default()
    }

    #[test]
    fn ground_means_no_air_and_no_water_traits() {
        assert!(ground_unit().matches_terrain("Ground"));

        let mut floater = ground_unit();
        floater.float_on_water = true;
        assert!(
            !floater.matches_terrain("Ground"),
            "a floater is not ground"
        );
        assert!(floater.matches_terrain("Water"));

        let mut deep = ground_unit();
        deep.min_water_depth = 5.0;
        assert!(!deep.matches_terrain("Ground"));
        assert!(deep.matches_terrain("Water"));

        let mut flyer = ground_unit();
        flyer.can_fly = true;
        assert!(!flyer.matches_terrain("Ground"));
        assert!(flyer.matches_terrain("Air"));
    }

    #[test]
    fn all_matches_everything() {
        let mut flyer = ground_unit();
        flyer.can_fly = true;
        assert!(flyer.matches_terrain("All"));
        assert!(flyer.matches_type("All"));
    }

    #[test]
    fn buildings_and_units_are_complementary() {
        let mut building = ground_unit();
        building.is_building = true;
        assert!(building.matches_type("Buildings"));
        assert!(!building.matches_type("Units"));
        assert!(ground_unit().matches_type("Units"));
        assert!(!ground_unit().matches_type("Buildings"));
    }

    /// A tree is not a wreck, so Wreckage excludes it and Other keeps it -- and
    /// the wreck-only filters must not be applied to it.
    #[test]
    fn a_plain_feature_is_not_a_wreck() {
        let tree = DefTraits { unit: None };
        assert!(tree.passes_feature_filters("Other", "Units", "Ground"));
        assert!(!tree.passes_feature_filters("Wreckage", "All", "All"));
        assert!(tree.passes_feature_filters("All", "Units", "Air"));
    }

    #[test]
    fn a_wreck_is_filtered_by_the_unit_it_came_from() {
        let mut building = ground_unit();
        building.is_building = true;
        let wreck = DefTraits {
            unit: Some(building),
        };

        assert!(wreck.passes_feature_filters("Wreckage", "Buildings", "Ground"));
        assert!(!wreck.passes_feature_filters("Wreckage", "Units", "Ground"));
        assert!(!wreck.passes_feature_filters("Other", "All", "All"));
    }
}
