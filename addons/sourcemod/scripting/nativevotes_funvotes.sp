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

#define VERSION "25w52a"

public Plugin:myinfo =
{
	name = "NativeVotes Fun Votes",
	author = "Powerlord and AlliedModders LLC",
	description = "NativeVotes Fun Vote Commands",
	version = VERSION,
	url = "https://github.com/Heapons/sourcemod-nativevotes-updated/"
};

#define VOTE_NO "###no###"
#define VOTE_YES "###yes###"

//new Handle:g_hVoteMenu = INVALID_HANDLE;

new Handle:g_Cvar_Limits[5] = {INVALID_HANDLE, ...};
new Handle:g_Cvar_Gravity = INVALID_HANDLE;
new Handle:g_Cvar_Alltalk = INVALID_HANDLE;
new Handle:g_Cvar_FF = INVALID_HANDLE;

// new Handle:g_Cvar_Show = INVALID_HANDLE;

enum voteType
{
	gravity = 0,
	burn,
	slay,
	alltalk,
	ff
};

new voteType:g_voteType = voteType:gravity;

// Menu API does not provide us with a way to pass multiple peices of data with a single
// choice, so some globals are used to hold stuff.
//
#define VOTE_CLIENTID	0
#define VOTE_USERID	1
new g_voteClient[2];		/* Holds the target's client id and user id */

#define VOTE_NAME	0
#define VOTE_AUTHID	1
#define	VOTE_IP		2
new String:g_voteInfo[3][65];	/* Holds the target's name, authid, and IP */

new Handle:hTopMenu = INVALID_HANDLE;

// NativeVotes
new bool:g_NativeVotes;

#include "nativevotes_funvotes/votegravity.sp"
#include "nativevotes_funvotes/voteburn.sp"
#include "nativevotes_funvotes/voteslay.sp"
#include "nativevotes_funvotes/votealltalk.sp"
#include "nativevotes_funvotes/voteff.sp"

public OnPluginStart()
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

	g_Cvar_Limits[0] = CreateConVar("sm_vote_gravity", "0.60", "percent required for successful gravity vote.", 0, true, 0.05, true, 1.0);
	g_Cvar_Limits[1] = CreateConVar("sm_vote_burn", "0.60", "percent required for successful burn vote.", 0, true, 0.05, true, 1.0);
	g_Cvar_Limits[2] = CreateConVar("sm_vote_slay", "0.60", "percent required for successful slay vote.", 0, true, 0.05, true, 1.0);
	g_Cvar_Limits[3] = CreateConVar("sm_vote_alltalk", "0.60", "percent required for successful alltalk vote.", 0, true, 0.05, true, 1.0);
	g_Cvar_Limits[4] = CreateConVar("sm_vote_ff", "0.60", "percent required for successful friendly fire vote.", 0, true, 0.05, true, 1.0);
	CreateConVar("nativevotes_funvotes_version", VERSION, "NativeVotes Fun Votes version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY);
	
	g_Cvar_Gravity = FindConVar("sv_gravity");
	g_Cvar_Alltalk = FindConVar("sv_alltalk");
	g_Cvar_FF = FindConVar("mp_friendlyfire");
	
	/*
	g_Cvar_Show = FindConVar("sm_vote_show");
	if (g_Cvar_Show == INVALID_HANDLE)
	{
		g_Cvar_Show = CreateConVar("sm_vote_show", "1", "Show player's votes? Default on.", 0, true, 0.0, true, 1.0);
	}
	*/
}

public OnAllPluginsLoaded()
{
	if (FindPluginByFile("basefunvotes.smx") != INVALID_HANDLE)
	{
		SetFailState("This plugin replaces basefuncommands.  You cannot run both at once.");
	}
	
	if (FindPluginByFile("funvotes.smx") != INVALID_HANDLE)
	{
		LogMessage("Unloading funvotes to prevent conflicts...");
		ServerCommand("sm plugins unload funvotes");

		decl String:oldPath[PLATFORM_MAX_PATH];
		decl String:newPath[PLATFORM_MAX_PATH];

		BuildPath(Path_SM, oldPath, sizeof(oldPath), "plugins/funvotes.smx");
		BuildPath(Path_SM, newPath, sizeof(newPath), "plugins/disabled/funvotes.smx");
		if (RenameFile(newPath, oldPath))
		{
			LogMessage("Moving funvotes to disabled.");
		}
		
		
		//SetFailState("This plugin replaces funvotes.  You cannot run both at once.");
		
	}
	
	/* Account for late loading */
	new Handle:topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}

	g_NativeVotes = LibraryExists("nativevotes") && NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_YesNo);
}

