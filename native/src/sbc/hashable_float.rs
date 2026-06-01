use std::hash;

#[derive(Debug, Copy, Clone)]
pub struct HashableFloat(pub f32);

impl HashableFloat {
    fn key(&self) -> u32 {
        self.0.to_bits()
    }
}

impl hash::Hash for HashableFloat {
    fn hash<H>(&self, state: &mut H)
    where
        H: hash::Hasher,
    {
        self.key().hash(state)
    }
}

impl PartialEq for HashableFloat {
    fn eq(&self, other: &HashableFloat) -> bool {
        self.key() == other.key()
    }
}

impl Eq for HashableFloat {}
