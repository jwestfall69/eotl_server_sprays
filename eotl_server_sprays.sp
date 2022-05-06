#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools_trace>
#include <tf2_stocks>
#include <clientprefs>

#define PLUGIN_AUTHOR           "ack"
#define PLUGIN_VERSION          "0.6"

#define CONFIG_FILE             "configs/eotl_server_sprays.cfg"
#define MAX_MAP_SPRAYS          32
#define MAX_SPRAY_NAME_LENGTH   32
#define MAX_RANDOM_SPRAYS       16

// idea for server side sprays comes from https://github.com/Franc1sco/Franug-Sprays
public Plugin myinfo = {
	name = "eotl_server_spray",
	author = PLUGIN_AUTHOR,
	description = "Server Side Sprays",
	version = PLUGIN_VERSION,
	url = ""
};

enum struct mapSpray {
    int index;
    float location[3];
}

enum struct PlayerState {
    bool sentSprays;
    bool enabled;
}

StringMap g_smSprayIndexes;
ArrayList g_alSprayNames;
mapSpray g_mapSprays[MAX_MAP_SPRAYS];
PlayerState g_PlayerStates[MAXPLAYERS + 1];
int g_numMapSprays;
Handle g_hClientCookies;
ConVar g_cvSSCommandLimited;
ConVar g_cvDebug;

public void OnPluginStart() {
    LogMessage("version %s starting", PLUGIN_VERSION);
    RegConsoleCmd("sm_ss", CommandSS);

    g_cvSSCommandLimited = CreateConVar("eotl_ss_command_limited", "1", "limited !ss to only allow enable/disable of server sprays");
    g_cvDebug = CreateConVar("eotl_server_sprays_debug", "0", "0/1 enable debug output", FCVAR_NONE, true, 0.0, true, 1.0);


    g_alSprayNames = CreateArray(MAX_SPRAY_NAME_LENGTH);
    g_hClientCookies = RegClientCookie("ss enabled", "ss enabled", CookieAccess_Private);
    HookEvent("player_team", EventPlayerTeam);
}

public void OnMapStart() {
    g_smSprayIndexes = CreateTrie();
    g_alSprayNames.Clear();
    LoadConfig();
}

public void OnMapEnd() {
    CloseHandle(g_smSprayIndexes);
}

public void OnClientCookiesCached(int client) {
    LoadClientConfig(client);
}

public void OnClientConnected(int client) {
    g_PlayerStates[client].sentSprays = false;
}

public Action EventPlayerTeam(Handle event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if(g_PlayerStates[client].enabled && !g_PlayerStates[client].sentSprays) {
        SendStaticSprays(client);
    }
    return Plugin_Continue;
}

public Action CommandSS(int client, int args) {
    char sprayName[MAX_SPRAY_NAME_LENGTH];
    int index;

    if(args > 1) {
        PrintToChat(client, "\x01[\x03ss\x01] Invalid syntax");
        return Plugin_Handled;
    }

    if(args == 0) {
        if(!g_PlayerStates[client].enabled) {
            g_PlayerStates[client].enabled = true;
            SaveClientConfig(client);
            PrintToChat(client, "\x01[\x03ss\x01] server sprays are now \x03enabled\x01 for you");
            SendStaticSprays(client);
        } else if(!g_cvSSCommandLimited.BoolValue) {
            SendSprayList(client);
        }
        return Plugin_Handled;
    }

    GetCmdArg(1, sprayName, sizeof(sprayName));
    StringToLower(sprayName);

    if(StrEqual(sprayName, "disable")) {
        g_PlayerStates[client].enabled = false;
        SaveClientConfig(client);
        PrintToChat(client, "\x01[\x03ss\x01] server sprays are now \x03disabled\x01 for you and will take effect next map");
        return Plugin_Handled;
    }

    if(g_cvSSCommandLimited.BoolValue) {
        PrintToChat(client, "\x01[\x03ss\x01] !ss to enable, !ss disable to disable server side sprays");
        LogMessage("%N tried to run \"!ss %s\" but the command is in limited mode", client, sprayName);
        return Plugin_Handled;
    }

    if(StrEqual(sprayName, "list")) {
        SendSprayList(client);
        return Plugin_Handled;
    }

    if(!g_smSprayIndexes.GetValue(sprayName, index)) {
        PrintToChat(client, "\x01[\x03ss\x01] error invalid spray \"%s\", use \"!ss list\" for a list", sprayName);
        return Plugin_Handled;
    }

    float location[3];
    CalcSprayLocation(client, location);
    SendSpray(0, index, location);
    PrintToChat(client, "Sprayed %s at location %f %f %f", sprayName, location[0], location[1], location[2]);

    return Plugin_Handled;
}

