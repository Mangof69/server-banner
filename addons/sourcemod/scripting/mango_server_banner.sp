// v2.0.4 build trigger: compile against SourceMod 1.12 stable build 7260.
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdktools_stringtables>

#define PLUGIN_VERSION "2.0.5"
#define VMT_PATH "materials/overlays/mango_server_banner.vmt"
#define VTF_PATH "materials/overlays/mango_server_banner.vtf"
#define OVERLAY_MATERIAL "overlays/mango_server_banner"

public Plugin myinfo =
{
    name = "Mango Server Banner",
    author = "Mango",
    description = "Downloads and displays the server banner overlay on player join",
    version = PLUGIN_VERSION,
    url = "https://github.com/Mangof69/server-banner"
};

bool g_bResourcesReady;
int g_iDownloadables = INVALID_STRING_TABLE;

public void OnPluginStart()
{
    RegConsoleCmd("sm_banner_overlay", Command_ShowOverlay, "Show the server banner overlay");
    RegConsoleCmd("sm_banner_close", Command_HideOverlay, "Hide the server banner overlay");
    RegConsoleCmd("sm_banner_test", Command_ShowOverlay, "Test the server banner overlay");

    RegAdminCmd("sm_mango_banner_status", Command_Status, ADMFLAG_GENERIC, "Show Mango Banner resource status");
    RegAdminCmd("sm_mango_banner_debug", Command_Debug, ADMFLAG_GENERIC, "Show Mango Banner download table diagnostics");

    AutoExecConfig(true, "sm_mango_banner");

    PrintToServer("[Mango Banner] v%s loaded. Waiting for map resource registration.", PLUGIN_VERSION);

    // Supports loading the plugin after the map has already started.
    char currentMap[PLATFORM_MAX_PATH];
    GetCurrentMap(currentMap, sizeof(currentMap));
    if (currentMap[0] != 0)
    {
        CreateTimer(1.0, Timer_RegisterResources, _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public void OnMapStart()
{
    g_bResourcesReady = false;
    g_iDownloadables = INVALID_STRING_TABLE;
    PrepareResources();

    // Existing clients also need the overlay again after a map transition.
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client))
        {
            QueueOverlay(client);
        }
    }
}

public void OnConfigsExecuted()
{
    // Re-check after server.cfg and the plugin config have both executed.
    PrepareResources();
}

public void OnClientPutInServer(int client)
{
    QueueOverlay(client);
}

