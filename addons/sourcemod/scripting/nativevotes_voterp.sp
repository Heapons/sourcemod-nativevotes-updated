#include <sourcemod>
#include <multicolors>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <nativevotes>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "NativeVotes | Medieval Auto-RP",
	author = "Heapons",
	description = "Provides Medieval Auto-RP voting.",
	version = "26w06c",
	url = "https://github.com/Heapons/sourcemod-nativevotes-updated/"
};

enum
{
    tf_medieval,
    tf_medieval_autorp,
    vote_duration,

    MAX_CONVARS
}

ConVar g_ConVars[MAX_CONVARS];

bool g_NativeVotes;

public void OnPluginStart()
{
    g_ConVars[tf_medieval] = FindConVar("tf_medieval");
    g_ConVars[tf_medieval_autorp] = FindConVar("tf_medieval_autorp");
    if (FindSendPropInfo("CTFGameRulesProxy", "m_bPlayingMedieval") <= 0)
    {
        SetFailState("This game doesn't support Medieval Mode.");
    }

    g_ConVars[vote_duration] = CreateConVar("sm_voterp_voteduration", "20", "Specifies how long the rp vote should be available for.", _, true, 5.0);

    RegConsoleCmd("sm_voterp", Command_VoteRP, "Vote to toggle 'tf_medieval_autorp'.");
}

public void OnAllPluginsLoaded()
{
    g_NativeVotes = LibraryExists("nativevotes");
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "nativevotes", false))
    {
        g_NativeVotes = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "nativevotes", false))
    {
        g_NativeVotes = false;
    }
}

int MenuHandler_VoteRP(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_VoteEnd:
        {
            int item = param1;
            char info[8];
            menu.GetItem(item, info, sizeof(info));
            int value = StringToInt(info);
            g_ConVars[tf_medieval_autorp].SetInt(value);
            CPrintToChatAll("[{lightgreen}NativeVotes\x01] tf_medieval_autorp set to %d", value);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

Action Command_VoteRP(int client, int args)
{
    if (!client || !IsClientInGame(client))
    {
        return Plugin_Handled;
    }

    if ((g_NativeVotes && NativeVotes_IsVoteInProgress()) || (!g_NativeVotes && IsVoteInProgress()))
    {
        CPrintToChat(client, "[{lightgreen}NativeVotes\x01] A vote is already in progress.");
        return Plugin_Handled;
    }

    bool isMedieval = g_ConVars[tf_medieval].BoolValue || GameRules_GetProp("m_bPlayingMedieval") || FindEntityByClassname(-1, "tf_logic_medieval") != -1;
    if (!isMedieval)
    {
        CPrintToChat(client, "[{lightgreen}NativeVotes\x01] This vote is only available in Medieval Mode.");
        return Plugin_Handled;
    }

    bool enabled = g_ConVars[tf_medieval_autorp].BoolValue;
    char title[64];
    Format(title, sizeof(title), "Turn Medieval Auto-RP %s?", enabled ? "off" : "on");

    if (g_NativeVotes)
    {
        NativeVote vote = NativeVotes_Create(VoteHandler, NativeVotesType_Custom_YesNo, MENU_ACTIONS_ALL);
        NativeVotes_SetTitle(vote, title);
        NativeVotes_SetInitiator(vote, client);
        NativeVotes_AddItem(vote, enabled ? "0" : "1", enabled ? "Disable" : "Enable");
        NativeVotes_AddItem(vote, enabled ? "1" : "0", enabled ? "Enable" : "Disable");
        NativeVotes_DisplayToAll(vote, g_ConVars[vote_duration].IntValue);
    }
    else
    {
        Menu menu = new Menu(MenuHandler_VoteRP);
        menu.SetTitle(title);
        menu.AddItem(enabled ? "0" : "1", enabled ? "Disable" : "Enable");
        menu.AddItem(enabled ? "1" : "0", enabled ? "Enable" : "Disable");
        menu.ExitButton = false;
        menu.DisplayVoteToAll(g_ConVars[vote_duration].IntValue);
    }

    return Plugin_Handled;
}

int VoteHandler(NativeVote vote, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_VoteEnd:
        {
            int item = param1;
            char info[8];
            NativeVotes_GetItem(vote, item, info, sizeof(info));
            int value = StringToInt(info);
            g_ConVars[tf_medieval_autorp].SetInt(value);
            NativeVotes_DisplayPass(vote, "tf_medieval_autorp set to %d", value);
        }
        case MenuAction_End:
        {
            NativeVotes_Close(vote);
        }
    }
    return Plugin_Continue;
}