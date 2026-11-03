# Mango Server Banner v3.0.1

**Author:** Mango  
**Game:** Counter-Strike: Source  
**Required:** SourceMod 1.12  
**Display mode:** server-side `env_screenoverlay` entity

## Changes in 3.0.1

- Removed the `$translucent` and `$vertexalpha` material flags. The supplied banner is a JPEG and does not require alpha blending.
- Kept the server-side `env_screenoverlay` implementation; no client console commands or client cvar changes are required.
- Rebuilt the plugin and package with version 3.0.1.

## Install

Extract the release archive into the server's `cstrike` directory, preserving paths:

- `addons/sourcemod/plugins/mango_server_banner.smx`
- `addons/sourcemod/scripting/mango_server_banner.sp`
- `materials/overlays/mango_server_banner.vmt`
- `materials/overlays/mango_server_banner.vtf`
- `cfg/sourcemod/sm_mango_banner.cfg`

Keep `sv_allowdownload 1`. Restart the map or reload the plugin after installation.

## Commands

- `sm_mango_banner_status` — resource and entity status
- `sm_mango_banner_debug` — download table and entity diagnostics
- `sm_mango_banner_restart` — recreate the global overlay

## Compatibility and testing

The plugin checks whether the game server can create `env_screenoverlay`. Successful compilation and entity creation do not prove that the material renders correctly on every CS:S client. The visual result still requires testing on the target dedicated server and client.

## Author

Mango
