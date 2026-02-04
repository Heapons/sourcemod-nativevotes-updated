#include <sourcemod>
#include <multicolors>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <nativevotes>
#define REQUIRE_PLUGIN

public Plugin myinfo =
{
    name = "NativeVotes | Scramble Teams",
    author = "Heapons",
    description = "Provides Scramble Teams Voting",
    version = "26w06c",
    url = "https://github.com/Heapons/sourcemod-nativevotes-updated/"
};

enum
{
    needed,
    minplayers,
    initialdelay,
    interval,
    restart_round,
    restart_timelimit,
    enforce_timelimit,

    MAX_CONVARS
}

ConVar g_ConVars[MAX_CONVARS];

bool g_ScrambleAllowed = false;
int g_Voters = 0;
int g_Votes = 0;
int g_VotesNeeded = 0;
bool g_Voted[MAXPLAYERS+1] = {false, ...};
bool g_NativeVotes;
bool g_RegisteredScramble = false;
int g_ScrambleTime = 0;

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    LoadTranslations("rockthevote.phrases");
    LoadTranslations("votescramble.phrases");

    g_ConVars[needed]            = CreateConVar("sm_scrambleteams_needed", "0.60", "Percentage of players needed to scramble teams (Def 60%)", 0, true, 0.05, true, 1.0);
    g_ConVars[minplayers]        = CreateConVar("sm_scrambleteams_minplayers", "0", "Number of players required before scramble will be enabled.", 0, true, 0.0, true, float(MAXPLAYERS));
    g_ConVars[initialdelay]      = CreateConVar("sm_scrambleteams_initialdelay", "30.0", "Time (in seconds) before first scramble can be held", 0, true, 0.00);
    g_ConVars[interval]          = CreateConVar("sm_scrambleteams_interval", "240.0", "Time (in seconds) after a failed scramble before another can be held", 0, true, 0.00);
    g_ConVars[restart_round]     = CreateConVar("sm_scrambleteams_restart_round", "0", "Whether to restart the round after scrambling teams", 0, true, 0.0, true, 1.0);
    g_ConVars[restart_timelimit] = CreateConVar("sm_scrambleteams_restart_timelimit", "0", "Whether to restart the timelimit after scrambling teams", 0, true, 0.0, true, 1.0);
    g_ConVars[enforce_timelimit] = CreateConVar("sm_scrambleteams_enforce_timelimit", "0", "Whether to end the game as soon as the timelimit runs out.", 0, true, 0.0, true, 1.0);

    RegConsoleCmd("sm_votescramble", Command_VoteScramble);
    RegConsoleCmd("sm_scramble", Command_VoteScramble);

    RegAdminCmd("sm_forcescramble", Command_ForceScramble, ADMFLAG_CHANGEMAP);
    RegAdminCmd("sm_resetscramble", Command_ResetScramble, ADMFLAG_CHANGEMAP);

    AutoExecConfig(true, "votescramble");

    OnMapEnd();

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientConnected(i))
        {
            OnClientConnected(i);
        }
    }
}

public void OnPluginEnd()
{
    RemoveVoteHandler();
}

public void OnAllPluginsLoaded()
{
    g_NativeVotes = LibraryExists("nativevotes") &&
                    GetFeatureStatus(FeatureType_Native, "NativeVotes_AreVoteCommandsSupported") == FeatureStatus_Available &&
                    NativeVotes_AreVoteCommandsSupported();

    if (g_NativeVotes)
        RegisterVoteHandler();
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "nativevotes", false) &&
        GetFeatureStatus(FeatureType_Native, "NativeVotes_AreVoteCommandsSupported") == FeatureStatus_Available &&
        NativeVotes_AreVoteCommandsSupported())
    {
        g_NativeVotes = true;
        RegisterVoteHandler();
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "nativevotes", false))
    {
        g_NativeVotes = false;
        RemoveVoteHandler();
    }
}

public void OnMapEnd()
{
    g_ScrambleAllowed = false;
    g_Voters = 0;
    g_Votes = 0;
    g_VotesNeeded = 0;
}