public OnLibraryAdded(const String:name[])
{
	new Handle:topmenu;
	if (StrEqual(name, "adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
	else
	if (StrEqual(name, "nativevotes") && NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_YesNo))
	{
		g_NativeVotes = true;
	}
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "adminmenu"))
	{
		hTopMenu = INVALID_HANDLE;
	}
	else
	if (StrEqual(name, "nativevotes"))
	{
		g_NativeVotes = false;
	}
}

public OnAdminMenuReady(Handle:topmenu)
{
	/* Block us from being called twice */
	if (topmenu == hTopMenu)
	{
		return;
	}
	
	/* Save the Handle */
	hTopMenu = topmenu;
	
	/* Build the "Voting Commands" category */
	new TopMenuObject:voting_commands = FindTopMenuCategory(hTopMenu, ADMINMENU_VOTINGCOMMANDS);

	if (voting_commands != INVALID_TOPMENUOBJECT)
	{
		AddToTopMenu(hTopMenu,
			"sm_votegravity",
			TopMenuObject_Item,
			AdminMenu_VoteGravity,
			voting_commands,
			"sm_votegravity",
			ADMFLAG_VOTE);
			
		AddToTopMenu(hTopMenu,
			"sm_voteburn",
			TopMenuObject_Item,
			AdminMenu_VoteBurn,
			voting_commands,
			"sm_voteburn",
			ADMFLAG_VOTE|ADMFLAG_SLAY);
			
		AddToTopMenu(hTopMenu,
			"sm_voteslay",
			TopMenuObject_Item,
			AdminMenu_VoteSlay,
			voting_commands,
			"sm_voteslay",
			ADMFLAG_VOTE|ADMFLAG_SLAY);
			
		AddToTopMenu(hTopMenu,
			"sm_votealltalk",
			TopMenuObject_Item,
			AdminMenu_VoteAllTalk,
			voting_commands,
			"sm_votealltalk",
			ADMFLAG_VOTE);
			
		AddToTopMenu(hTopMenu,
			"sm_voteff",
			TopMenuObject_Item,
			AdminMenu_VoteFF,
			voting_commands,
			"sm_voteff",
			ADMFLAG_VOTE);
	}
}

