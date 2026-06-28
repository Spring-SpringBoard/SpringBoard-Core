use serde::Deserialize;

/// Object kinds that flow through the add / remove / set-param commands.
///
/// Dispatch stays out of this type: each kind registers its own s11n handler, and
/// `ObjectManager` routes through that registry instead of matching variants.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ObjectKind {
    Unit,
    Feature,
    Area,
}