void SendStaticSprays(int client) {
    LogDebug("Sending static sprays to %N", client);
    for(int spray = 0; spray < g_numMapSprays; spray++) {
        SendSpray(client, g_mapSprays[spray].index, g_mapSprays[spray].location);
    }
    g_PlayerStates[client].sentSprays = true;
}

void SendSpray(int client, int index, float location[3]) {
    TE_Start("BSP Decal");
    TE_WriteVector("m_vecOrigin", location);
    TE_WriteNum("m_nEntity", 0);
    TE_WriteNum("m_nIndex", index);

    if(client == 0) {
        TE_SendToAllEnabled();
    } else {
        TE_SendToClient(client);
    }
}

void TE_SendToAllEnabled() {
	int total = 0;
	int[] clients = new int[MaxClients];

	for (int client = 1; client <= MaxClients; client++) {

        if(!IsClientInGame(client)) {
            continue;
		}

        if(!g_PlayerStates[client].enabled) {
            continue;
        }

        clients[total++] = client;
	}
	TE_Send(clients, total);
}

void SendSprayList(int client) {
    char sprayName[MAX_SPRAY_NAME_LENGTH];

    PrintToChat(client, "\x03Server Side Sprays\x01:");
    for(int i = 0; i < g_alSprayNames.Length; i++) {
        g_alSprayNames.GetString(i, sprayName, sizeof(sprayName));
        PrintToChat(client, "\x03  !ss %s\x01", sprayName);
    }
}

void CalcSprayLocation(int client, float location[3])
{
	float angles[3];
	GetClientEyeAngles(client, angles);

	float position[3];
	GetClientEyePosition(client, position);

	Handle trace = TR_TraceRayFilterEx(position, angles, MASK_SHOT, RayType_Infinite, TR_FilterNotPlayers);
	if(TR_DidHit(trace)) {
		TR_GetEndPosition(location, trace);
	}
	CloseHandle(trace);
}

public bool TR_FilterNotPlayers(int entity, int mask) {
	return entity > MaxClients;
}

