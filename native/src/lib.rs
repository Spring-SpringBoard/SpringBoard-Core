#![forbid(unsafe_code)]
#![allow(clippy::module_inception)]
#![allow(clippy::upper_case_acronyms)]

use spring_native::prelude::*;

mod sbc;

use sbc::sbc::SBC;

spring_native::export_module!(SBC);
