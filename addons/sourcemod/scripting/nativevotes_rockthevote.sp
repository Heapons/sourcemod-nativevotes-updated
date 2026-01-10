/**
 * vim: set ts=4 :
 * =============================================================================
 * SourceMod NativeVotes Rock The Vote Plugin
 * Creates a map vote when the required number of players have requested one.
 * Updated with NativeVotes support
 *
 * NativeVotes (C)2011-2016 Ross Bemrose (Powerlord). All rights reserved.
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

#include <sourcemod>
#include <mapchooser>
#include <nextmap>

#undef REQUIRE_PLUGIN
#include <nativevotes>
#define REQUIRE_PLUGIN

// Despite being labeled as TF2-only, this plugin does work on other games.
// It's just identical to rockthevote.smx there
#undef REQUIRE_EXTENSIONS
#include <tf2>
#define REQUIRE_EXTENSIONS

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "[NativeVotes] Rock The Vote",
	author = "AlliedModders LLC and Powerlord",
	description = "Provides RTV Map Voting",
	version = "26w02e",
	url = "https://github.com/Heapons/sourcemod-nativevotes-updated/"
};

enum
{
	needed,
	minplayers,
	initialdelay,
	interval,
	changetime,
	postvoteaction,

	MAX_CONVARS
}

ConVar g_ConVars[MAX_CONVARS];

bool g_RTVAllowed = false;					// True if RTV is available to players. Used to delay rtv votes.
int g_Voters = 0;							// Total voters connected. Doesn't include fake clients.
int g_Votes = 0;							// Total number of "say rtv" votes
int g_VotesNeeded = 0;						// Necessary votes before map vote begins. (voters * percent_needed)
bool g_Voted[MAXPLAYERS+1] = {false, ...};

bool g_InChange = false;

// NativeVotes
bool g_NativeVotes;
bool g_RegisteredMenusChangeLevel = false;
int g_RTVTime = 0;
bool g_Warmup = false;

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("rockthevote.phrases");
	
	g_ConVars[needed] = CreateConVar("sm_rtv_needed", "0.60", "Percentage of players needed to rockthevote (Def 60%)", 0, true, 0.05, true, 1.0);
	g_ConVars[minplayers] = CreateConVar("sm_rtv_minplayers", "0", "Number of players required before RTV will be enabled.", 0, true, 0.0, true, float(MAXPLAYERS));
	g_ConVars[initialdelay] = CreateConVar("sm_rtv_initialdelay", "30.0", "Time (in seconds) before first RTV can be held", 0, true, 0.00);
	g_ConVars[interval] = CreateConVar("sm_rtv_interval", "240.0", "Time (in seconds) after a failed RTV before another can be held", 0, true, 0.00);
	g_ConVars[changetime] = CreateConVar("sm_rtv_changetime", "0", "When to change the map after a succesful RTV: 0 - Instant, 1 - RoundEnd, 2 - MapEnd", _, true, 0.0, true, 2.0);
	g_ConVars[postvoteaction] = CreateConVar("sm_rtv_postvoteaction", "0", "What to do with RTV's after a mapvote has completed. 0 - Allow, success = instant change, 1 - Deny", _, true, 0.0, true, 1.0);
	
	RegConsoleCmd("sm_rtv", Command_RTV);
	RegAdminCmd("sm_forcertv", Command_ForceRTV, ADMFLAG_CHANGEMAP);
	RegAdminCmd("sm_resetrtv", Command_ResetRTV, ADMFLAG_CHANGEMAP);
	
	AutoExecConfig(true, "rtv");

	OnMapEnd();

	/* Handle late load */
	for (int i=1; i<=MaxClients; i++)
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
	if (FindPluginByFile("rockthevote.smx") != null)
	{
		LogMessage("Unloading rockthevote to prevent conflicts...");
		ServerCommand("sm plugins unload rockthevote");
		
		char oldPath[PLATFORM_MAX_PATH];
		char newPath[PLATFORM_MAX_PATH];
		
		BuildPath(Path_SM, oldPath, sizeof(oldPath), "plugins/rockthevote.smx");
		BuildPath(Path_SM, newPath, sizeof(newPath), "plugins/disabled/rockthevote.smx");
		if (RenameFile(newPath, oldPath))
		{
			LogMessage("Moving rockthevote to disabled.");
		}
	}
	
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

