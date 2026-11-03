# Mango Server Banner v2.0.4

Author: Mango  
Target: Counter-Strike: Source + SourceMod 1.12

## What changed in 2.0.4

- Fixes the CS:S overlay invocation: `r_screenoverlay` is flagged `FCVAR_CHEAT`. The plugin now temporarily clears that flag while issuing the client command, then restores the exact original flags. This follows the established SourceMod overlay implementation pattern.
- Verifies that both banner files are present in the server's `downloadables` network string table, rather than treating file existence alone as proof of client delivery.
- Logs the actual `sv_allowdownload` and `sv_downloadurl` values.
- Adds `sm_mango_banner_debug` to inspect the registered banner entries.
- Reapplies the overlay after map changes and five seconds after a player joins.

## Install

Extract the ZIP **directly into the server's `cstrike` directory**, preserving the archive paths.

Required files after extraction:

```
cstrike/addons/sourcemod/plugins/mango_server_banner.smx
cstrike/addons/sourcemod/scripting/mango_server_banner.sp
cstrike/materials/overlays/mango_server_banner.vmt
cstrike/materials/overlays/mango_server_banner.vtf
```

Restart the server or run `sm plugins reload mango_server_banner`.

For a server without FastDL access, configure:

```cfg
sv_allowdownload 1
sv_downloadurl ""
```

The server host must permit direct Source downloads. On the client, downloads must be enabled:

```cfg
cl_allowdownload 1
cl_downloadfilter all
```

If the hosting provider forcibly sets a non-empty `sv_downloadurl`, its FastDL must contain the two material files. A SourceMod plugin cannot upload files to a provider-controlled FastDL service.

## Commands

- `!banner_overlay` / `sm_banner_overlay` — show the overlay manually.
- `!banner_test` / `sm_banner_test` — same test command.
- `!banner_close` / `sm_banner_close` — clear the overlay.
- `sm_mango_banner_status` — show file presence, download-table indexes, table size, and download cvars (admin).
- `sm_mango_banner_debug` — list matching entries in the download table (admin).

## What READY means

`ready=1` means both files exist on the server and both exact relative paths are present in the `downloadables` string table. It does not prove that a specific client completed the download or that their game rendered the material. Check the player's client download folder and console if delivery still fails.

## Important limitation

This build can fix the plugin's command handling and validate resource registration. It cannot override a hosting provider that blocks direct file downloads or controls FastDL outside the game server. In that case the provider must enable direct downloads or publish these two files on its FastDL.

