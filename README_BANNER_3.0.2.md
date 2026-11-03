# Mango Server Banner v3.0.2

**Author:** Mango  
**Game:** Counter-Strike: Source  
**Required:** SourceMod 1.12  
**Display mode:** server-side `env_screenoverlay` entity

## Changes in 3.0.2

- Corrected the VTF texture flags. The previous generator set both `ONEBITALPHA` and `EIGHTBITALPHA` on the same RGBA texture; those flags are generated texture metadata and must not be forced together.
- The VTF build now validates its signature, version, dimensions, flags, image format, mip count, depth, and exact payload size.
- Kept the server-side `env_screenoverlay` implementation; no client console commands or client cvar changes are required.

## Install

Extract the release archive into the server's `cstrike` directory, preserving paths:

- `addons/sourcemod/plugins/mango_server_banner.smx`
- `addons/sourcemod/scripting/mango_server_banner.sp`
- `materials/overlays/mango_server_banner.vmt`
- `materials/overlays/mango_server_banner.vtf`
- `cfg/sourcemod/sm_mango_banner.cfg`

Replace both material files from the archive, not only the plugin. Keep `sv_allowdownload 1`. Restart the map or server after installation so clients download the updated texture.

## Commands

- `sm_mango_banner_status` — resource and entity status
- `sm_mango_banner_debug` — download table and entity diagnostics
- `sm_mango_banner_restart` — recreate the global overlay

## Compatibility and testing

The CI build validates the VTF header and payload and compiles the SourcePawn plugin. This does not replace an in-game test on the target CS:S server/client. The visual result remains unconfirmed until tested in-game.

## Author

Mango
