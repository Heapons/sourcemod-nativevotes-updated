/**
 * vim: set ts=4 :
 * =============================================================================
 * NativeVotes Fun Votes Plugin
 * Implements extra fun vote commands using NativeVotes.
 * Based on the SourceMod version.
 *
 * NativeVotes (C)2011-2014 Ross Bemrose (Powerlord).  All rights reserved.
 * SourceMod (C)2004-2008 AlliedModders LLC.  All rights reserved.
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

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <nativevotes>

#define PLUGIN_PREFIX "[\x04NativeVotes\x01]"

public Plugin myinfo =
{
	name = "NativeVotes | Fun Votes",
	author = "Powerlord and AlliedModders LLC",
	description = "NativeVotes Fun Vote Commands",
	version = "26w08a",
	url = "https://github.com/Heapons/sourcemod-nativevotes-updated/"
};

#define VOTE_NO "###no###"
#define VOTE_YES "###yes###"

// Handle g_hVoteMenu;

enum
{
	sv_gravity,
	sv_alltalk,
	mp_friendlyfire,
	sv_vote_timer_duration,

	vote_gravity,
	vote_burn,
	vote_slay,
	vote_alltalk,
	vote_ff,

	MAX_CONVARS
}

ConVar g_ConVars[MAX_CONVARS];

enum VoteType
{
	gravity,
	burn,
	slay,
	alltalk,
	ff
};

VoteType g_VoteType = gravity;

// Menu API does not provide us with a way to pass multiple peices of data with a single
// choice, so some globals are used to hold stuff.
//
#define VOTE_CLIENTID 0
#define VOTE_USERID 1
int g_VoteClient[2];        // Holds the target's client id and user id

#define VOTE_NAME 0
#define VOTE_AUTHID 1
#define VOTE_IP 2
char g_VoteInfo[3][65];    // Holds the target's name, authid, and IP

Handle g_TopMenu;

// NativeVotes
bool g_NativeVotes;

#include "nativevotes_funvotes/votegravity.sp"
#include "nativevotes_funvotes/voteburn.sp"
#include "nativevotes_funvotes/voteslay.sp"
#include "nativevotes_funvotes/votealltalk.sp"
#include "nativevotes_funvotes/voteff.sp"

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("basevotes.phrases");
	LoadTranslations("funvotes.phrases");
	LoadTranslations("funcommands.phrases");
	
	RegAdminCmd("sm_votegravity", Command_VoteGravity, ADMFLAG_VOTE, "sm_votegravity <amount> [amount2] ... [amount5]");
	RegAdminCmd("sm_voteburn", Command_VoteBurn, ADMFLAG_VOTE|ADMFLAG_SLAY, "sm_voteburn <player>");
	RegAdminCmd("sm_voteslay", Command_VoteSlay, ADMFLAG_VOTE|ADMFLAG_SLAY, "sm_voteslay <player>");
	RegAdminCmd("sm_votealltalk", Command_VoteAlltalk, ADMFLAG_VOTE, "sm_votealltalk");
	RegAdminCmd("sm_voteff", Command_VoteFF, ADMFLAG_VOTE, "sm_voteff");

	g_ConVars[sv_gravity] 	   		  = FindConVar("sv_gravity");
	g_ConVars[sv_alltalk] 	   		  = FindConVar("sv_alltalk");
	g_ConVars[mp_friendlyfire] 		  = FindConVar("mp_friendlyfire");
	g_ConVars[sv_vote_timer_duration] = FindConVar("sv_vote_timer_duration");
	g_ConVars[vote_gravity]    		  = CreateConVar("sm_vote_gravity", "0.60", "Percent required for successful gravity vote.", 0, true, 0.05, true, 1.0);
	g_ConVars[vote_burn] 	   		  = CreateConVar("sm_vote_burn", "0.60", "Percent required for successful burn vote.", 0, true, 0.05, true, 1.0);
	g_ConVars[vote_slay] 	   		  = CreateConVar("sm_vote_slay", "0.60", "Percent required for successful slay vote.", 0, true, 0.05, true, 1.0);
	g_ConVars[vote_alltalk]    		  = CreateConVar("sm_vote_alltalk", "0.60", "Percent required for successful alltalk vote.", 0, true, 0.05, true, 1.0);
	g_ConVars[vote_ff] 		   		  = CreateConVar("sm_vote_ff", "0.60", "Percent required for successful friendly fire vote.", 0, true, 0.05, true, 1.0);
}

public void OnAllPluginsLoaded()
{
	if (FindPluginByFile("basefunvotes.smx") != null)
	{
		SetFailState("This plugin replaces basefuncommands. You cannot run both at once.");
	}
	
	if (FindPluginByFile("funvotes.smx") != null)
	{
		LogMessage("Unloading funvotes to prevent conflicts...");
		ServerCommand("sm plugins unload funvotes");
		
		char oldPath[PLATFORM_MAX_PATH], newPath[PLATFORM_MAX_PATH];
		
		BuildPath(Path_SM, oldPath, sizeof(oldPath), "plugins/funvotes.smx");
		BuildPath(Path_SM, newPath, sizeof(newPath), "plugins/disabled/funvotes.smx");
		if (RenameFile(newPath, oldPath))
		{
			LogMessage("Moving funvotes to disabled.");
		}
		//SetFailState("This plugin replaces funvotes.  You cannot run both at once.");
	}
	/* Account for late loading */
	Handle topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(topmenu);
	}
	
	g_NativeVotes = LibraryExists("nativevotes") && NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_YesNo);
}

