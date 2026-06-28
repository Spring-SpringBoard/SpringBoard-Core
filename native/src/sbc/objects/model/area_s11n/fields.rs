use crate::sbc::objects::model::field::{FieldEntry, TypedField};
use crate::sbc::objects::model::field_descriptor::{
    FieldRange, FieldValueType, ObjectFieldDescriptor,
};
use crate::sbc::objects::model::object_data::Vec3;

use super::model::{area_center, area_extent, rect_with_center, rect_with_size, AreaModel};

inventory::collect!(FieldEntry<AreaModel>);

pub(super) fn entries() -> impl Iterator<Item = &'static FieldEntry<AreaModel>> {
    inventory::iter::<FieldEntry<AreaModel>>.into_iter()
}

pub(super) fn by_name(name: &str) -> Option<&'static FieldEntry<AreaModel>> {
    entries().find(|entry| entry.descriptor.name == name)
}

pub(super) fn descriptors() -> Vec<ObjectFieldDescriptor> {
    entries().map(|entry| entry.descriptor).collect()
}

struct Pos;
impl TypedField<AreaModel> for Pos {
    type Value = Vec3;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "pos",
        value_type: FieldValueType::Vec3,
        range: None,
        description: "Center of the editor area rectangle; y is ignored.",
    };

    fn get(state: &AreaModel, id: i32) -> Option<Vec3> {
        let (x, z) = area_center(*state.areas.get(&id)?);
        Some(Vec3 { x, y: 0.0, z })
    }

    fn set(state: &mut AreaModel, id: i32, pos: &Vec3) {
        if let Some(rect) = state.areas.get_mut(&id) {
            *rect = rect_with_center(*rect, pos.x, pos.z);
        }
    }
}
inventory::submit! { FieldEntry::of::<Pos>() }

struct Size;
impl TypedField<AreaModel> for Size {
    type Value = Vec3;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "size",
        value_type: FieldValueType::Vec3,
        range: Some(FieldRange::at_least(0.0)),
        description: "Width/depth of the editor area rectangle; y is ignored.",
    };

    fn get(state: &AreaModel, id: i32) -> Option<Vec3> {
        let (x, z) = area_extent(*state.areas.get(&id)?);
        Some(Vec3 { x, y: 0.0, z })
    }

    fn set(state: &mut AreaModel, id: i32, size: &Vec3) {
        if let Some(rect) = state.areas.get_mut(&id) {
            *rect = rect_with_size(*rect, size.x, size.z);
        }
    }
}
inventory::submit! { FieldEntry::of::<Size>() }