public void OnConfigsExecuted()
{
    if (g_ConVars[initialdelay].FloatValue <= 0.0)
    {
        g_ScrambleAllowed = true;
        return;
    }
    CreateTimer(g_ConVars[initialdelay].FloatValue, Timer_DelayScramble, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientConnected(int client)
{
    if (!IsFakeClient(client))
    {
        g_Voters++;
        g_VotesNeeded = RoundToCeil(float(g_Voters) * g_ConVars[needed].FloatValue);
    }
}

public void OnClientDisconnect(int client)
{
    if (g_Voted[client])
    {
        g_Votes--;
        g_Voted[client] = false;
    }

    if (!IsFakeClient(client))
    {
        g_Voters--;
        g_VotesNeeded = RoundToCeil(float(g_Voters) * g_ConVars[needed].FloatValue);
    }

    if (g_Votes &&
        g_Voters &&
        g_Votes >= g_VotesNeeded &&
        g_ScrambleAllowed)
    {
        if (g_NativeVotes && NativeVotes_IsVoteInProgress())
        {
            return;
        }

        StartScramble();
    }
}

public void Event_TeamplayRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    // Ends game mid-round once mp_timelimit runs out
	if (g_ConVars[enforce_timelimit].BoolValue)
    {
        int entity = FindEntityByClassname(-1, "tf_gamerules");
	    if (entity != -1)
	    {
	    	SetVariantBool(true);
	    	AcceptEntityInput(entity, "SetStalemateOnTimelimit", 0, 0);
	    }
    }
    // Prevents map reset after scrambling teams
    if (!g_ConVars[restart_timelimit].BoolValue)
    {
        GameRules_SetPropFloat("m_flMapResetTime", 0.0);
    }
}

public Action Command_VoteScramble(int client, int args)
{
    if (!client)
        return Plugin_Handled;

    AttemptScramble(client);
    return Plugin_Handled;
}

public Action Command_ForceScramble(int client, int args)
{
    if (!g_ScrambleAllowed)
        g_ScrambleAllowed = true;

    StartScramble();
    return Plugin_Handled;
}

public Action Command_ResetScramble(int client, int args)
{
    ResetScramble();
    CPrintToChatAll("[{olive}Scramble Teams\x01] %t", "Cancelled Vote");
    return Plugin_Handled;
}

void UndoScramble(int client)
{
    char yes[64], no[64];
    Format(yes, sizeof(yes), "%T", "Yes", client);
    Format(no, sizeof(no), "%T", "No", client);

    char title[128];
    Format(title, sizeof(title), "%T", "Cancel vote", client);

    Menu menu = new Menu(MenuHandler_UndoScramble);
    menu.SetTitle(title);
    menu.AddItem("yes", yes);
    menu.AddItem("no", no);
    menu.ExitButton = false;
    menu.Display(client, MENU_TIME_FOREVER);
}

void MenuHandler_UndoScramble(Menu menu, MenuAction action, int client, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            if (param2 == 0) // Yes
            {
                if (g_Voted[client])
                {
                    char name[MAX_NAME_LENGTH];
                    GetPlayerName(client, name, sizeof(name));

                    g_Voted[client] = false;
                    if (g_Votes > 0) g_Votes--;
                    CPrintToChatAllEx(client, "[{olive}Scramble Teams\x01] %s: %t", name, "Cancelled Vote");
                }
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
}

void AttemptScramble(int client, bool isVoteMenu=false)
{
    if (!g_ScrambleAllowed)
    {
        CReplyToCommand(client, "[{olive}Scramble Teams\x01] %t", "Scramble Not Allowed");
        if (isVoteMenu && g_NativeVotes)
        {
            int timeleft = g_ScrambleTime - GetTime();
            if (timeleft > 0)
            {
                NativeVotes_DisplayCallVoteFail(client, NativeVotesCallFail_Failed, timeleft);
            }
            else
            {
                NativeVotes_DisplayCallVoteFail(client, NativeVotesCallFail_Generic);
            }
        }
        return;
    }

    if (g_NativeVotes && NativeVotes_IsVoteInProgress())
    {
        CReplyToCommand(client, "[{olive}Scramble Teams\x01] %t", "Vote in Progress");
        return;
    }

    if (GetClientCount(true) < g_ConVars[minplayers].IntValue)
    {
        CReplyToCommand(client, "[{olive}Scramble Teams\x01] %t", "Minimal Players Not Met");
        if (isVoteMenu && g_NativeVotes)
        {
            NativeVotes_DisplayCallVoteFail(client, NativeVotesCallFail_Loading);
        }
        return;
    }

    if (g_Voted[client])
    {
        UndoScramble(client);
        return;
    }

    char name[MAX_NAME_LENGTH];
    GetPlayerName(client, name, sizeof(name));

    g_Votes++;
    g_Voted[client] = true;

    CPrintToChatAllEx(client, "[{olive}Scramble Teams\x01] %t", "Scramble Requested", name, g_Votes, g_VotesNeeded);

    if (g_Votes >= g_VotesNeeded)
    {
        StartScramble();
    }
}

void StartScramble()
{
    char yes[64], no[64];
    Format(yes, sizeof(yes), "%T", "Yes", LANG_SERVER);
    Format(no, sizeof(no), "%T", "No", LANG_SERVER);
    if (g_NativeVotes)
    {
        NativeVote vote = NativeVotes_Create(ScrambleVoteHandler, NativeVotesType_ScrambleNow);
        NativeVotes_SetTitle(vote, "%t", "Scramble Teams");
        NativeVotes_AddItem(vote, "yes", yes);
        NativeVotes_AddItem(vote, "no", no);
        NativeVotes_DisplayToAll(vote, 20);
        NativeVotes_SetResultCallback(vote, ScrambleVoteResult);
    }
    else
    {
        Menu menu = new Menu(MenuHandler_Scramble);
        menu.SetTitle("%t", "Scramble Teams");
        menu.AddItem("yes", yes);
        menu.AddItem("no", no);
        menu.ExitButton = false;
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && !IsFakeClient(i))
            {
                menu.Display(i, 20);
            }
        }
    }
    ResetScramble();
    g_ScrambleAllowed = false;

    g_ScrambleTime = GetTime() + g_ConVars[interval].IntValue;
    CreateTimer(g_ConVars[interval].FloatValue, Timer_DelayScramble, _, TIMER_FLAG_NO_MAPCHANGE);
}

