//! Gathers the runtime library assets (LCS, s11n) a Spring-archive export must
//! bundle so the exported map loads its saved features.

use std::path::{Path, PathBuf};

use crate::sbc::command_system::context::Context;
use crate::sbc::project::jobs::archive_export::ArchiveAsset;

const LCS_ASSETS: &[&str] = &[
    "libs_sb/lcs/LCS.lua",
    "libs_sb/lcs/README.md",
    "libs_sb/lcs/docs/files/LCS.html",
    "libs_sb/lcs/docs/files/docgen.html",
    "libs_sb/lcs/docs/index.html",
    "libs_sb/lcs/docs/luadoc.css",
    "libs_sb/lcs/quickTour.lua",
    "libs_sb/lcs/tests.lua",
    "libs_sb/lcs/version_history.md",
    "libs_sb/lcs/zlib LICENSE.txt",
];

const S11N_ASSETS: &[&str] = &[
    "libs_sb/s11n/LICENSE",
    "libs_sb/s11n/README.md",
    "libs_sb/s11n/feature_s11n.lua",
    "libs_sb/s11n/luaui/widgets/s11n_widget_load.lua",
    "libs_sb/s11n/object_s11n.lua",
    "libs_sb/s11n/s11n.lua",
    "libs_sb/s11n/s11n_gadget_load.lua",
    "libs_sb/s11n/s11n_load_map_features.lua",
    "libs_sb/s11n/s11n_widget_load.lua",
    "libs_sb/s11n/unit_s11n.lua",
];

pub(crate) fn gather(ctx: &Context) -> Result<Vec<ArchiveAsset>, String> {
    let mut assets = vec![
        ArchiveAsset {
            path: PathBuf::from("LuaGaia/main.lua"),
            bytes: br#"VFS.Include("LuaGadgets/gadgets.lua",nil, VFS.BASE)"#.to_vec(),
        },
        ArchiveAsset {
            path: PathBuf::from("LuaGaia/draw.lua"),
            bytes: br#"VFS.Include("LuaGadgets/gadgets.lua",nil, VFS.BASE)"#.to_vec(),
        },
    ];

    for source in LCS_ASSETS {
        assets.push(read_asset(
            ctx,
            source,
            Path::new("libs/lcs").join(strip_prefix(source, "libs_sb/lcs/")?),
        )?);
    }
    for source in S11N_ASSETS {
        assets.push(read_asset(
            ctx,
            source,
            Path::new("libs/s11n").join(strip_prefix(source, "libs_sb/s11n/")?),
        )?);
    }

    let gadget = read_vfs(ctx, "libs_sb/s11n/s11n_gadget_load.lua")?;
    assets.push(ArchiveAsset {
        path: PathBuf::from("LuaGaia/Gadgets/s11n_gadget_load.lua"),
        bytes: gadget,
    });

    let load_features =
        String::from_utf8(read_vfs(ctx, "libs_sb/s11n/s11n_load_map_features.lua")?)
            .map_err(|err| format!("s11n_load_map_features.lua is not utf-8: {err}"))?
            .replace(
                "local modelPath = nil",
                "local modelPath = \"mapconfig/s11n_model.lua\"",
            );
    assets.push(ArchiveAsset {
        path: PathBuf::from("LuaGaia/Gadgets/s11n_load_map_features.lua"),
        bytes: load_features.into_bytes(),
    });

    Ok(assets)
}

fn read_asset(ctx: &Context, source: &str, path: PathBuf) -> Result<ArchiveAsset, String> {
    Ok(ArchiveAsset {
        path,
        bytes: read_vfs(ctx, source)?,
    })
}

fn read_vfs(ctx: &Context, source: &str) -> Result<Vec<u8>, String> {
    ctx.interface
        .vfs()
        .read_file(source)
        .map_err(|err| format!("read VFS asset {source}: {err:?}"))
}

fn strip_prefix<'a>(source: &'a str, prefix: &str) -> Result<&'a str, String> {
    source
        .strip_prefix(prefix)
        .ok_or_else(|| format!("{source} does not start with {prefix}"))
}
