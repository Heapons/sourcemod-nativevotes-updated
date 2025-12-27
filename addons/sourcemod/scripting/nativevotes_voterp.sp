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

#define VERSION "25w52a"

public Plugin myinfo =
{
	name = "NativeVotes Medieval Auto-RP",
	author = "Heapons",
	description = "Provides Medieval Auto-RP voting.",
	version = VERSION,
	url = "https://github.com/Heapons/sourcemod-nativevotes-updated/"
};

ConVar g_Cvar_Medieval;
ConVar g_Cvar_MedievalAutoRP;
ConVar g_Cvar_VoteDuration;

public void OnPluginStart()
{
    if (GetEngineVersion() != Engine_TF2)
    {
        SetFailState("This plugin is for Team Fortress 2 only.");
    }

    g_Cvar_Medieval = FindConVar("tf_medieval");
    g_Cvar_MedievalAutoRP = FindConVar("tf_medieval_autorp");
    if (g_Cvar_MedievalAutoRP == null)
    {
        SetFailState("Could not find tf_medieval_autorp cvar.");
    }

    g_Cvar_VoteDuration = CreateConVar("sm_voterp_voteduration", "20", "Specifies how long the rp vote should be available for.", _, true, 5.0);

    RegConsoleCmd("sm_voterp", Command_VoteRP, "Vote to enable/disable tf_medieval_autorp");
}

public Action Command_VoteRP(int client, int args)
{
    if (!client || !IsClientInGame(client))
    {
        return Plugin_Handled;
    }

    if (NativeVotes_IsVoteInProgress())
    {
        PrintToChat(client, "[{lightgreen}NativeVotes\x01] A vote is already in progress.");
        return Plugin_Handled;
    }

    bool isMedieval = g_Cvar_Medieval.BoolValue || GameRules_GetProp("m_bPlayingMedieval") || FindEntityByClassname(-1, "tf_logic_medieval") != -1;
    if (!isMedieval)
    {
        PrintToChat(client, "[{lightgreen}NativeVotes\x01] This vote is only available in Medieval Mode.");
        return Plugin_Handled;
    }

    bool enabled = g_Cvar_MedievalAutoRP.BoolValue;
    char title[64];
    Format(title, sizeof(title), "Turn Medieval Auto-RP %s?", enabled ? "off" : "on");

    NativeVote vote = NativeVotes_Create(VoteHandler, NativeVotesType_Custom_YesNo, MENU_ACTIONS_ALL);
    NativeVotes_SetTitle(vote, title);
    NativeVotes_SetInitiator(vote, client);
    NativeVotes_AddItem(vote, enabled ? "0" : "1", enabled ? "Disable" : "Enable");
    NativeVotes_AddItem(vote, enabled ? "1" : "0", enabled ? "Enable" : "Disable");
    NativeVotes_DisplayToAll(vote, g_Cvar_VoteDuration.IntValue);
    return Plugin_Handled;
}

public int VoteHandler(NativeVote vote, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_VoteEnd:
        {
            int item = param1;
            char info[8];
            NativeVotes_GetItem(vote, item, info, sizeof(info));
            int value = StringToInt(info);
            g_Cvar_MedievalAutoRP.SetInt(value);
            NativeVotes_DisplayPass(vote, "tf_medieval_autorp set to %d", value);
        }
        case MenuAction_End:
        {
            NativeVotes_Close(vote);
        }
    }
    return 0;
}
