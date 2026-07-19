use crate::sbc::panels::runtime::Item;

use super::model::InfoField;
use super::model::InfoField::*;

pub(crate) fn layout() -> Vec<Item<InfoField>> {
    vec![
        Item::Field(Name),
        Item::Field(Description),
        Item::Field(Version),
        Item::Field(Author),
    ]
}
