//! In-engine coverage for native Chonsole catalog and rule-command parity.

use spring_native::RulesParamValue;

use crate::sbc::chonsole::ChonsoleManager;
use crate::sbc::tests::tests_api::TestCtx;

fn native_catalog_is_live(ctx: &mut TestCtx) -> Result<(), String> {
    let manager = ctx.sbc.model::<ChonsoleManager>();
    manager
        .update()
        .map_err(|err| format!("refresh chonsole catalog: {err:?}"))?;

    let commands = manager.suggestions("/");
    if commands.len() < 20 || !commands.iter().any(|item| item.command == "/give") {
        return Err(format!(
            "native command catalog is incomplete: {commands:?}"
        ));
    }
    let textures = manager.suggestions("/texture $ssmf");
    if !textures
        .iter()
        .any(|item| item.command == "/texture $ssmf_specular")
    {
        return Err(format!(
            "engine texture catalog is incomplete: {textures:?}"
        ));
    }
    Ok(())
}

crate::integration_test!("native_catalog_is_live", native_catalog_is_live);

fn gamerules_lists_and_sets_natively(ctx: &mut TestCtx) -> Result<(), String> {
    const NAME: &str = "__sbc_chonsole_integration_rule";
    ctx.sbc
        .interface()
        .rules_params()
        .set_game_rules_param(NAME, RulesParamValue::Float(1.0), 0)
        .map_err(|err| format!("seed game rule: {err:?}"))?;

    let manager = ctx.sbc.model::<ChonsoleManager>();
    manager
        .update()
        .map_err(|err| format!("refresh game-rule catalog: {err:?}"))?;
    if !manager
        .suggestions("/gamerules __sbc_chonsole")
        .iter()
        .any(|item| item.command == format!("/gamerules {NAME}"))
    {
        return Err("/gamerules did not suggest the live rule".into());
    }
    manager.execute(&format!("/gamerules {NAME} 42"));
    let (value, _, exists) = ctx
        .sbc
        .interface()
        .rules_params()
        .get_game_rules_param(NAME)
        .map_err(|err| format!("read game rule: {err:?}"))?;
    if !exists || value != RulesParamValue::Float(42.0) {
        return Err(format!(
            "/gamerules did not set the expected value: {value:?}"
        ));
    }
    Ok(())
}

crate::integration_test!(
    "gamerules_lists_and_sets_natively",
    gamerules_lists_and_sets_natively
);

fn teamrules_lists_and_sets_the_requested_team(ctx: &mut TestCtx) -> Result<(), String> {
    const NAME: &str = "__sbc_chonsole_team_rule";
    let team = ctx
        .sbc
        .interface()
        .teams()
        .get_team_list(-1)
        .map_err(|err| format!("list teams: {err:?}"))?
        .into_iter()
        .next()
        .ok_or_else(|| "test game has no teams".to_string())?;
    let rules = ctx.sbc.interface().rules_params();
    rules
        .set_team_rules_param(team, NAME, RulesParamValue::Float(1.0), 0)
        .map_err(|err| format!("seed team rule: {err:?}"))?;

    {
        let manager = ctx.sbc.model::<ChonsoleManager>();
        manager
            .update()
            .map_err(|err| format!("refresh team-rule catalog: {err:?}"))?;
        if !manager
            .suggestions(&format!("/teamrules {team} __sbc_chonsole"))
            .iter()
            .any(|item| item.command == format!("/teamrules {team} {NAME}"))
        {
            return Err("/teamrules did not use the requested team's live rules".into());
        }
        manager.execute(&format!("/teamrules {team} {NAME} 42"));
    }
    let (value, _, exists) = ctx
        .sbc
        .interface()
        .rules_params()
        .get_team_rules_param(team, NAME)
        .map_err(|err| format!("read team rule: {err:?}"))?;
    if !exists || value != RulesParamValue::Float(42.0) {
        return Err(format!(
            "/teamrules did not set the expected value: {value:?}"
        ));
    }
    Ok(())
}

crate::integration_test!(
    "teamrules_lists_and_sets_the_requested_team",
    teamrules_lists_and_sets_the_requested_team
);

fn unitrules_lists_and_sets_selected_units(ctx: &mut TestCtx) -> Result<(), String> {
    const NAME: &str = "__sbc_chonsole_unit_rule";
    let interface = ctx.sbc.interface();
    let team = interface
        .teams()
        .get_team_list(-1)
        .map_err(|err| format!("list teams: {err:?}"))?
        .into_iter()
        .next()
        .ok_or_else(|| "test game has no teams".to_string())?;
    let Some(definition) = interface
        .unit_defs()
        .get_unit_def_ids()
        .map_err(|err| format!("list unit definitions: {err:?}"))?
        .into_iter()
        .next()
    else {
        // The smoke game's deliberately blank fixture has no unit definitions.
        // The command is covered when an integration game supplies one.
        return Ok(());
    };
    let unit = interface
        .synced_ctrl()
        .unit()
        .create_unit(
            spring_native::sys::DefRef {
                name: std::ptr::null(),
                id: definition,
            },
            spring_native::sys::Float3 {
                x: 256.0,
                y: 0.0,
                z: 256.0,
            },
            0,
            team,
            false,
            false,
            -1,
            -1,
        )
        .map_err(|err| format!("create test unit: {err:?}"))?;
    interface
        .selection()
        .select_unit(unit, false)
        .map_err(|err| format!("select test unit: {err:?}"))?;
    interface
        .rules_params()
        .set_unit_rules_param(unit, NAME, RulesParamValue::Float(1.0), 0)
        .map_err(|err| format!("seed unit rule: {err:?}"))?;

    {
        let manager = ctx.sbc.model::<ChonsoleManager>();
        manager
            .update()
            .map_err(|err| format!("refresh unit-rule catalog: {err:?}"))?;
        if !manager
            .suggestions("/unitrules __sbc_chonsole")
            .iter()
            .any(|item| item.command == format!("/unitrules {NAME}"))
        {
            return Err("/unitrules did not use selected units' live rules".into());
        }
        manager.execute(&format!("/unitrules {NAME} 42"));
    }
    let (value, _, exists) = ctx
        .sbc
        .interface()
        .rules_params()
        .get_unit_rules_param(unit, NAME)
        .map_err(|err| format!("read unit rule: {err:?}"))?;
    if !exists || value != RulesParamValue::Float(42.0) {
        return Err(format!(
            "/unitrules did not set the expected value: {value:?}"
        ));
    }
    Ok(())
}

crate::integration_test!(
    "unitrules_lists_and_sets_selected_units",
    unitrules_lists_and_sets_selected_units
);
