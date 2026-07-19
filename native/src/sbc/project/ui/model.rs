use crate::sbc::panels::fields::StringField;
use crate::sbc::panels::runtime::{TableEntry, TableModel};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum InfoField {
    Name,
    Description,
    Version,
    Author,
}

use InfoField::*;

pub(crate) fn info_model() -> TableModel<InfoField> {
    TableModel::new(vec![
        TableEntry::new(Name, Box::new(StringField::new("name", "Name", ""))),
        TableEntry::new(
            Description,
            Box::new(StringField::new("description", "Description", "")),
        ),
        TableEntry::new(
            Version,
            Box::new(StringField::new("version", "Version", "")),
        ),
        TableEntry::new(Author, Box::new(StringField::new("author", "Author", ""))),
    ])
}
