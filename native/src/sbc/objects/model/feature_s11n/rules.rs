use std::collections::HashMap;

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::objects::model::object_data::RuleValue;

/// Read a feature's rules params into a name->value map. `None` if it has none,
/// so the field is omitted from the serialized object.
pub(super) fn read_rules(
    interface: &NativeInterfaceRef,
    spring_id: i32,
) -> Option<HashMap<String, RuleValue>> {
    let rules = interface.rules_params();
    let names = rules.get_feature_rules_params(spring_id).ok()?;
    if names.is_empty() {
        return None;
    }
    let mut out = HashMap::with_capacity(names.len());
    for name in names {
        if let Ok((value, _los, exists)) = rules.get_feature_rules_param(spring_id, &name) {
            if exists {
                out.insert(name, RuleValue::from(value));
            }
        }
    }
    Some(out)
}

pub(super) fn write_rules(
    interface: &NativeInterfaceRef,
    spring_id: i32,
    rules: &HashMap<String, RuleValue>,
) {
    let api = interface.rules_params();
    for (name, value) in rules {
        let _ = api.set_feature_rules_param(spring_id, name, value.into(), RULES_PARAM_LOS_PRIVATE);
    }
}

/// LOS access for a rules-param set: private (readable by the owning ally).
const RULES_PARAM_LOS_PRIVATE: i32 = 1;