void ResetScramble()
{
    g_Votes = 0;
    for (int i = 1; i <= MAXPLAYERS; i++)
    {
        g_Voted[i] = false;
    }
}

void RegisterVoteHandler()
{
    if (!g_NativeVotes)
        return;

    if (!g_RegisteredScramble)
    {
        NativeVotes_RegisterVoteCommand(NativeVotesOverride_Scramble, Menu_ScrambleTeams);
        g_RegisteredScramble = true;
    }
}

void RemoveVoteHandler()
{
    if (g_RegisteredScramble)
    {
        if (g_NativeVotes)
            NativeVotes_UnregisterVoteCommand(NativeVotesOverride_Scramble, Menu_ScrambleTeams);
        g_RegisteredScramble = false;
    }
}

public Action Menu_ScrambleTeams(int client, NativeVotesOverride overrideType, const char[] voteArgument)
{
    if (client <= 0 || NativeVotes_IsVoteInProgress())
        return Plugin_Stop;

    AttemptScramble(client, true);
    return Plugin_Stop;
}

int ScrambleVoteHandler(NativeVote vote, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_VoteEnd)
    {
        // handled by result callback
    }
    else if (action == MenuAction_End)
    {
        NativeVotes_Close(vote);
    }
    return 0;
}

void ScrambleVoteResult(NativeVote vote, int num_votes, int num_clients, const int[] client_indexes, const int[] client_votes, int num_items, const int[] item_indexes, const int[] item_votes)
{
    int yesVotes = 0;
    int noVotes = 0;

    for (int i = 0; i < num_items; i++)
    {
        if (item_indexes[i] == 0)
        {
            yesVotes = item_votes[i];
        }
        else if (item_indexes[i] == 1)
        {
            noVotes = item_votes[i];
        }
    }

    if (yesVotes > noVotes)
    {
        NativeVotes_DisplayPassEx(vote, NativeVotesPass_Scramble);

        CPrintToChatAll("[{olive}Scramble Teams\x01] %t", "Scrambling Teams");
        ServerCommand("mp_scrambleteams");
        if (g_ConVars[restart_round].BoolValue)
        {
            ServerCommand("mp_restartgame 5");
        }
    }
    else if (yesVotes == 0 && noVotes == 0)
    {
        NativeVotes_DisplayFail(vote, NativeVotesFail_NotEnoughVotes);
        CPrintToChatAll("[{olive}Scramble Teams\x01] %t", "No Votes");
    }
    else
    {
        NativeVotes_DisplayFail(vote, NativeVotesFail_Loses);
    }
}

int MenuHandler_Scramble(Menu menu, MenuAction action, int client, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            if (param2 == 0)
            {
                CPrintToChatAll("[{olive}Scramble Teams\x01] %t", "Scrambling Teams");
                ServerCommand("mp_scrambleteams");
                if (g_ConVars[restart_round].BoolValue)
                {
                    ServerCommand("mp_restartgame 5");
                }
            }
            else
            {
                CPrintToChatAll("[{olive}Scramble Teams\x01] %t", "No Votes");
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

public Action Timer_DelayScramble(Handle timer)
{
    g_ScrambleAllowed = true;
    return Plugin_Continue;
}

void GetPlayerName(int client, char[] name, int maxlen)
{
    int r, g, b, a, color;
    GetEntityRenderColor(client, r, g, b, a);
    color = (r << 16) | (g << 8) | b;
    if (color != 0xFFFFFF)
    {
        Format(name, maxlen, "{#%06X}%N\x01", color, client);
    }
    else
    {
        Format(name, maxlen, "{teamcolor}%N\x01", client);
    }
}