void LoadConfig() {
    g_numMapSprays = 0;

    KeyValues cfg = CreateKeyValues("static sprays");

    char configFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configFile, sizeof(configFile), CONFIG_FILE);

    LogMessage("loading config file: %s", configFile);
    if(!FileToKeyValues(cfg, configFile)) {
        SetFailState("unable to load config file!");
        return;
    }

    if(cfg.JumpToKey("sprays")) {
        KvGotoFirstSubKey(cfg);
        do {
            char sprayName[MAX_SPRAY_NAME_LENGTH];
            char sprayPath[PLATFORM_MAX_PATH];
            char downloadFile[PLATFORM_MAX_PATH];
            char buffer[PLATFORM_MAX_PATH];

            cfg.GetSectionName(sprayName, sizeof(sprayName));
            cfg.GetString("spray", sprayPath, sizeof(sprayPath));
            g_alSprayNames.PushString(sprayName);

            Format(downloadFile, sizeof(downloadFile), "materials/%s.vmt", sprayPath);
            AddFileToDownloadsTable(downloadFile);

            // grab the path of the vtf from the $basetexture value in the vmt
            KeyValues vmt = CreateKeyValues("LightmappedGeneric");
            FileToKeyValues(vmt, downloadFile);
            KvGetString(vmt, "$basetexture", buffer, sizeof(buffer), "");
            CloseHandle(vmt);

            if(strlen(buffer) == 0) {
                LogMessage("Error unable to get $basetexture from %s file, skipping", downloadFile);
                continue;
            }

            Format(downloadFile, sizeof(downloadFile), "materials/%s.vtf", buffer);
            AddFileToDownloadsTable(downloadFile);

            int index = PrecacheDecal(sprayPath, true);
            g_smSprayIndexes.SetValue(sprayName, index, true);

            LogMessage("  %s as %s (%d)", sprayName, sprayPath, index);
        } while(KvGotoNextKey(cfg));
    } else {
        LogMessage("Error not sprays defined in config file: %s", configFile);
        CloseHandle(cfg);
        return;
    }

    KvRewind(cfg);
    cfg.JumpToKey("maps");

    char mapName[32];
    GetCurrentMap(mapName, sizeof(mapName));
    bool found = false;

    do {
        if(cfg.JumpToKey(mapName)) {
            LogMessage("%s found in config file", mapName);
            found = true;
        } else {
            LogMessage("%s NOT found in config file", mapName);
        }
    } while(!found && MakeShortMapName(mapName));

    if(!found) {
        LogMessage("No config for this map found in the config file");
        CloseHandle(cfg);
        return;
    }

    LogMessage("Loading static sprays for %s", mapName);
    KvGotoFirstSubKey(cfg);
    do {
        char buffer[MAX_SPRAY_NAME_LENGTH * (MAX_RANDOM_SPRAYS + 1)];
        char sprayNames[MAX_RANDOM_SPRAYS][MAX_SPRAY_NAME_LENGTH];
        char sectionName[128];
        char location[128];
        char floats[4][32];
        cfg.GetSectionName(sectionName, sizeof(sectionName));
        cfg.GetString("spray", buffer, sizeof(buffer));

        int numSprays = ExplodeString(buffer, ",", sprayNames, MAX_RANDOM_SPRAYS, MAX_SPRAY_NAME_LENGTH);
        int picked = GetRandomInt(0, numSprays - 1);

        int index;
        if(!g_smSprayIndexes.GetValue(sprayNames[picked], index)) {
            LogMessage("WARN %s has unknown spray name: \"%s\", ignoring", mapName, sprayNames[picked]);
            continue;
        }

        cfg.GetString("location", location, sizeof(location));
        if(ExplodeString(location, " ", floats, 4, 32) != 3) {
            LogMessage("WARN: %s has a bad spray location \"%s\", ignoring", mapName, location);
            continue;
        }

        g_mapSprays[g_numMapSprays].index = index;
        g_mapSprays[g_numMapSprays].location[0] = StringToFloat(floats[0]);
        g_mapSprays[g_numMapSprays].location[1] = StringToFloat(floats[1]);
        g_mapSprays[g_numMapSprays].location[2] = StringToFloat(floats[2]);

        LogMessage("  %s at location %f %f %f (%s)", sprayNames[picked], g_mapSprays[g_numMapSprays].location[0], g_mapSprays[g_numMapSprays].location[1], g_mapSprays[g_numMapSprays].location[1], sectionName);
        g_numMapSprays++;
    } while(KvGotoNextKey(cfg));
    CloseHandle(cfg);  
}

void LoadClientConfig(int client) {
    if(IsFakeClient(client)) {
        return;
    }

    char enableState[6];
    GetClientCookie(client, g_hClientCookies, enableState, 6);
    if(StrEqual(enableState, "false")) {
        g_PlayerStates[client].enabled = false;
    } else {
        g_PlayerStates[client].enabled = true;
    }

    LogDebug("client %N has server sprays %s", client, g_PlayerStates[client].enabled ? "enabled" : "disabled");
}

void SaveClientConfig(int client) {
    char enableState[6];
    if(g_PlayerStates[client].enabled) {
        Format(enableState, 6, "true");
    } else {
        Format(enableState, 6, "false");
    }

    LogDebug("client %N saving server sprays as %s", client, g_PlayerStates[client].enabled ? "enabled" : "disabled");
    SetClientCookie(client, g_hClientCookies, enableState);
}

// given a mapName truncate it at the last "_", as long
// as there are more then 1 of them.
// pl_mymap_rc123 => pl_mymap
bool MakeShortMapName(char[] mapName) {
    int us_count = 0;
    int us_last = 0;
    int len = strlen(mapName);

    for(int i = 0;i < len;i++) {
        if(mapName[i] == '_') {
            us_count++;
            us_last = i;
        }
    }

    if(us_count > 1) {
        mapName[us_last] = '\0';
        return true;
    }

    return false;
}

void StringToLower(char[] string) {
    int len = strlen(string);

    for(int i = 0;i < len;i++) {
        string[i] = CharToLower(string[i]);
    }
}

void LogDebug(char []fmt, any...) {

    if(!g_cvDebug.BoolValue) {
        return;
    }

    char message[128];
    VFormat(message, sizeof(message), fmt, 2);
    LogMessage(message);
}