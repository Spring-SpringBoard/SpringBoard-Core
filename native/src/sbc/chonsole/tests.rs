#[cfg(test)]
mod tests {
    use crate::sbc::chonsole::core::{ChonsoleCore, ChonsoleEffect};

    fn core() -> ChonsoleCore {
        ChonsoleCore::default()
    }

    #[test]
    fn help_lists_native_commands() {
        let mut core = core();
        let (response, effects) = core.execute("/help");
        assert!(effects.is_empty());
        assert!(response
            .lines
            .iter()
            .any(|line| line.text.contains("/help")));
        assert_eq!(response.history, vec!["/help"]);
    }

    #[test]
    fn duplicate_history_entries_are_collapsed() {
        let mut core = core();
        core.execute("/help");
        core.execute("/help");
        assert_eq!(core.history(), ["/help".to_string()]);
    }

    #[test]
    fn non_slash_input_is_sent_as_chat() {
        let mut core = core();
        let (_response, effects) = core.execute("hello");
        assert_eq!(effects.len(), 1);
        assert!(matches!(effects[0], ChonsoleEffect::Chat(_, _)));
    }

    #[test]
    fn suggestions_match_builtin_prefixes() {
        let core = core();
        let suggestions = core.suggestions("/hi");
        assert_eq!(suggestions.len(), 1);
        assert_eq!(suggestions[0].command, "/history");
    }

    #[test]
    fn suggestions_match_substrings_and_fuzzy_input() {
        let core = core();
        let suggestions = core.suggestions("/cho");
        assert_eq!(suggestions[0].command, "/echo");

        let suggestions = core.suggestions("/hst");
        assert_eq!(suggestions[0].command, "/history");
    }

    #[test]
    fn slash_commands_are_forwarded_as_engine_effects() {
        let mut core = core();
        let (_, effects) = core.execute("/water 1");
        assert_eq!(effects.len(), 1);
        match &effects[0] {
            ChonsoleEffect::EngineCommand { command, args, .. } => {
                assert_eq!(command, "water");
                assert_eq!(args, "1");
            }
            _ => panic!("expected engine command effect"),
        }
    }
}
