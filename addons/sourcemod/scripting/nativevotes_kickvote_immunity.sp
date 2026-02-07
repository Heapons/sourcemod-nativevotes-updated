/**
 * vim: set ts=4 :
 * =============================================================================
 * NativeVotes Kick Vote Immunity
 * Causes TF2 kick votes to fail against people who the current user can't target.
 * 
 * Inspired by psychonic's [TF2] Basic Votekick Immunity
 *
 * NativeVotes Kick Vote Immunity (C)2014 Powerlord (Ross Bemrose).
 * All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */
#include <sourcemod>
#include <sdktools>

#include <nativevotes>

#pragma semicolon 1
#pragma newdecls required

enum
{
	sv_allow_votes,
	sv_vote_issue_kick_allowed,
	sv_vote_issue_kick_allowed_mvm,

	MAX_CONVARS
}

ConVar g_ConVars[MAX_CONVARS];

bool g_bRegistered = false;

bool g_bMapActive = false;

public Plugin myinfo = {
	name			= "NativeVotes | Kick Vote Immunity",
	author			= "Powerlord",
	description		= "Causes TF2 kick votes to fail against people who the current user can't target.",
	version			= "26w06f",
	url 			= "https://github.com/Heapons/sourcemod-nativevotes-updated/"
};

public void OnPluginStart()
{
	g_ConVars[sv_allow_votes]                 = FindConVar("sv_allow_votes");
	g_ConVars[sv_vote_issue_kick_allowed]     = FindConVar("sv_vote_issue_kick_allowed");
	g_ConVars[sv_vote_issue_kick_allowed_mvm] = FindConVar("sv_vote_issue_kick_allowed_mvm");

	for (int i = 0; i < MAX_CONVARS; i++)
	{
		if (g_ConVars[i] != null)
		{
			g_ConVars[i].AddChangeHook(ConVar_CheckEnable);
		}
	}
	
	LoadTranslations("common.phrases");
}

public void OnAllPluginsLoaded()
{
	if (GetFeatureStatus(FeatureType_Native, "NativeVotes_AreVoteCommandsSupported") != FeatureStatus_Available)
	{
		SetFailState("Requires NativeVotes 1.1 or newer");
	}
}

public void OnConfigsExecuted()
{
	g_bMapActive = true;
	CheckStatus();
}

public void OnMapEnd()
{
	g_bMapActive = false;
}

public void OnPluginEnd()
{
	UnregisterVoteCommand();
}

void RegisterVoteCommand()
{
	if (!g_bRegistered && NativeVotes_AreVoteCommandsSupported())
	{
		NativeVotes_RegisterVoteCommand(NativeVotesOverride_Kick, KickVoteHandler);
		g_bRegistered = true;
	}
}

void UnregisterVoteCommand()
{
	if (g_bRegistered)
	{
		NativeVotes_UnregisterVoteCommand(NativeVotesOverride_Kick, KickVoteHandler);
		g_bRegistered = false;
	}
}

public void ConVar_CheckEnable(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!g_bMapActive)
		return;
		
	CheckStatus();
}

void CheckStatus()
{
	bool bIsMvM = IsMvM();
	if (g_bRegistered)
	{
		if (!g_ConVars[sv_allow_votes].BoolValue || 
			(bIsMvM && !g_ConVars[sv_vote_issue_kick_allowed_mvm].BoolValue) ||
			(!bIsMvM && !g_ConVars[sv_vote_issue_kick_allowed].BoolValue)
		)
		{
			LogMessage("Disabling.");
			UnregisterVoteCommand();
		}
	}
	else
	{
		if (g_ConVars[sv_allow_votes].BoolValue &&
			((bIsMvM && g_ConVars[sv_vote_issue_kick_allowed_mvm].BoolValue) ||
			(!bIsMvM && g_ConVars[sv_vote_issue_kick_allowed].BoolValue))
		)
		{
			LogMessage("Enabling.");
			RegisterVoteCommand();
		}
	}
}

stock bool IsMvM()
{
	return view_as<bool>(GameRules_GetProp("m_bPlayingMannVsMachine"));
}

public Action KickVoteHandler(int client, NativeVotesOverride overrideType, const char[] voteArgument, NativeVotesKickType kickType, int target)
{
	if (!CanUserTarget(client, target))
	{
		NativeVotes_DisplayCallVoteFail(client, NativeVotesCallFail_CantKickAdmin);
		CPrintToChat(client, "%t", "Unable to target");
		return Plugin_Stop;
	}
		
	return Plugin_Continue;
}