public void TF2_OnWaitingForPlayersStart()
{
	g_Warmup = true;
}

public void TF2_OnWaitingForPlayersEnd()
{
	g_Warmup = false;
}

public void OnMapEnd()
{
	g_RTVAllowed = false;
	g_Voters = 0;
	g_Votes = 0;
	g_VotesNeeded = 0;
	g_InChange = false;
}

public void OnConfigsExecuted()
{	
	CreateTimer(g_ConVars[initialdelay].FloatValue, Timer_DelayRTV, _, TIMER_FLAG_NO_MAPCHANGE);
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
		g_RTVAllowed ) 
	{
		if (g_ConVars[postvoteaction].IntValue == 1 && HasEndOfMapVoteFinished())
		{
			return;
		}
		
		StartRTV();
	}	
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (client <= 0 || IsChatTrigger())
	{
		return;
	}
	
	if (strcmp(sArgs, "rtv", false) == 0 || strcmp(sArgs, "rockthevote", false) == 0)
	{
		ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);
		
		Command_RTV(client, 0);
		
		SetCmdReplySource(old);
	}
}

public Action Command_RTV(int client, int args)
{
	if (client <= 0)
	{
		return Plugin_Handled;
	}
	
	AttemptRTV(client);
	
	return Plugin_Handled;
}

public Action Command_ForceRTV(int client, int args)
{
	if (!g_RTVAllowed)
	{
		g_RTVAllowed = true;
	}

	StartRTV();
	
	return Plugin_Handled;
}

public Action Command_ResetRTV(int client, int args)
{
	ResetRTV();
	
	CPrintToChatAll("[{lightgreen}Rock The Vote\x01] %t", "Cancelled Vote");
	
	return Plugin_Handled;
}

void UndoRTV(int client)
{
	char yes[64], no[64];
	Format(yes, sizeof(yes), "%T", "Yes", client);
	Format(no, sizeof(no), "%T", "No", client);

	char title[128];
	Format(title, sizeof(title), "%T", "Cancel vote", client);

	Menu menu = new Menu(MenuHandler_UndoRTV);
	menu.SetTitle(title);
	menu.AddItem("yes", yes);
	menu.AddItem("no", no);
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

void MenuHandler_UndoRTV(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		if (param2 == 0) // Yes
		{
			if (g_Voted[client])
			{
				char name[MAX_NAME_LENGTH]; int r, g, b, a, color;
				GetEntityRenderColor(client, r, g, b, a);
				color = (r << 16) | (g << 8) | b;
				if (color != 0xFFFFFF)
				{
					Format(name, sizeof(name), "{#%06X}%N\x01", color, client);
				}
				else
				{
					Format(name, sizeof(name), "{teamcolor}%N\x01", client);
				}
				
				g_Voted[client] = false;
				if (g_Votes > 0) g_Votes--;
				CPrintToChatAllEx(client, "[{lightgreen}Rock The Vote\x01] %s: %t", name, "Cancelled Vote");
			}
		}
	}
	delete menu;
}

void AttemptRTV(int client, bool isVoteMenu=false)
{
	if (!g_RTVAllowed  || (g_ConVars[postvoteaction].IntValue == 1 && HasEndOfMapVoteFinished()))
	{
		CReplyToCommand(client, "[{lightgreen}Rock The Vote\x01] %t", "RTV Not Allowed");
		if (isVoteMenu && g_NativeVotes)
		{
			if (g_Warmup)
			{
				NativeVotes_DisplayCallVoteFail(client, NativeVotesCallFail_Waiting);
			}
			else
			{
				int timeleft = g_RTVTime - GetTime();
				if (timeleft > 0)
				{
					NativeVotes_DisplayCallVoteFail(client, NativeVotesCallFail_Failed, timeleft);
				}
				else
				{
					NativeVotes_DisplayCallVoteFail(client, NativeVotesCallFail_Generic);
				}
			}
		}
		return;
	}
		
	if (!CanMapChooserStartVote() && NativeVotes_IsVoteInProgress())
	{
		CReplyToCommandEx(client, client, "[{lightgreen}Rock The Vote\x01] %t", "RTV Started");
		return;
	}
	
	if (GetClientCount(true) < g_ConVars[minplayers].IntValue)
	{
		CReplyToCommand(client, "[{lightgreen}Rock The Vote\x01] %t", "Minimal Players Not Met");
		if (isVoteMenu && g_NativeVotes)
		{
			NativeVotes_DisplayCallVoteFail(client, NativeVotesCallFail_Loading);
		}
		return;			
	}
	
	if (g_Voted[client])
	{
		UndoRTV(client);
		return;
	}	
	
	char name[MAX_NAME_LENGTH]; int r, g, b, a, color;
	GetEntityRenderColor(client, r, g, b, a);
	color = (r << 16) | (g << 8) | b;
	if (color != 0xFFFFFF)
	{
		Format(name, sizeof(name), "{#%06X}%N\x01", color, client);
	}
	else
	{
		Format(name, sizeof(name), "{teamcolor}%N\x01", client);
	}
	
	g_Votes++;
	g_Voted[client] = true;
	
	CPrintToChatAllEx(client, "[{lightgreen}Rock The Vote\x01] %t", "RTV Requested", name, g_Votes, g_VotesNeeded);
	
	if (g_Votes >= g_VotesNeeded)
	{
		StartRTV();
	}	
}