void QueueOverlay(int client)
{
    if (client < 1 || client > MaxClients || !IsClientConnected(client))
    {
        return;
    }

    CreateTimer(5.0, Timer_ShowOverlay, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_RegisterResources(Handle timer)
{
    PrepareResources();
    return Plugin_Stop;
}

public Action Timer_ShowOverlay(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (client == 0 || !IsClientInGame(client))
    {
        return Plugin_Stop;
    }

    if (!g_bResourcesReady)
    {
        LogError("[Mango Banner] Cannot show overlay to client %N: resources are not registered.", client);
        return Plugin_Stop;
    }

    ApplyOverlay(client, OVERLAY_MATERIAL);
    return Plugin_Stop;
}

void PrepareResources()
{
    g_bResourcesReady = false;

    bool vmtExists = FileExists(VMT_PATH);
    bool vtfExists = FileExists(VTF_PATH);

    LogMessage("[Mango Banner] Resource check: %s=%s, %s=%s",
        VMT_PATH, vmtExists ? "FOUND" : "MISSING",
        VTF_PATH, vtfExists ? "FOUND" : "MISSING");

    if (!vmtExists || !vtfExists)
    {
        LogError("[Mango Banner] Resource files are missing. Install both files under cstrike/materials/overlays/.");
        return;
    }

    g_iDownloadables = FindStringTable("downloadables");
    if (g_iDownloadables == INVALID_STRING_TABLE)
    {
        LogError("[Mango Banner] Network string table 'downloadables' was not found.");
        return;
    }

    RegisterDownload(VMT_PATH);
    RegisterDownload(VTF_PATH);

    int vmtIndex = FindStringIndex(g_iDownloadables, VMT_PATH);
    int vtfIndex = FindStringIndex(g_iDownloadables, VTF_PATH);

    if (vmtIndex == INVALID_STRING_INDEX || vtfIndex == INVALID_STRING_INDEX)
    {
        LogError("[Mango Banner] Registration verification FAILED: VMT index=%d, VTF index=%d.",
            vmtIndex, vtfIndex);
        return;
    }

    g_bResourcesReady = true;

    ConVar allowDownload = FindConVar("sv_allowdownload");
    ConVar downloadUrl = FindConVar("sv_downloadurl");

    char url[256];
    if (downloadUrl != null)
    {
        downloadUrl.GetString(url, sizeof(url));
    }
    else
    {
        strcopy(url, sizeof(url), "<cvar missing>");
    }

    int allow = (allowDownload != null) ? allowDownload.IntValue : -1;

    LogMessage("[Mango Banner] READY v%s: downloadables table contains VMT(index=%d) and VTF(index=%d); sv_allowdownload=%d; sv_downloadurl='%s'; entries=%d.",
        PLUGIN_VERSION, vmtIndex, vtfIndex, allow, url, GetStringTableNumStrings(g_iDownloadables));

    if (allow == 0)
    {
        LogError("[Mango Banner] sv_allowdownload is 0. Clients cannot download files directly from this server.");
    }

    if (url[0] != '\0')
    {
        LogError("[Mango Banner] sv_downloadurl is not empty. The HTTP FastDL must contain both banner files at matching relative paths.");
    }
}

void RegisterDownload(const char[] path)
{
    if (FindStringIndex(g_iDownloadables, path) != INVALID_STRING_INDEX)
    {
        LogMessage("[Mango Banner] Already in downloadables: %s", path);
        return;
    }

    AddFileToDownloadsTable(path);

    int index = FindStringIndex(g_iDownloadables, path);
    if (index == INVALID_STRING_INDEX)
    {
        LogError("[Mango Banner] AddFileToDownloadsTable did not register: %s", path);
    }
    else
    {
        LogMessage("[Mango Banner] Registered download: %s (index %d)", path, index);
    }
}

void ApplyOverlay(int client, const char[] material)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
    {
        return;
    }

    // r_screenoverlay is a CLIENT command. It is not registered in the
    // dedicated server command table, so GetCommandFlags/SetCommandFlags
    // on the server are invalid and must not be used as an existence check.
    // SourceMod ClientCommand requires cl_restrict_server_commands 0.
    int action = (material[0] == '\\0') ? 0 : 1;
    QueryClientConVar(client, "cl_restrict_server_commands", OnServerCommandRestrictionChecked,
        GetClientUserId(client) * 2 + action);
}

public void OnServerCommandRestrictionChecked(QueryCookie cookie, int client,
    ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any value)
{
    int userid = value / 2;
    bool show = (value % 2) == 1;
    int target = GetClientOfUserId(userid);

    if (target == 0 || !IsClientInGame(target))
    {
        return;
    }

    if (result != ConVarQuery_Okay)
    {
        LogError("[Mango Banner] Cannot query %s from %N (query result %d). Overlay command not sent.",
            cvarName, target, result);
        PrintToChat(target, "[Mango Banner] Cannot check client command permissions. See server console.");
        return;
    }

    if (StringToInt(cvarValue) != 0)
    {
        LogError("[Mango Banner] %N has %s=%s. ClientCommand is blocked; set it to 0 in the client console.",
            target, cvarName, cvarValue);
        PrintToChat(target, "[Mango Banner] Overlay blocked by %s. Set %s 0 in your game console.",
            cvarName, cvarName);
        return;
    }

    if (show)
    {
        ClientCommand(target, "r_screenoverlay \\"%s\"", OVERLAY_MATERIAL);
    }
    else
    {
        ClientCommand(target, "r_screenoverlay \\"\\""); 
    }

    LogMessage("[Mango Banner] Sent client overlay command to %N (show=%d, %s=%s).",
        target, show, cvarName, cvarValue);
}

public Action Command_ShowOverlay(int client, int args)
{
    if (client == 0)
    {
        ReplyToCommand(client, "[Mango Banner] This command must be used by a player.");
        return Plugin_Handled;
    }

    if (!g_bResourcesReady)
    {
        ReplyToCommand(client, "[Mango Banner] Resources are not ready. Ask an admin to run sm_mango_banner_status.");
        return Plugin_Handled;
    }

    ApplyOverlay(client, OVERLAY_MATERIAL);
    return Plugin_Handled;
}

public Action Command_HideOverlay(int client, int args)
{
    if (client == 0)
    {
        ReplyToCommand(client, "[Mango Banner] This command must be used by a player.");
        return Plugin_Handled;
    }

    ApplyOverlay(client, "");
    return Plugin_Handled;
}

public Action Command_Status(int client, int args)
{
    bool vmtExists = FileExists(VMT_PATH);
    bool vtfExists = FileExists(VTF_PATH);

    int table = FindStringTable("downloadables");
    int vmtIndex = (table != INVALID_STRING_TABLE) ? FindStringIndex(table, VMT_PATH) : INVALID_STRING_INDEX;
    int vtfIndex = (table != INVALID_STRING_TABLE) ? FindStringIndex(table, VTF_PATH) : INVALID_STRING_INDEX;

    ConVar allowDownload = FindConVar("sv_allowdownload");
    ConVar downloadUrl = FindConVar("sv_downloadurl");

    char url[256];
    if (downloadUrl != null)
    {
        downloadUrl.GetString(url, sizeof(url));
    }
    else
    {
        strcopy(url, sizeof(url), "<cvar missing>");
    }

    ReplyToCommand(client, "[Mango Banner] v%s | ready=%d | VMT=%s(index %d) | VTF=%s(index %d)",
        PLUGIN_VERSION, g_bResourcesReady,
        vmtExists ? "FOUND" : "MISSING", vmtIndex,
        vtfExists ? "FOUND" : "MISSING", vtfIndex);

    ReplyToCommand(client, "[Mango Banner] downloadables table=%d | entries=%d | sv_allowdownload=%d | sv_downloadurl='%s'",
        table, (table != INVALID_STRING_TABLE) ? GetStringTableNumStrings(table) : -1,
        (allowDownload != null) ? allowDownload.IntValue : -1, url);

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

    ReplyToCommand(client, "[Mango Banner] downloadables entries=%d", GetStringTableNumStrings(table));

    char entry[PLATFORM_MAX_PATH];
    int count = GetStringTableNumStrings(table);

    for (int i = 0; i < count; i++)
    {
        ReadStringTable(table, i, entry, sizeof(entry));

        if (StrContains(entry, "mango_server_banner", false) != -1)
        {
            ReplyToCommand(client, "[Mango Banner] table[%d] = %s", i, entry);
        }
    }

    return Plugin_Handled;
}
