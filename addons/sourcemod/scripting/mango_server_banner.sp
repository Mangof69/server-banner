#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdktools_stringtables>

#define PLUGIN_VERSION "3.1.0"
#define VMT_PATH "materials/overlays/mango_server_banner.vmt"
#define VTF_PATH "materials/overlays/mango_server_banner.vtf"
#define OVERLAY_MATERIAL "overlays/mango_server_banner"
#define OVERLAY_ENTITY "env_screenoverlay"
#define LINKS_CONFIG "configs/mango_server_banner_links.cfg"
#define MAX_BANNER_LINKS 32
#define MAX_LINK_URL 192

public Plugin myinfo =
{
    name = "Mango Server Banner",
    author = "Mango",
    description = "Automatic screen banner with an in-game browser link menu",
    version = PLUGIN_VERSION,
    url = "https://github.com/Mangof69/server-banner"
};

int g_iOverlayEntity = INVALID_ENT_REFERENCE;
int g_iDownloadables = INVALID_STRING_TABLE;
bool g_bResourcesReady;

public void OnPluginStart()
{
    RegAdminCmd("sm_mango_banner_status", Command_Status, ADMFLAG_GENERIC, "Show Mango Banner status");
    RegAdminCmd("sm_mango_banner_debug", Command_Debug, ADMFLAG_GENERIC, "Show Mango Banner resource diagnostics");
    RegAdminCmd("sm_mango_banner_restart", Command_Restart, ADMFLAG_CONFIG, "Recreate the server-wide banner");

    // SourceMod automatically exposes registered sm_* console commands as !chat triggers.
    RegConsoleCmd("sm_links", Command_Links, "Open the server links menu");
    RegConsoleCmd("sm_banner", Command_Links, "Open the server links menu");
    RegConsoleCmd("sm_mango_banner_links", Command_Links, "Open the server links menu");

    AutoExecConfig(true, "sm_mango_banner");
    PrintToServer("[Mango Banner] v%s loaded. Automatic env_screenoverlay banner; browser links: !links / !banner.", PLUGIN_VERSION);

    char map[PLATFORM_MAX_PATH];
    GetCurrentMap(map, sizeof(map));
    if (map[0] != 0)
    {
        CreateTimer(1.0, Timer_Initialize, _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public void OnMapStart()
{
    g_bResourcesReady = false;
    g_iOverlayEntity = INVALID_ENT_REFERENCE;
    g_iDownloadables = INVALID_STRING_TABLE;
    CreateTimer(1.0, Timer_Initialize, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnPluginEnd()
{
    int entity = EntRefToEntIndex(g_iOverlayEntity);
    if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
    {
        AcceptEntityInput(entity, "StopOverlays");
        RemoveEntity(entity);
    }
}

public Action Timer_Initialize(Handle timer)
{
    PrepareResources();
    if (g_bResourcesReady)
    {
        CreateServerOverlay();
    }
    return Plugin_Stop;
}

void PrepareResources()
{
    g_bResourcesReady = false;

    bool vmtExists = FileExists(VMT_PATH);
    bool vtfExists = FileExists(VTF_PATH);
    LogMessage("[Mango Banner] Resource check: VMT=%s, VTF=%s",
        vmtExists ? "FOUND" : "MISSING", vtfExists ? "FOUND" : "MISSING");

    if (!vmtExists || !vtfExists)
    {
        LogError("[Mango Banner] Missing banner resources. Expected cstrike/%s and cstrike/%s.", VMT_PATH, VTF_PATH);
        return;
    }

    g_iDownloadables = FindStringTable("downloadables");
    if (g_iDownloadables == INVALID_STRING_TABLE)
    {
        LogError("[Mango Banner] Network string table 'downloadables' not found.");
        return;
    }

    RegisterDownload(VMT_PATH);
    RegisterDownload(VTF_PATH);

    int vmtIndex = FindStringIndex(g_iDownloadables, VMT_PATH);
    int vtfIndex = FindStringIndex(g_iDownloadables, VTF_PATH);
    if (vmtIndex == INVALID_STRING_INDEX || vtfIndex == INVALID_STRING_INDEX)
    {
        LogError("[Mango Banner] Download registration failed: VMT=%d VTF=%d.", vmtIndex, vtfIndex);
        return;
    }

    g_bResourcesReady = true;
    LogMessage("[Mango Banner] Resources READY: VMT index=%d, VTF index=%d, downloadables=%d.",
        vmtIndex, vtfIndex, GetStringTableNumStrings(g_iDownloadables));
}

void RegisterDownload(const char[] path)
{
    if (FindStringIndex(g_iDownloadables, path) == INVALID_STRING_INDEX)
    {
        AddFileToDownloadsTable(path);
    }
}

void CreateServerOverlay()
{
    int existing = EntRefToEntIndex(g_iOverlayEntity);
    if (existing != INVALID_ENT_REFERENCE && IsValidEntity(existing))
    {
        AcceptEntityInput(existing, "StopOverlays");
        RemoveEntity(existing);
    }

    int entity = CreateEntityByName(OVERLAY_ENTITY);
    if (entity == -1 || !IsValidEntity(entity))
    {
        g_iOverlayEntity = INVALID_ENT_REFERENCE;
        LogError("[Mango Banner] FAILED: game server does not provide entity '%s'.", OVERLAY_ENTITY);
        return;
    }

    DispatchKeyValue(entity, "OverlayName1", OVERLAY_MATERIAL);
    DispatchKeyValue(entity, "OverlayTime1", "-1");

    if (!DispatchSpawn(entity))
    {
        RemoveEntity(entity);
        g_iOverlayEntity = INVALID_ENT_REFERENCE;
        LogError("[Mango Banner] FAILED: DispatchSpawn rejected %s.", OVERLAY_ENTITY);
        return;
    }

    g_iOverlayEntity = EntIndexToEntRef(entity);
    AcceptEntityInput(entity, "StartOverlays");

    LogMessage("[Mango Banner] v%s ACTIVE: %s (entindex=%d, ref=%d), material=%s.",
        PLUGIN_VERSION, OVERLAY_ENTITY, entity, g_iOverlayEntity, OVERLAY_MATERIAL);
}

bool IsAllowedWebURL(const char[] url)
{
    int length = strlen(url);
    if (length == 0 || length >= MAX_LINK_URL)
    {
        return false;
    }

    return (StrContains(url, "https://", false) == 0 || StrContains(url, "http://", false) == 0);
}

void ShowLinksMenu(int client)
{
    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, sizeof(configPath), LINKS_CONFIG);

    KeyValues kv = new KeyValues("Links");
    if (!kv.ImportFromFile(configPath))
    {
        delete kv;
        PrintToChat(client, "[Mango] Link configuration is missing: addons/sourcemod/%s", LINKS_CONFIG);
        return;
    }

    Menu menu = new Menu(MenuHandler_Links);
    menu.SetTitle("Mango Server — links");
    menu.ExitButton = true;

    int added = 0;
    if (kv.GotoFirstSubKey())
    {
        do
        {
            char title[64];
            char url[MAX_LINK_URL];

            kv.GetString("title", title, sizeof(title));
            kv.GetString("url", url, sizeof(url));

            if (!IsAllowedWebURL(url))
            {
                LogError("[Mango Banner] Skipping invalid link entry in %s (URL must start with http:// or https:// and be shorter than 192 bytes).", LINKS_CONFIG);
                continue;
            }

            if (title[0] == 0)
            {
                strcopy(title, sizeof(title), "Open link");
            }

            menu.AddItem(url, title);
            added++;
            if (added >= MAX_BANNER_LINKS)
            {
                break;
            }
        }
        while (kv.GotoNextKey());
    }

    delete kv;

    if (added == 0)
    {
        delete menu;
        PrintToChat(client, "[Mango] No valid links are configured. Edit addons/sourcemod/%s.", LINKS_CONFIG);
        return;
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Links(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char url[MAX_LINK_URL];
        menu.GetItem(param2, url, sizeof(url));

        if (param1 > 0 && IsClientInGame(param1) && IsAllowedWebURL(url))
        {
            ShowMOTDPanel(param1, "Mango Server Links", url, MOTDPANEL_TYPE_URL);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

public Action Command_Links(int client, int args)
{
    if (client <= 0 || !IsClientInGame(client) || IsFakeClient(client))
    {
        return Plugin_Handled;
    }

    ShowLinksMenu(client);
    return Plugin_Handled;
}

public Action Command_Restart(int client, int args)
{
    if (!g_bResourcesReady)
    {
        ReplyToCommand(client, "[Mango Banner] Resources are not ready.");
        return Plugin_Handled;
    }

    CreateServerOverlay();
    ReplyToCommand(client, "[Mango Banner] Overlay recreation requested. Check server log for result.");
    return Plugin_Handled;
}

public Action Command_Status(int client, int args)
{
    int entity = EntRefToEntIndex(g_iOverlayEntity);
    bool entityValid = entity != INVALID_ENT_REFERENCE && IsValidEntity(entity);

    ReplyToCommand(client, "[Mango Banner] v%s | resources=%s | entity=%s | entindex=%d",
        PLUGIN_VERSION, g_bResourcesReady ? "READY" : "NOT READY",
        entityValid ? "ACTIVE" : "NOT CREATED", entityValid ? entity : -1);
    ReplyToCommand(client, "[Mango Banner] Overlay material=%s | links: !links / !banner | links config=addons/sourcemod/%s",
        OVERLAY_MATERIAL, LINKS_CONFIG);
    ReplyToCommand(client, "[Mango Banner] VMT index=%d; VTF index=%d",
        (g_iDownloadables != INVALID_STRING_TABLE) ? FindStringIndex(g_iDownloadables, VMT_PATH) : -1,
        (g_iDownloadables != INVALID_STRING_TABLE) ? FindStringIndex(g_iDownloadables, VTF_PATH) : -1);
    return Plugin_Handled;
}

public Action Command_Debug(int client, int args)
{
    int table = FindStringTable("downloadables");
    if (table == INVALID_STRING_TABLE)
    {
        ReplyToCommand(client, "[Mango Banner] downloadables table NOT FOUND.");
        return Plugin_Handled;
    }

    char entry[PLATFORM_MAX_PATH];
    int count = GetStringTableNumStrings(table);
    ReplyToCommand(client, "[Mango Banner] downloadables entries=%d", count);

    for (int i = 0; i < count; i++)
    {
        ReadStringTable(table, i, entry, sizeof(entry));
        if (StrContains(entry, "mango_server_banner", false) != -1)
        {
            ReplyToCommand(client, "[Mango Banner] table[%d] = %s", i, entry);
        }
    }

    int entity = EntRefToEntIndex(g_iOverlayEntity);
    ReplyToCommand(client, "[Mango Banner] env_screenoverlay entity=%s (%d)",
        (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity)) ? "VALID" : "INVALID", entity);
    return Plugin_Handled;
}
