//! A renderer reply too long for one Lua message (the engine refuses 64 KiB) arrives in parts:
//! `springboard|lab-part|<reply>|<part>|<parts>|<text>`, `<part>` counting from 0. Joined, the
//! texts are the reply's JSON. Format: see the game's `shipcore::lab::wire::messages`.

/// The parts of the reply arriving now.
#[derive(Default)]
pub(crate) struct Parts {
    reply: String,
    texts: Vec<Option<String>>,
}

impl Parts {
    /// Keep one part (what follows the prefix); the reply whole once its last part is in. A part
    /// of another reply drops what had come of the one before.
    pub fn take(&mut self, part: &str) -> Option<String> {
        let mut fields = part.splitn(4, '|');
        let reply = fields.next()?;
        let index: usize = fields.next()?.parse().ok()?;
        let count: usize = fields.next()?.parse().ok()?;
        let text = fields.next()?;
        if index >= count {
            return None;
        }
        if self.reply != reply || self.texts.len() != count {
            self.reply = reply.to_string();
            self.texts = vec![None; count];
        }
        self.texts[index] = Some(text.to_string());
        if self.texts.iter().any(Option::is_none) {
            return None;
        }
        let whole = self.texts.drain(..).flatten().collect();
        self.reply.clear();
        Some(whole)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_parts_join_in_any_order() {
        let mut parts = Parts::default();
        assert_eq!(parts.take("4|1|3|b"), None);
        assert_eq!(parts.take("4|0|3|a|with|bars"), None);
        assert_eq!(parts.take("4|2|3|c").as_deref(), Some("a|with|barsbc"));
        assert_eq!(parts.take("5|0|1|x").as_deref(), Some("x"));
    }

    #[test]
    fn a_new_reply_drops_an_unfinished_one() {
        let mut parts = Parts::default();
        assert_eq!(parts.take("1|0|2|old"), None);
        assert_eq!(parts.take("2|1|2|B"), None);
        assert_eq!(parts.take("2|0|2|A").as_deref(), Some("AB"));
        assert_eq!(parts.take("3|2|2|out of range"), None);
        assert_eq!(parts.take("garbage"), None);
    }
}