public Handler_VoteCallback(Handle:menu, MenuAction:action, param1, param2)
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
			decl String:title[64];
			GetMenuTitle(menu, title, sizeof(title));
			
			decl String:buffer[255];
			Format(buffer, sizeof(buffer), "%T", title, param1, g_voteInfo[VOTE_NAME]);

			new Handle:panel = Handle:param2;
			SetPanelTitle(panel, buffer);
		}
		
		case MenuAction_DisplayItem:
		{
			decl String:display[64];
			GetMenuItem(menu, param2, "", 0, _, display, sizeof(display));
		 
			if (strcmp(display, VOTE_NO) == 0 || strcmp(display, VOTE_YES) == 0)
			{
				decl String:buffer[255];
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
			decl String:item[64];
			new Float:percent, Float:limit, votes, totalVotes;

			GetMenuVoteInfo(param2, votes, totalVotes);
			GetMenuItem(menu, param1, item, sizeof(item));
			
			if (strcmp(item, VOTE_NO) == 0 && param1 == 1)
			{
				votes = totalVotes - votes; // Reverse the votes to be in relation to the Yes option.
			}
			
			percent = GetVotePercent(votes, totalVotes);
			
			limit = GetConVarFloat(g_Cvar_Limits[g_voteType]);
			
			/* :TODO: g_voteClient[userid] needs to be checked */

			// A multi-argument vote is "always successful", but have to check if its a Yes/No vote.
			if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent,limit) < 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1))
			{
				/* :TODO: g_voteClient[userid] should be used here and set to -1 if not applicable.
				 */
				LogAction(-1, -1, "Vote failed.");
				CPrintToChatAll("%t", "Vote Failed", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
			}
			else
			{
				CPrintToChatAll("%t", "Vote Successful", RoundToNearest(100.0*percent), totalVotes);
				
				switch (g_voteType)
				{
					case (voteType:gravity):
					{
						CPrintToChatAll("%t", "Cvar changed", "sv_gravity", item);					
						LogAction(-1, -1, "Changing gravity to %s due to vote.", item);
						SetConVarInt(g_Cvar_Gravity, StringToInt(item));
					}
					
					case (voteType:burn):
					{
						CPrintToChatAll("%t", "Set target on fire", "_s", g_voteInfo[VOTE_NAME]);					
						LogAction(-1, g_voteClient[VOTE_CLIENTID], "Vote burn successful, igniting \"%L\"", g_voteClient[VOTE_CLIENTID]);
						
						IgniteEntity(g_voteClient[VOTE_CLIENTID], 19.8);	
					}
					
					case (voteType:slay):
					{
						CPrintToChatAll("%t", "Slayed player", g_voteInfo[VOTE_NAME]);					
						LogAction(-1, g_voteClient[VOTE_CLIENTID], "Vote slay successful, slaying \"%L\"", g_voteClient[VOTE_CLIENTID]);
						
						ExtinguishEntity(g_voteClient[VOTE_CLIENTID]);
						ForcePlayerSuicide(g_voteClient[VOTE_CLIENTID]);
					}
					
					case (voteType:alltalk):
					{
						CPrintToChatAll("%t", "Cvar changed", "sv_alltalk", (GetConVarBool(g_Cvar_Alltalk) ? "0" : "1"));
						LogAction(-1, -1, "Changing alltalk to %s due to vote.", (GetConVarBool(g_Cvar_Alltalk) ? "0" : "1"));
						SetConVarBool(g_Cvar_Alltalk, !GetConVarBool(g_Cvar_Alltalk));
					}
					
					case (voteType:ff):
					{
						CPrintToChatAll("%t", "Cvar changed", "mp_friendlyfire", (GetConVarBool(g_Cvar_FF) ? "0" : "1"));
						LogAction(-1, -1, "Changing friendly fire to %s due to vote.", (GetConVarBool(g_Cvar_FF) ? "0" : "1"));
						SetConVarBool(g_Cvar_FF, !GetConVarBool(g_Cvar_FF));
					}				
				}
			}
		}
	}
	
	return 0;
}

