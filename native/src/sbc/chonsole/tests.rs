#[cfg(test)]
mod tests {
    use crate::sbc::chonsole::core::{ChonsoleCore, ChonsoleEffect, ConsoleCommand};

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
    fn matching_slash_commands_are_alphabetical() {
        let mut core = core();
        core.replace_catalog(vec![
            ConsoleCommand {
                name: "zulu".into(),
                description: String::new(),
                requires_cheat: false,
            },
            ConsoleCommand {
                name: "alpha".into(),
                description: String::new(),
                requires_cheat: false,
            },
        ]);

        let commands = core
            .suggestions("/")
            .into_iter()
            .map(|suggestion| suggestion.command)
            .collect::<Vec<_>>();
        assert!(commands.windows(2).all(|pair| pair[0] <= pair[1]));
    }

    #[test]
    fn history_keeps_the_most_recent_hundred_entries() {
        let mut core = core();
        for index in 0..101 {
            core.execute(&format!("/echo {index}"));
        }

        assert_eq!(core.history().len(), 100);
        assert_eq!(core.history().first(), Some(&"/echo 1".to_string()));
        assert_eq!(core.history().last(), Some(&"/echo 100".to_string()));
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

    #[test]
    fn live_catalog_replaces_enumerated_engine_commands() {
        let mut core = core();
        core.replace_catalog(vec![ConsoleCommand {
            name: "texture".into(),
            description: "Displays engine textures".into(),
            requires_cheat: false,
        }]);
        assert!(core
            .suggestions("/tex")
            .iter()
            .any(|item| item.command == "/texture"));
    }

    #[test]
    fn engine_texture_and_rule_suggestions_are_runtime_data() {
        let mut core = core();
        core.set_textures(vec!["$ssmf_specular".into(), "$heightmap".into()]);
        core.set_game_rules(vec![("windStrength".into(), "10".into())]);

        let textures = core.suggestions("/texture $ssmf");
        assert_eq!(textures[0].command, "/texture $ssmf_specular");
        assert_eq!(textures[0].description, "Engine texture");

        let rules = core.suggestions("/gamerules wind");
        assert_eq!(rules[0].command, "/gamerules windStrength");
        assert_eq!(rules[0].description, "10");
    }

    #[test]
    fn team_and_selected_unit_rule_suggestions_use_live_values() {
        let mut core = core();
        core.set_teams(vec![3]);
        core.set_team_rules(std::collections::BTreeMap::from([(
            3,
            vec![("income".into(), "12".into())],
        )]));
        core.set_unit_rules(vec![("health".into(), "?".into())]);

        assert_eq!(
            core.suggestions("/teamrules 3")[0].command,
            "/teamrules 3 income"
        );
        assert_eq!(core.suggestions("/unitrules hea")[0].description, "?");
    }

    #[test]
    fn original_extension_completion_sources_are_native_runtime_catalogs() {
        let mut core = core();
        core.set_unit_defs(vec![("armcom".into(), ". Commander".into())]);
        core.set_config_params(vec![("Shadows".into(), "Shadow quality".into())]);
        core.set_players(vec!["Alice".into()]);

        assert_eq!(core.suggestions("/give arm")[0].command, "/give armcom");
        assert_eq!(
            core.suggestions("/set Sha")[0].description,
            "Shadow quality"
        );
        assert_eq!(core.suggestions("/w Al")[0].command, "/w Alice");
    }
}
