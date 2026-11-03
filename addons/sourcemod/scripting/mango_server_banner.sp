#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdktools_stringtables>

#define PLUGIN_VERSION "3.0.1"
#define VMT_PATH "materials/overlays/mango_server_banner.vmt"
#define VTF_PATH "materials/overlays/mango_server_banner.vtf"
#define OVERLAY_MATERIAL "overlays/mango_server_banner"
#define OVERLAY_ENTITY "env_screenoverlay"

public Plugin myinfo =
{
    name = "Mango Server Banner",
    author = "Mango",
    description = "Displays a server-wide banner through the Source env_screenoverlay entity",
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
    RegAdminCmd("sm_mango_banner_restart", Command_Restart, ADMFLAG_CONFIG, "Recreate the server-wide banner overlay");

    AutoExecConfig(true, "sm_mango_banner");
    PrintToServer("[Mango Banner] v%s loaded. Uses server entity %s; no client console commands.", PLUGIN_VERSION, OVERLAY_ENTITY);

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
        LogError("[Mango Banner] FAILED: game server does not provide entity '%s'. No client-command fallback will be used.", OVERLAY_ENTITY);
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

    LogMessage("[Mango Banner] v%s ACTIVE: server entity %s (entindex=%d, ref=%d), material=%s.",
        PLUGIN_VERSION, OVERLAY_ENTITY, entity, g_iOverlayEntity, OVERLAY_MATERIAL);
}

public Action Command_Restart(int client, int args)
{
    if (!g_bResourcesReady)
    {
        ReplyToCommand(client, "[Mango Banner] Resources are not ready.");
        return Plugin_Handled;
    }

    CreateServerOverlay();
    ReplyToCommand(client, "[Mango Banner] Server-wide overlay recreation requested. Check server log for result.");
    return Plugin_Handled;
}

public Action Command_Status(int client, int args)
{
    int entity = EntRefToEntIndex(g_iOverlayEntity);
    bool entityValid = entity != INVALID_ENT_REFERENCE && IsValidEntity(entity);

    ReplyToCommand(client, "[Mango Banner] v%s | resources=%s | entity=%s | entindex=%d",
        PLUGIN_VERSION, g_bResourcesReady ? "READY" : "NOT READY",
        entityValid ? "ACTIVE" : "NOT CREATED", entityValid ? entity : -1);
    ReplyToCommand(client, "[Mango Banner] Mode=server entity; client commands=NONE; VMT=%d; VTF=%d",
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
