# Mango Server Banner v3.0.0

**Author:** Mango  
**Game:** Counter-Strike: Source  
**Required:** SourceMod 1.12  
**Display mode:** server-side `env_screenoverlay` entity

## What changed

Version 3.0.0 removes the `ClientCommand` / `r_screenoverlay` display path entirely. The plugin creates one networked `env_screenoverlay` entity on the server, configures its first overlay material, and starts it. The entity is designed to transmit to clients, including clients who join after it has been activated.

This removes the need for players to enter commands or change client cvars. The game client still has to download and render the material; that is an unavoidable part of Source Engine rendering.

## Install

Extract the release archive into the server's `cstrike` directory, preserving paths:

- `addons/sourcemod/plugins/mango_server_banner.smx`
- `addons/sourcemod/scripting/mango_server_banner.sp`
- `materials/overlays/mango_server_banner.vmt`
- `materials/overlays/mango_server_banner.vtf`
- `cfg/sourcemod/sm_mango_banner.cfg`

Keep `sv_allowdownload 1`. Since this setup uses no FastDL, leave `sv_downloadurl` empty.

Restart the map or reload the plugin after installation.

## Commands

- `sm_mango_banner_status` — resource and entity status
- `sm_mango_banner_debug` — download table and entity diagnostics
- `sm_mango_banner_restart` — recreate the global overlay (admin)

The overlay is server-wide. It is not independently closable by one player; stopping the entity would affect everyone.

## Important compatibility check

The plugin checks whether the running game server can create `env_screenoverlay`. If the entity is unavailable in that CS:S server build, the plugin logs an explicit error and does not silently fall back to client commands.

A successful entity creation proves server-side activation, but the final visual result must still be tested on a real CS:S client and dedicated server.

## Author

Mango
