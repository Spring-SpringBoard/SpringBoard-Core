//! Native execution for Chonsole effects and custom commands.

use spring_native::prelude::NativeInterfaceRef;
use spring_native::RulesParamValue;

use super::core::{ChatTarget, ChonsoleEffect};

#[derive(Default)]
pub(super) struct CommandExecutor {
    texture_export: Option<TextureExport>,
}

struct TextureExport {
    source: String,
    output: String,
    grayscale16: bool,
}

impl CommandExecutor {
    pub(super) fn apply(&mut self, interface: &NativeInterfaceRef, effect: ChonsoleEffect) {
        match effect {
            ChonsoleEffect::Echo(text) => {
                let _ = interface.messages().echo(&text, "");
            }
            ChonsoleEffect::Chat(target, text) => send_chat(interface, target, &text),
            ChonsoleEffect::EngineCommand {
                command,
                args,
                requires_cheat,
                auto_cheat,
            } => self.send_engine_command(interface, &command, &args, requires_cheat, auto_cheat),
        }
    }

    pub(super) fn export_pending_texture(&mut self, interface: &NativeInterfaceRef) {
        let Some(export) = self.texture_export.take() else {
            return;
        };
        let gfx = interface.gfx();
        let Ok((width, height, _, _, _, _)) = gfx.texture_info(&export.source) else {
            let _ = interface
                .messages()
                .echo(&format!("unknown texture: {}", export.source), "");
            return;
        };
        let params = spring_native::sys::GfxTextureParams {
            target: 0x0DE1,
            format: if export.grayscale16 { 0x8818 } else { 0x8058 },
            border: 0,
            minFilter: 0x2601,
            magFilter: 0x2601,
            wrapS: 0x812F,
            wrapT: 0x812F,
            wrapR: 0x812F,
            compareFunc: 0,
            lodBias: 0.0,
            aniso: 0.0,
            samples: 0,
            fbo: true,
            fboDepth: false,
        };
        let Ok(Some(target)) = gfx.create_texture(width, height, 0, params) else {
            return;
        };
        let _ = gfx.bind_texture(&export.source, 0, true);
        let _ = gfx.render_to_texture(&target, || {
            let _ = gfx.tex_rect(-1.0, -1.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0);
            let _ = gfx.save_image(
                0,
                0,
                width,
                height,
                &export.output,
                true,
                true,
                export.grayscale16,
                0x8CE0,
            );
        });
        let _ = gfx.bind_texture("", 0, false);
        let _ = gfx.delete_texture(&target);
        let _ = interface.messages().echo(
            &format!("exported {} to {}", export.source, export.output),
            "",
        );
    }

    fn send_engine_command(
        &mut self,
        interface: &NativeInterfaceRef,
        command: &str,
        args: &str,
        requires_cheat: bool,
        auto_cheat: bool,
    ) {
        if command == "texture" {
            let parts = args.split_whitespace().collect::<Vec<_>>();
            if let [texture, file, rest @ ..] = parts.as_slice() {
                self.texture_export = Some(TextureExport {
                    source: (*texture).into(),
                    output: (*file).into(),
                    grayscale16: rest.contains(&"16bit"),
                });
            } else {
                let _ = interface
                    .messages()
                    .echo("usage: /texture <texture> <output-file> [16bit]", "");
            }
            return;
        }
        if matches!(command, "gamerules" | "teamrules" | "unitrules")
            && requires_cheat
            && !interface.game().is_cheating_enabled().unwrap_or(false)
            && !auto_cheat
        {
            let _ = interface
                .messages()
                .echo("Enable cheats with /cheat or /autocheat", "");
            return;
        }
        if send_custom_rule_command(interface, command, args) {
            return;
        }
        let messages = interface.messages();
        // `SendCommands`' second argument is an additional command *line*, not
        // this command's argument -- the engine joins the two with a newline.
        // "/water 4" must go out as the single line "water 4"; split, it cycles
        // the water renderer and then runs a junk "4" command.
        let line = if args.is_empty() {
            command.to_string()
        } else {
            format!("{command} {args}")
        };
        if requires_cheat && !interface.game().is_cheating_enabled().unwrap_or(false) {
            if auto_cheat {
                let _ = messages.send_commands("cheat 1", "");
                let _ = messages.send_commands(&line, "");
                let _ = messages.send_commands("cheat 0", "");
            } else {
                let _ = messages.echo("Enable cheats with /cheat or /autocheat", "");
                let _ = messages.send_commands(&line, "");
            }
            return;
        }
        let _ = messages.send_commands(&line, "");
    }
}

