# Mango Server Banner v3.1.0

**Author:** Mango  
**Game:** Counter-Strike: Source  
**Required:** SourceMod 1.12  
**Automatic display:** server-side `env_screenoverlay`  
**Clickable links:** Source VGUI/MOTD browser menu

## What changed

- The source artwork is no longer stretched into a square. The build keeps its aspect ratio and places it on a transparent 1024x1024 canvas.
- The VTF is RGBA8888 with the sRGB and 8-bit-alpha flags. The alpha channel makes everything outside the banner transparent.
- The VMT enables texture transparency and vertex alpha using the standard `UnlitGeneric` HUD-style material setup.
- Added an in-game browser menu. Players can type `!links` or `!banner`; selecting an item opens its URL in the CS:S MOTD browser. No client console commands or client cvar changes are required.

## Install

1. Stop the server.
2. Remove the previous plugin and old copies of these material files from the server:
   - `addons/sourcemod/plugins/mango_server_banner.smx`
   - `materials/overlays/mango_server_banner.vmt`
   - `materials/overlays/mango_server_banner.vtf`
3. Extract the archive into the server's `cstrike` directory, preserving folders.
4. Confirm `sv_allowdownload 1` is enabled.
5. Restart the server or change map. Clients should reconnect so Source downloads the updated materials.

The archive contains:
- `addons/sourcemod/plugins/mango_server_banner.smx`
- `addons/sourcemod/scripting/mango_server_banner.sp`
- `addons/sourcemod/configs/mango_server_banner_links.cfg`
- `materials/overlays/mango_server_banner.vmt`
- `materials/overlays/mango_server_banner.vtf`
- `cfg/sourcemod/sm_mango_banner.cfg`

## Browser links

Edit `addons/sourcemod/configs/mango_server_banner_links.cfg` on the server. Each numbered block is one link:

```text
"Links"
{
    "1"
    {
        "title" "Website"
        "url" "https://example.com"
    }
    "2"
    {
        "title" "Discord"
        "url" "https://discord.gg/your-invite"
    }
}
```

The supplied config includes the GitHub project link. Replace it or add your own destinations. Valid URLs must use `https://` or `http://` and contain fewer than 192 bytes.

Players use:
- `!links`
- `!banner`

The selected link opens in the game's MOTD/browser panel. The game/client may still block HTML MOTDs if the player has explicitly disabled them; a server plugin cannot override a client-side privacy setting.

## Admin diagnostics

- `sm_mango_banner_status`
- `sm_mango_banner_debug`
- `sm_mango_banner_restart`

## Important technical notes

- `env_screenoverlay` is a full-screen material effect, not a positioned HUD image. The transparent canvas is what lets the art occupy only the top banner area.
- `OverlayTime1 = -1` means the overlay remains active indefinitely.
- The VTF uses version 7.2, an 80-byte header, RGBA8888 pixels, no low-resolution thumbnail, one frame, one mip level, and depth 1.
- VTF texture flag `0x2000` is `EIGHTBITALPHA`; it is not `ONEBITALPHA`. The combined flags in this build are `0x234C`.
- The build workflow validates the VTF header/payload and compiles the plugin using SourceMod 1.12. That is not a substitute for testing on the target CS:S server and client.

## Author

Mango
