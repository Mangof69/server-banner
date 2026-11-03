# Mango Server Banner v3.2.0

**Author:** Mango  
**Game:** Counter-Strike: Source  
**Required:** SourceMod 1.12  
**Graphic display:** automatic server-side `env_screenoverlay`  
**Browser links:** Source VGUI/MOTD menu

## What changed

- Replaced the square 1024x1024 canvas. The new VTF is 1024x512 (2:1), with artwork pre-corrected for the common 16:9 CSS viewport. This reduces the severe horizontal stretch from the previous square texture.
- The original picture keeps its visual proportions on a 16:9 screen. Ultra-wide and 4:3 clients can still see some aspect-ratio variation because `env_screenoverlay` maps one material over the whole viewport.
- The canvas is transparent outside the banner. The VTF is RGBA8888, has one frame, one mip level and an 80-byte VTF 7.2 header.
- The VMT uses the minimal Source overlay material definition: `UnlitGeneric`, the exact basetexture path and `$translucent 1`.
- VTF pixel values are kept in their source sRGB color space; the VTF sets the Source sRGB flag. The image is not gamma-baked or brightened a second time. There is no separate "gamma" value to enter in the VMT.
- Added the in-game browser links menu. Players type `!links` or `!banner`, select an item, and the Source MOTD browser opens that URL.

## Install

1. Stop the server.
2. Remove the previous plugin and old copies of these files from the server:
   - `addons/sourcemod/plugins/mango_server_banner.smx`
   - `materials/overlays/mango_server_banner.vmt`
   - `materials/overlays/mango_server_banner.vtf`
3. Extract the archive into the server's `cstrike` directory, preserving folders.
4. Confirm `sv_allowdownload 1` is enabled. If using FastDL, upload both material files there with the same relative paths.
5. Restart the server or change map. Clients should reconnect to download the new materials.

The archive contains the plugin, SourcePawn source, links config, VMT, VTF and server config.

## Browser links

Edit `addons/sourcemod/configs/mango_server_banner_links.cfg`:

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

Players can open the menu with `!links` or `!banner`. Selecting an entry opens the URL in the game's MOTD/browser panel. A URL must begin with `https://` or `http://` and be shorter than 192 bytes (SourceMod API limit). The browser panel is opened only after the player chooses a link; it does not interrupt play automatically.

The server cannot override a player's client-side choice to disable HTML MOTDs. Players with HTML MOTDs disabled will need to enable them in their game settings to use the embedded browser.

## Admin diagnostics

- `sm_mango_banner_status`
- `sm_mango_banner_debug`
- `sm_mango_banner_restart`

Expected status after the resource check: `resources=READY`, `entity=ACTIVE`. Debug lists both entries in the `downloadables` string table.

## Technical notes

- `env_screenoverlay` is a full-screen material effect, not a positioned HUD panel. Artwork placement is built into the transparent canvas.
- `OverlayTime1 = -1` means the overlay remains active indefinitely.
- Texture flags are `0x234C`: CLAMPS, CLAMPT, SRGB, NOMIP, NOLOD and EIGHTBITALPHA. `0x2000` means EIGHTBITALPHA; it is not ONEBITALPHA.
- The build workflow compiles the plugin with SourceMod 1.12 and validates the VTF header and payload. A successful build does not prove runtime behavior on every CS:S branch/client; the final check must be made in-game.

## Author

Mango
