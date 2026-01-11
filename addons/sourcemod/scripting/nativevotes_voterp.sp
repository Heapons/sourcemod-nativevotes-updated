/**
 * vim: set ts=4 :
 * =============================================================================
 * NativeVotes: sm_voterp - Vote to enable/disable tf_medieval_autorp
 * Only works in TF2.
 * =============================================================================
 */

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <nativevotes>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "[NativeVotes] Medieval Auto-RP",
	author = "Heapons",
	description = "Provides Medieval Auto-RP voting.",
	version = "26w02g",
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

public void OnPluginStart()
{
    g_ConVars[tf_medieval] = FindConVar("tf_medieval");
    g_ConVars[tf_medieval_autorp] = FindConVar("tf_medieval_autorp");
    if (GetEngineVersion() != Engine_TF2 || !g_ConVars[tf_medieval] || !g_ConVars[tf_medieval_autorp])
    {
        SetFailState("This plugin is for Team Fortress 2 only.");
    }

    g_ConVars[vote_duration] = CreateConVar("sm_voterp_voteduration", "20", "Specifies how long the rp vote should be available for.", _, true, 5.0);

    RegConsoleCmd("sm_voterp", Command_VoteRP, "Vote to toggle 'tf_medieval_autorp'.");
}

Action Command_VoteRP(int client, int args)
{
    if (!client || !IsClientInGame(client))
    {
        return Plugin_Handled;
    }

    if (NativeVotes_IsVoteInProgress())
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

    NativeVote vote = NativeVotes_Create(VoteHandler, NativeVotesType_Custom_YesNo, MENU_ACTIONS_ALL);
    
    NativeVotes_SetTitle(vote, title);
    NativeVotes_SetInitiator(vote, client);
    NativeVotes_AddItem(vote, enabled ? "0" : "1", enabled ? "Disable" : "Enable");
    NativeVotes_AddItem(vote, enabled ? "1" : "0", enabled ? "Enable" : "Disable");
    NativeVotes_DisplayToAll(vote, g_ConVars[vote_duration].IntValue);

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