fn send_chat(interface: &NativeInterfaceRef, target: ChatTarget, text: &str) {
    if text.trim().is_empty() {
        return;
    }
    let command = match target {
        // The original default context is team chat for a player. `/s` remains
        // the explicit spectator route when the console is opened normally.
        ChatTarget::Default | ChatTarget::Ally => format!("say a:{text}"),
        ChatTarget::Public => format!("say {text}"),
        ChatTarget::Spectator => format!("say s:{text}"),
    };
    if let Err(error) = interface.messages().send_commands(&command, "") {
        log::error!("native chonsole chat failed: {error:?}");
    }
}

fn send_custom_rule_command(interface: &NativeInterfaceRef, command: &str, args: &str) -> bool {
    let parts = args.split_whitespace().collect::<Vec<_>>();
    let value = |raw: &str| match raw {
        "true" => RulesParamValue::Bool(true),
        "false" => RulesParamValue::Bool(false),
        _ => raw
            .parse::<f32>()
            .map(RulesParamValue::Float)
            .unwrap_or_else(|_| RulesParamValue::String(raw.to_string())),
    };
    let rules = interface.rules_params();
    match (command, parts.as_slice()) {
        ("gamerules", []) | ("gamerules", [_]) => {
            let filter = parts.first().copied().unwrap_or("");
            if let Ok(names) = rules.get_game_rules_params() {
                for name in names.into_iter().filter(|name| name.starts_with(filter)) {
                    if let Ok((value, _, true)) = rules.get_game_rules_param(&name) {
                        let _ = interface
                            .messages()
                            .echo(&format!("{name} = {}", rule_value_text(&value)), "");
                    }
                }
            }
            true
        }
        ("gamerules", [name, raw, ..]) => {
            if let Err(error) = rules.set_game_rules_param(name, value(raw), 0) {
                log::error!("/gamerules failed: {error:?}");
            }
            true
        }
        ("teamrules", [team, name, raw, ..]) => {
            match team.parse::<i32>() {
                Ok(team) => {
                    if let Err(error) = rules.set_team_rules_param(team, name, value(raw), 0) {
                        log::error!("/teamrules failed: {error:?}");
                    }
                }
                Err(_) => {
                    let _ = interface
                        .messages()
                        .echo("usage: /teamrules <team> <name> <value>", "");
                }
            }
            true
        }
        ("unitrules", [name, raw, ..]) => {
            match interface.selection().get_selected_units() {
                Ok(units) => {
                    for unit in units {
                        if let Err(error) = rules.set_unit_rules_param(unit, name, value(raw), 0) {
                            log::error!("/unitrules failed for {unit}: {error:?}");
                        }
                    }
                }
                Err(error) => log::error!("/unitrules selection failed: {error:?}"),
            }
            true
        }
        ("teamrules" | "unitrules", _) => {
            let _ = interface
                .messages()
                .echo(&format!("usage: /{command} ... <name> <value>"), "");
            true
        }
        _ => false,
    }
}

fn rule_value_text(value: &RulesParamValue) -> String {
    match value {
        RulesParamValue::Bool(value) => value.to_string(),
        RulesParamValue::Float(value) => value.to_string(),
        RulesParamValue::String(value) => value.clone(),
    }
}