public Action Timer_DelayRTV(Handle timer)
{
	g_RTVAllowed = true;

	return Plugin_Continue;
}

void StartRTV()
{
	if (g_InChange)
	{
		return;	
	}
	
	if (EndOfMapVoteEnabled() && HasEndOfMapVoteFinished())
	{
		/* Change right now then */
		char map[96];
		if (GetNextMap(map, sizeof(map)))
		{
			GetMapDisplayName(map, map, sizeof(map));
			Format(map, sizeof(map), "\x05%s\x01", map);
			
			CPrintToChatAll("[{lightgreen}Rock The Vote\x01] %t", "Changing Maps", map);
			CreateTimer(5.0, Timer_ChangeMap, _, TIMER_FLAG_NO_MAPCHANGE);
			g_InChange = true;
			
			ResetRTV();
			
			g_RTVAllowed = false;
		}
		return;	
	}
	
	if (CanMapChooserStartVote())
	{
		MapChange when = view_as<MapChange>(g_ConVars[changetime].IntValue);
		InitiateMapChooserVote(when);
		
		ResetRTV();
		
		g_RTVAllowed = false;
		g_RTVTime = GetTime() + g_ConVars[interval].IntValue;

		CreateTimer(g_ConVars[interval].FloatValue, Timer_DelayRTV, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

void ResetRTV()
{
	g_Votes = 0;
			
	for (int i=1; i<=MAXPLAYERS; i++)
	{
		g_Voted[i] = false;
	}
}

public Action Timer_ChangeMap(Handle hTimer)
{
	g_InChange = false;
	
	LogMessage("RTV changing map manually");
	
	char map[96];
	if (GetNextMap(map, sizeof(map)))
	{	
		ForceChangeLevel(map, "RTV after mapvote");
	}
	
	return Plugin_Stop;
}

void RegisterVoteHandler()
{
	if (!g_NativeVotes)
		return;
		
	if (!g_RegisteredMenusChangeLevel)
	{
		NativeVotes_RegisterVoteCommand(NativeVotesOverride_ChgLevel, Menu_RTV);
		g_RegisteredMenusChangeLevel = true;
	}
}

void RemoveVoteHandler()
{
	if (g_RegisteredMenusChangeLevel)
	{
		if (g_NativeVotes)
			NativeVotes_UnregisterVoteCommand(NativeVotesOverride_ChgLevel, Menu_RTV);
			
		g_RegisteredMenusChangeLevel = false;
	}
		
}

public Action Menu_RTV(int client, NativeVotesOverride overrideType, const char[] voteArgument)
{
	if (client <= 0 || NativeVotes_IsVoteInProgress())
	{
		return Plugin_Handled;
	}
	
	if (strlen(voteArgument) == 0)
	{
		NativeVotes_DisplayCallVoteFail(client, NativeVotesCallFail_SpecifyMap);
		return Plugin_Handled;
	}
	
	ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);
	
	// awful hack, but whatever
	char mapname[96];
	strcopy(mapname, sizeof(mapname), voteArgument);
	FakeClientCommand(client, "sm_nominate %s", voteArgument);

	AttemptRTV(client, true);
	
	SetCmdReplySource(old);
	
	return Plugin_Handled;
}