public Handler_NativeVoteCallback(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		
		case MenuAction_End:
		{
			NativeVotes_Close(menu);
		}
		
		case MenuAction_Display:
		{
			new NativeVotesType:nVoteType = NativeVotes_GetType(menu);
			if (nVoteType == NativeVotesType_Custom_YesNo || nVoteType == NativeVotesType_Custom_Mult)
			{
				decl String:title[64];
				NativeVotes_GetTitle(menu, title, sizeof(title));
				
				decl String:buffer[255];
				Format(buffer, sizeof(buffer), "%T", title, param1, g_voteInfo[VOTE_NAME]);
				
				return _:NativeVotes_RedrawVoteTitle(buffer);
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
			decl String:item[64];
			new Float:percent, Float:limit, votes, totalVotes;
			
			new NativeVotesType:nVoteType = NativeVotes_GetType(menu);

			NativeVotes_GetInfo(param2, votes, totalVotes);
			NativeVotes_GetItem(menu, param1, item, sizeof(item));
			
			if (nVoteType == NativeVotesType_Custom_YesNo && param1 == NATIVEVOTES_VOTE_NO)
			{
				votes = totalVotes - votes; // Reverse the votes to be in relation to the Yes option.
			}
			
			percent = GetVotePercent(votes, totalVotes);
			
			limit = GetConVarFloat(g_Cvar_Limits[g_voteType]);
			
			/* :TODO: g_voteClient[userid] needs to be checked */

			// A multi-argument vote is "always successful", but have to check if its a Yes/No vote.
			if ((nVoteType != NativeVotesType_NextLevelMult && nVoteType != NativeVotesType_Custom_Mult) && ((param1 == NATIVEVOTES_VOTE_YES && FloatCompare(percent,limit) < 0) || (param1 == NATIVEVOTES_VOTE_NO)))
			{
				/* :TODO: g_voteClient[userid] should be used here and set to -1 if not applicable.
				 */
				NativeVotes_DisplayFail(menu, NativeVotesFail_Loses);
				LogAction(-1, -1, "Vote failed.");
				CPrintToChatAll("%t", "Vote Failed", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
			}
			else
			{
				CPrintToChatAll("%t", "Vote Successful", RoundToNearest(100.0*percent), totalVotes);
				
				switch (g_voteType)
				{
					case (voteType:gravity):
					{
						CPrintToChatAll("%t", "Cvar changed", "sv_gravity", item);
						NativeVotes_DisplayPassCustom(menu, "%t", "Cvar changed", "sv_gravity", item);
						LogAction(-1, -1, "Changing gravity to %s due to vote.", item);
						SetConVarInt(g_Cvar_Gravity, StringToInt(item));
					}
					
					case (voteType:burn):
					{
						CPrintToChatAll("%t", "Set target on fire", "_s", g_voteInfo[VOTE_NAME]);
						NativeVotes_DisplayPassCustom(menu, "%t", "Set target on fire", "_s", g_voteInfo[VOTE_NAME]);
						LogAction(-1, g_voteClient[VOTE_CLIENTID], "Vote burn successful, igniting \"%L\"", g_voteClient[VOTE_CLIENTID]);
						
						IgniteEntity(g_voteClient[VOTE_CLIENTID], 19.8);	
					}
					
					case (voteType:slay):
					{
						CPrintToChatAll("%t", "Slayed player", g_voteInfo[VOTE_NAME]);
						NativeVotes_DisplayPassCustom(menu, "%t", "Slayed player", g_voteInfo[VOTE_NAME]);
						LogAction(-1, g_voteClient[VOTE_CLIENTID], "Vote slay successful, slaying \"%L\"", g_voteClient[VOTE_CLIENTID]);
						
						ExtinguishEntity(g_voteClient[VOTE_CLIENTID]);
						ForcePlayerSuicide(g_voteClient[VOTE_CLIENTID]);
					}
					
					case (voteType:alltalk):
					{
						CPrintToChatAll("%t", "Cvar changed", "sv_alltalk", (GetConVarBool(g_Cvar_Alltalk) ? "0" : "1"));
						NativeVotes_DisplayPassCustom(menu, "%t", "Cvar changed", "sv_alltalk", (GetConVarBool(g_Cvar_Alltalk) ? "0" : "1"));
						LogAction(-1, -1, "Changing alltalk to %s due to vote.", (GetConVarBool(g_Cvar_Alltalk) ? "0" : "1"));
						SetConVarBool(g_Cvar_Alltalk, !GetConVarBool(g_Cvar_Alltalk));
					}
					
					case (voteType:ff):
					{
						CPrintToChatAll("%t", "Cvar changed", "mp_friendlyfire", (GetConVarBool(g_Cvar_FF) ? "0" : "1"));
						NativeVotes_DisplayPassCustom(menu, "%t", "Cvar changed", "mp_friendlyfire", (GetConVarBool(g_Cvar_FF) ? "0" : "1"));
						LogAction(-1, -1, "Changing friendly fire to %s due to vote.", (GetConVarBool(g_Cvar_FF) ? "0" : "1"));
						SetConVarBool(g_Cvar_FF, !GetConVarBool(g_Cvar_FF));
					}				
				}
			}
		}
	}
	
	return 0;
}

Float:GetVotePercent(votes, totalVotes)
{
	return FloatDiv(float(votes),float(totalVotes));
}

bool:TestVoteDelay(client)
{
 	new delay = Internal_CheckVoteDelay();
	
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

bool:Internal_IsVoteInProgress()
{
	if (g_NativeVotes)
	{
		return NativeVotes_IsVoteInProgress();
	}
	
	return IsVoteInProgress();	
}

Internal_CheckVoteDelay()
{
	if (g_NativeVotes)
	{
		return NativeVotes_CheckVoteDelay();
	}
	
	return CheckVoteDelay();	
}

bool:Internal_IsNewVoteAllowed()
{
	if (g_NativeVotes)
	{
		return NativeVotes_IsNewVoteAllowed();
	}

	return IsNewVoteAllowed();
}