public void OnLibraryAdded(const char[] name)
{
	Handle topmenu;
	if (StrEqual(name, "adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(topmenu);
	}
	else if (StrEqual(name, "nativevotes") && NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_YesNo))
	{
		g_NativeVotes = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
	{
		g_TopMenu = null;
	}
	else if (StrEqual(name, "nativevotes"))
	{
		g_NativeVotes = false;
	}
}

public void OnAdminMenuReady(Handle topmenu)
{
	/* Block us from being called twice */
	if (topmenu == g_TopMenu)
	{
		return;
	}
	
	/* Save the Handle */
	g_TopMenu = topmenu;
	
	/* Build the "Voting Commands" category */
	TopMenuObject voting_commands = FindTopMenuCategory(g_TopMenu, ADMINMENU_VOTINGCOMMANDS);
	
	if (voting_commands != INVALID_TOPMENUOBJECT)
	{
		AddToTopMenu(g_TopMenu,
			"sm_votegravity",
			TopMenuObject_Item,
			AdminMenu_VoteGravity,
			voting_commands,
			"sm_votegravity",
			ADMFLAG_VOTE);
		
		AddToTopMenu(g_TopMenu,
			"sm_voteburn",
			TopMenuObject_Item,
			AdminMenu_VoteBurn,
			voting_commands,
			"sm_voteburn",
			ADMFLAG_VOTE|ADMFLAG_SLAY);
		
		AddToTopMenu(g_TopMenu,
			"sm_voteslay",
			TopMenuObject_Item,
			AdminMenu_VoteSlay,
			voting_commands,
			"sm_voteslay",
			ADMFLAG_VOTE|ADMFLAG_SLAY);
		
		AddToTopMenu(g_TopMenu,
			"sm_votealltalk",
			TopMenuObject_Item,
			AdminMenu_VoteAllTalk,
			voting_commands,
			"sm_votealltalk",
			ADMFLAG_VOTE);
		
		AddToTopMenu(g_TopMenu,
			"sm_voteff",
			TopMenuObject_Item,
			AdminMenu_VoteFF,
			voting_commands,
			"sm_voteff",
			ADMFLAG_VOTE);
	}
}

public int Handler_VoteCallback(Handle menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			//VoteMenuClose();
			CloseHandle(menu);
		}
		
		case MenuAction_Display:
		{
			char title[64];
			GetMenuTitle(menu, title, sizeof(title));
			
			char buffer[255];
			Format(buffer, sizeof(buffer), "%T", title, param1, g_VoteInfo[VOTE_NAME]);

			Handle panel = view_as<Handle>(param2);
			SetPanelTitle(panel, buffer);
		}
		
		case MenuAction_DisplayItem:
		{
			char display[64];
			GetMenuItem(menu, param2, "", 0, _, display, sizeof(display));
		 
			if (strcmp(display, VOTE_NO) == 0 || strcmp(display, VOTE_YES) == 0)
			{
				char buffer[255];
				Format(buffer, sizeof(buffer), "%T", display, param1);

				return RedrawMenuItem(buffer);
			}
		}
		
		case MenuAction_VoteCancel:
		{
			if (param1 == VoteCancel_NoVotes)
			{
				CPrintToChatAll("%t", "No Votes Cast");
			}
		}
		
		case MenuAction_VoteEnd:
		{
			char item[64];
			float percent, limit;
			int votes, totalVotes;

			GetMenuVoteInfo(param2, votes, totalVotes);
			GetMenuItem(menu, param1, item, sizeof(item));
			
			if (strcmp(item, VOTE_NO) == 0 && param1 == 1)
			{
				votes = totalVotes - votes; // Reverse the votes to be in relation to the Yes option.
			}
			
			percent = GetVotePercent(votes, totalVotes);
			
			limit = GetConVarFloat(g_ConVars[g_VoteType]);
			
			// :TODO: g_VoteClient[userid] needs to be checked

			// A multi-argument vote is "always successful", but have to check if its a Yes/No vote.
			if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent,limit) < 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1))
			{
				/* :TODO: g_VoteClient[userid] should be used here and set to -1 if not applicable.
				 */
				LogAction(-1, -1, "Vote failed.");
				CPrintToChatAll("%t", "Vote Failed", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
			}
			else
			{
				CPrintToChatAll("%t", "Vote Successful", RoundToNearest(100.0*percent), totalVotes);
				
				char name[MAX_NAME_LENGTH];
				GetPlayerName(g_VoteClient[VOTE_CLIENTID], name, sizeof(name));

				switch (g_VoteType)
				{
					case gravity:
					{
						CPrintToChatAll("%t", "Cvar changed", "sv_gravity", item);					
						LogAction(-1, -1, "Changing gravity to %s due to vote.", item);
						SetConVarInt(g_ConVars[sv_gravity], StringToInt(item));
					}
					case burn:
					{
						CPrintToChatAllEx(g_VoteClient[VOTE_CLIENTID], "%t", "Set target on fire", "_s", name);                    
						LogAction(-1, g_VoteClient[VOTE_CLIENTID], "Vote burn successful, igniting \"%L\"", g_VoteClient[VOTE_CLIENTID]);
						
						IgniteEntity(g_VoteClient[VOTE_CLIENTID], 19.8);	
					}
					case slay:
					{
						CPrintToChatAllEx(g_VoteClient[VOTE_CLIENTID], "%t", "Slayed player", "_s", name);						
						LogAction(-1, g_VoteClient[VOTE_CLIENTID], "Vote slay successful, slaying \"%L\"", g_VoteClient[VOTE_CLIENTID]);
						
						ExtinguishEntity(g_VoteClient[VOTE_CLIENTID]);
						ForcePlayerSuicide(g_VoteClient[VOTE_CLIENTID]);
					}
					case alltalk:
					{
						CPrintToChatAll("%t", "Cvar changed", "sv_alltalk", (GetConVarBool(g_ConVars[sv_alltalk]) ? "0" : "1"));
						LogAction(-1, -1, "Changing alltalk to %s due to vote.", (GetConVarBool(g_ConVars[sv_alltalk]) ? "0" : "1"));
						SetConVarBool(g_ConVars[sv_alltalk], !GetConVarBool(g_ConVars[sv_alltalk]));
					}
					case ff:
					{
						CPrintToChatAll("%t", "Cvar changed", "mp_friendlyfire", (GetConVarBool(g_ConVars[mp_friendlyfire]) ? "0" : "1"));
						LogAction(-1, -1, "Changing friendly fire to %s due to vote.", (GetConVarBool(g_ConVars[mp_friendlyfire]) ? "0" : "1"));
						SetConVarBool(g_ConVars[mp_friendlyfire], !GetConVarBool(g_ConVars[mp_friendlyfire]));
					}				
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public int Handler_NativeVoteCallback(Handle menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			NativeVotes_Close(menu);
		}
		
		case MenuAction_Display:
		{
			NativeVotesType nVoteType = NativeVotes_GetType(menu);
			if (nVoteType == NativeVotesType_Custom_YesNo || nVoteType == NativeVotesType_Custom_Mult)
			{
				char title[64];
				NativeVotes_GetTitle(menu, title, sizeof(title));
				
				char buffer[255];
				Format(buffer, sizeof(buffer), "%T", title, param1, g_VoteInfo[VOTE_NAME]);
				
				return NativeVotes_RedrawVoteTitle(buffer);
			}
		}
		
		case MenuAction_VoteCancel:
		{
			if (param1 == VoteCancel_NoVotes)
			{
				NativeVotes_DisplayFail(menu, NativeVotesFail_NotEnoughVotes);
				CPrintToChatAll("%t", "No Votes Cast");
			}
			else
			{
				NativeVotes_DisplayFail(menu, NativeVotesFail_Generic);
			}
		}
		
		case MenuAction_VoteEnd:
		{
			char item[64];
			float percent, limit;
			int votes, totalVotes;
			
			NativeVotesType nVoteType = NativeVotes_GetType(menu);

			NativeVotes_GetInfo(param2, votes, totalVotes);
			NativeVotes_GetItem(menu, param1, item, sizeof(item));
			
			if (nVoteType == NativeVotesType_Custom_YesNo && param1 == NATIVEVOTES_VOTE_NO)
			{
				votes = totalVotes - votes; // Reverse the votes to be in relation to the Yes option.
			}
			
			percent = GetVotePercent(votes, totalVotes);
			
			limit = GetConVarFloat(g_ConVars[g_VoteType]);
			
			// :TODO: g_VoteClient[userid] needs to be checked

			// A multi-argument vote is "always successful", but have to check if its a Yes/No vote.
			if ((nVoteType != NativeVotesType_NextLevelMult && nVoteType != NativeVotesType_Custom_Mult) && ((param1 == NATIVEVOTES_VOTE_YES && FloatCompare(percent,limit) < 0) || (param1 == NATIVEVOTES_VOTE_NO)))
			{
				/* :TODO: g_VoteClient[userid] should be used here and set to -1 if not applicable.
				 */
				NativeVotes_DisplayFail(menu, NativeVotesFail_Loses);
				LogAction(-1, -1, "Vote failed.");
				CPrintToChatAll("%t", "Vote Failed", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
			}
			else
			{
				CPrintToChatAll("%t", "Vote Successful", RoundToNearest(100.0*percent), totalVotes);
				
				switch (g_VoteType)
				{
					case gravity:
					{
						CPrintToChatAll("%t", "Cvar changed", "sv_gravity", item);
						NativeVotes_DisplayPassCustom(menu, "%t", "Cvar changed", "sv_gravity", item);
						LogAction(-1, -1, "Changing gravity to %s due to vote.", item);
						SetConVarInt(g_ConVars[sv_gravity], StringToInt(item));
					}
					
					case burn:
					{
						CPrintToChatAll("%t", "Set target on fire", "_s", g_VoteInfo[VOTE_NAME]);
						NativeVotes_DisplayPassCustom(menu, "%t", "Set target on fire", "_s", g_VoteInfo[VOTE_NAME]);
						LogAction(-1, g_VoteClient[VOTE_CLIENTID], "Vote burn successful, igniting \"%L\"", g_VoteClient[VOTE_CLIENTID]);
						
						IgniteEntity(g_VoteClient[VOTE_CLIENTID], 19.8);	
					}
					
					case slay:
					{
						CPrintToChatAll("%t", "Slayed player", g_VoteInfo[VOTE_NAME]);
						NativeVotes_DisplayPassCustom(menu, "%t", "Slayed player", g_VoteInfo[VOTE_NAME]);
						LogAction(-1, g_VoteClient[VOTE_CLIENTID], "Vote slay successful, slaying \"%L\"", g_VoteClient[VOTE_CLIENTID]);
						
						ExtinguishEntity(g_VoteClient[VOTE_CLIENTID]);
						ForcePlayerSuicide(g_VoteClient[VOTE_CLIENTID]);
					}
					
					case alltalk:
					{
						CPrintToChatAll("%t", "Cvar changed", "sv_alltalk", (GetConVarBool(g_ConVars[sv_alltalk]) ? "0" : "1"));
						NativeVotes_DisplayPassCustom(menu, "%t", "Cvar changed", "sv_alltalk", (GetConVarBool(g_ConVars[sv_alltalk]) ? "0" : "1"));
						LogAction(-1, -1, "Changing alltalk to %s due to vote.", (GetConVarBool(g_ConVars[sv_alltalk]) ? "0" : "1"));
						SetConVarBool(g_ConVars[sv_alltalk], !GetConVarBool(g_ConVars[sv_alltalk]));
					}
					
					case ff:
					{
						CPrintToChatAll("%t", "Cvar changed", "mp_friendlyfire", (GetConVarBool(g_ConVars[mp_friendlyfire]) ? "0" : "1"));
						NativeVotes_DisplayPassCustom(menu, "%t", "Cvar changed", "mp_friendlyfire", (GetConVarBool(g_ConVars[mp_friendlyfire]) ? "0" : "1"));
						LogAction(-1, -1, "Changing friendly fire to %s due to vote.", (GetConVarBool(g_ConVars[mp_friendlyfire]) ? "0" : "1"));
						SetConVarBool(g_ConVars[mp_friendlyfire], !GetConVarBool(g_ConVars[mp_friendlyfire]));
					}				
				}
			}
		}
	}
	
	return Plugin_Continue;
}

float GetVotePercent(int votes, int totalVotes)
{
	return float(votes) / float(totalVotes);
}

bool TestVoteDelay(int client)
{
	int delay = Internal_CheckVoteDelay();
	if (client <= 0 || GetUserFlagBits(client) & ADMFLAG_GENERIC)
	{
		delay = 0;
	}

	if (delay > 0)
	{
		if (delay > 60)
		{
			CReplyToCommand(client, "%t", "Vote Delay Minutes", delay % 60);
		}
		else
		{
			CReplyToCommand(client, "%t", "Vote Delay Seconds", delay);
		}
		
		if (g_NativeVotes)
		{
			NativeVotes_DisplayCallVoteFail(client, NativeVotesCallFail_Recent, delay);
		}
		
		return false;
	}
	
	return true;
}

bool Internal_IsVoteInProgress()
{
	if (g_NativeVotes)
	{
		return NativeVotes_IsVoteInProgress();
	}
	
	return IsVoteInProgress();
}

int Internal_CheckVoteDelay()
{
	if (g_NativeVotes)
	{
		return NativeVotes_CheckVoteDelay();
	}
	
	return CheckVoteDelay();
}

bool Internal_IsNewVoteAllowed()
{
	if (g_NativeVotes)
	{
		return NativeVotes_IsNewVoteAllowed();
	}
	
	return IsNewVoteAllowed();
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