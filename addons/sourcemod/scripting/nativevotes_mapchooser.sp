/**
 * vim: set ts=4 :
 * =============================================================================
 * SourceMod NativeVotes Mapchooser Plugin
 * Creates a map vote at appropriate times, setting sm_nextmap to the winning
 * vote
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
#include <regex>

#undef REQUIRE_PLUGIN
#include <nativevotes>
#define REQUIRE_PLUGIN

#undef REQUIRE_EXTENSIONS
#include <ripext>
#define REQUIRE_EXTENSIONS

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "NativeVotes | MapChooser",
	author = "AlliedModders LLC and Powerlord",
	description = "Automated Map Voting",
	version = "26w05a",
	url = "https://github.com/Heapons/sourcemod-nativevotes-updated/"
};

/* ConVars */
enum
{
	/* Valve ConVars */
	mp_winlimit,
	mp_maxrounds,
	mp_fraglimit,
	mp_bonusroundtime,
	mapcyclefile,

	/* Plugin ConVars */
	mapvote_endvote,
	mapvote_start,
	mapvote_startround,
	mapvote_startfrags,
	extendmap_timestep,
	extendmap_roundstep,
	extendmap_fragstep,
	mapvote_exclude,
	mapvote_include,
	mapvote_novote,
	mapvote_extend,
	mapvote_dontchange,
	mapvote_voteduration,
	mapvote_runoff,
	mapvote_runoffpercent,
	mapcycle_auto,
	mapcycle_exclude,
	workshop_map_collection,
	workshop_cleanup,

	MAX_CONVARS
}

ConVar g_ConVars[MAX_CONVARS];

Handle g_VoteTimer = null;
Handle g_RetryTimer = null;

// g_MapList stores unresolved names so we can resolve them after every map change in the workshop updates.
// g_OldMapList and g_NextMapList are resolved. g_NominateList depends on the nominations implementation.
/* Data Handles */
ArrayList g_MapList;
ArrayList g_NominateList;
ArrayList g_NominateOwners;
ArrayList g_OldMapList;
ArrayList g_NextMapList;
Menu g_VoteMenu;
NativeVote g_VoteNative;

int g_Extends;
int g_TotalRounds;
bool g_HasVoteStarted;
bool g_WaitingForVote;
bool g_MapVoteCompleted;
bool g_ChangeMapAtRoundEnd;
bool g_ChangeMapInProgress;
int g_mapFileSerial = -1;

MapChange g_ChangeTime;

Handle g_NominationsResetForward = null;
Handle g_MapVoteStartedForward = null;

/* Upper bound of how many team there could be */
#define MAX_TEAMS 10
int g_winCount[MAX_TEAMS];

#define VOTE_EXTEND 	"##extend##"
#define VOTE_DONTCHANGE "##dontchange##"

// Libraries
bool g_NativeVotes;
bool g_RestInPawn;

public void OnPluginStart()
{
	LoadTranslations("mapchooser.phrases");
	LoadTranslations("common.phrases");

	KeyValues kv = new KeyValues("GameInfo");
	kv.ImportFromFile("gameinfo.txt");

	char gameDir[128];
	GetGameFolderName(gameDir, sizeof(gameDir));
	
	EngineVersion engine = GetEngineVersion();
	if (!StrEqual(gameDir, "tf") &&
		(kv.GetNum("DependsOnAppID") == 440 ||
		(engine == Engine_SDK2013 && FileExists("resource/tf.ttf"))))
	{
		engine = Engine_TF2;
	}

	int arraySize = ByteCountToCells(PLATFORM_MAX_PATH);
	g_MapList = new ArrayList(arraySize);
	g_NominateList = new ArrayList(arraySize);
	g_NominateOwners = new ArrayList();
	g_OldMapList = new ArrayList(arraySize);
	g_NextMapList = new ArrayList(arraySize);

	g_ConVars[mapvote_endvote] 		 		= CreateConVar("sm_mapvote_endvote", "1", "Specifies if MapChooser should run an end of map vote.", _, true, 0.0, true, 1.0);
	g_ConVars[mapvote_start] 		 		= CreateConVar("sm_mapvote_start", "3.0", "Specifies when to start the vote based on time remaining.", _, true, 1.0);
	g_ConVars[mapvote_startround]    		= CreateConVar("sm_mapvote_startround", "2.0", "Specifies when to start the vote based on rounds remaining. Use '0' on TF2 to start vote during bonus round time", _, true, 0.0);
	g_ConVars[mapvote_startfrags]    		= CreateConVar("sm_mapvote_startfrags", "5.0", "Specifies when to start the vote base on frags remaining.", _, true, 1.0);
	g_ConVars[extendmap_timestep]    		= CreateConVar("sm_extendmap_timestep", "15", "Specifies how much many more minutes each extension makes.", _, true, 5.0);
	g_ConVars[extendmap_roundstep]   		= CreateConVar("sm_extendmap_roundstep", "5", "Specifies how many more rounds each extension makes.", _, true, 1.0);
	g_ConVars[extendmap_fragstep]    		= CreateConVar("sm_extendmap_fragstep", "10", "Specifies how many more frags are allowed when map is extended.", _, true, 5.0);	
	g_ConVars[mapvote_exclude]       		= CreateConVar("sm_mapvote_exclude", "5", "Specifies how many past maps to exclude from the vote.", _, true, 0.0);
	g_ConVars[mapvote_include]       		= CreateConVar("sm_mapvote_include", "5", "Specifies how many maps to include in the vote.", _, true, 2.0, true, 6.0);
	g_ConVars[mapvote_novote]        		= CreateConVar("sm_mapvote_novote", "1", "Specifies whether or not MapChooser should pick a map if no votes are received.", _, true, 0.0, true, 1.0);
	g_ConVars[mapvote_extend]        		= CreateConVar("sm_mapvote_extend", "0", "Number of extensions allowed each map.", _, true, 0.0);
	g_ConVars[mapvote_dontchange]    		= CreateConVar("sm_mapvote_dontchange", "1", "Specifies if a 'Don't Change' option should be added to early votes.", _, true, 0.0, true, 1.0);
	g_ConVars[mapvote_voteduration]  		= CreateConVar("sm_mapvote_voteduration", "20", "Specifies how long the mapvote should be available for.", _, true, 5.0);
	g_ConVars[mapvote_runoff] 		 		= CreateConVar("sm_mapvote_runoff", "0", "Hold run of votes if winning choice is less than a certain margin.", _, true, 0.0, true, 1.0);
	g_ConVars[mapvote_runoffpercent] 		= CreateConVar("sm_mapvote_runoffpercent", "50", "If winning choice has less than this percent of votes, hold a runoff.", _, true, 0.0, true, 100.0);
	g_ConVars[mapcycle_auto]         		= CreateConVar("sm_mapcycle_auto", "0", "Specifies whether or not to automatically populate the maps list.", _, true, 0.0, true, 1.0);
	g_ConVars[mapcycle_exclude]      		= CreateConVar("sm_mapcycle_exclude", ".*itemtest.*|background01|^tr.*$", "Specifies which maps shouldn't be automatically added with a regex pattern.");
	if (engine != Engine_SDK2013 && engine == Engine_TF2)
	{
		g_ConVars[workshop_map_collection]  = CreateConVar("sm_workshop_map_collection", "", "Specifies the workshop collection to fetch the maps from.");
		g_ConVars[workshop_cleanup] 		= CreateConVar("sm_workshop_map_cleanup", "0", "Specifies whether or not to automatically workshop maps on map change.", _, true, 0.0, true, 1.0);
	}

	RegAdminCmd("sm_mapvote", Command_MapVote, ADMFLAG_CHANGEMAP, "Forces MapChooser to attempt to run a map vote now.");
	RegAdminCmd("sm_setnextmap", Command_SetNextMap, ADMFLAG_CHANGEMAP, "sm_setnextmap <map>");

	g_ConVars[mp_winlimit]       = FindConVar("mp_winlimit");
	g_ConVars[mp_maxrounds]      = FindConVar("mp_maxrounds");
	g_ConVars[mp_fraglimit]      = FindConVar("mp_fraglimit");
	g_ConVars[mp_bonusroundtime] = FindConVar("mp_bonusroundtime");
	g_ConVars[mapcyclefile]      = FindConVar("mapcyclefile");
	
	if (g_ConVars[mp_winlimit] || g_ConVars[mp_maxrounds])
	{
		switch (engine)
		{
			case Engine_TF2:
			{
				HookEvent("teamplay_win_panel", Event_TeamplayWinPanel);
				HookEvent("teamplay_restart_round", Event_TeamplayRestartRound);
				HookEvent("arena_win_panel", Event_TeamplayWinPanel);
			}
			case Engine_NuclearDawn:
			{
				HookEvent("round_win", Event_RoundEnd);
			}
			default:
			{
				HookEvent("round_end", Event_RoundEnd);
			}
		}
	}
	
	if (g_ConVars[mp_fraglimit])
	{
		HookEvent("player_death", Event_PlayerDeath);		
	}
	
	AutoExecConfig(true, "mapchooser");
	
	// Change the mp_bonusroundtime max so that we have time to display the vote
	// If you display a vote during bonus time good defaults are 17 vote duration and 19 mp_bonustime
	if (g_ConVars[mp_bonusroundtime])
	{
		g_ConVars[mp_bonusroundtime].SetBounds(ConVarBound_Upper, true, 30.0);		
	}
	
	g_NominationsResetForward = CreateGlobalForward("OnNominationRemoved", ET_Ignore, Param_String, Param_Cell);
	g_MapVoteStartedForward   = CreateGlobalForward("OnMapVoteStarted", ET_Ignore);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("mapchooser");	
	
	CreateNative("NominateMap", Native_NominateMap);
	CreateNative("RemoveNominationByMap", Native_RemoveNominationByMap);
	CreateNative("RemoveNominationByOwner", Native_RemoveNominationByOwner);
	CreateNative("InitiateMapChooserVote", Native_InitiateVote);
	CreateNative("CanMapChooserStartVote", Native_CanVoteStart);
	CreateNative("HasEndOfMapVoteFinished", Native_CheckVoteDone);
	CreateNative("GetExcludeMapList", Native_GetExcludeMapList);
	CreateNative("GetNominatedMapList", Native_GetNominatedMapList);
	CreateNative("EndOfMapVoteEnabled", Native_EndOfMapVoteEnabled);

	// Why doesn't RIP ext already set these as optional??
	MarkNativeAsOptional("HTTPRequest.HTTPRequest");
	MarkNativeAsOptional("HTTPRequest.AppendFormParam");
	MarkNativeAsOptional("HTTPRequest.PostForm");
	MarkNativeAsOptional("HTTPResponse.Status.get");
	MarkNativeAsOptional("HTTPResponse.Data.get");
	MarkNativeAsOptional("JSONObject.Get");
	MarkNativeAsOptional("JSONObject.GetInt");
	MarkNativeAsOptional("JSONObject.GetString");
	MarkNativeAsOptional("JSONArray.Get");
	MarkNativeAsOptional("JSONArray.Length.get");

	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	if (FindPluginByFile("mapchooser.smx") != null)
	{
		LogMessage("Unloading mapchooser to prevent conflicts...");
		ServerCommand("sm plugins unload mapchooser");
		
		char oldPath[PLATFORM_MAX_PATH];
		char newPath[PLATFORM_MAX_PATH];
		
		BuildPath(Path_SM, oldPath, sizeof(oldPath), "plugins/mapchooser.smx");
		BuildPath(Path_SM, newPath, sizeof(newPath), "plugins/disabled/mapchooser.smx");
		if (RenameFile(newPath, oldPath))
		{
			LogMessage("Moving mapchooser to disabled.");
		}
	}
	
	g_NativeVotes = LibraryExists("nativevotes") && NativeVotes_IsVoteTypeSupported(NativeVotesType_NextLevelMult);
	g_RestInPawn  = GetExtensionFileStatus("rip.ext") == 1;
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "nativevotes", false) && NativeVotes_IsVoteTypeSupported(NativeVotesType_NextLevelMult))
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
	else if (StrEqual(name, "rip.ext", false))
	{
		g_RestInPawn = false;
	}
}

public void OnConfigsExecuted()
{
	if (g_ConVars[workshop_cleanup].BoolValue)
	{
		CleanupWorkshopMaps();
	}

	if (g_ConVars[mapcycle_auto].BoolValue)
	{
		PopulateMapList();
	}

	if (ReadMapList(g_MapList, g_mapFileSerial, "mapchooser", MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER) != null)
	{
		if (g_mapFileSerial == -1)
		{
			LogError("Unable to create a valid map list.");
		}
	}

	CreateNextVote();
	SetupTimeleftTimer();
	
	g_TotalRounds = 0;
	
	g_Extends = 0;
	
	g_MapVoteCompleted = false;
	
	g_NominateList.Clear();
	g_NominateOwners.Clear();
	
	for (int i = 0; i < MAX_TEAMS; i++)
	{
		g_winCount[i] = 0;	
	}

	/* Check if mapchooser will attempt to start mapvote during bonus round time - TF2 Only */
	if (g_ConVars[mp_bonusroundtime] && !g_ConVars[mapvote_startround].IntValue)
	{
		if (g_ConVars[mp_bonusroundtime].FloatValue <= g_ConVars[mapvote_voteduration].FloatValue)
		{
			LogMessage("Warning - Bonus Round Time shorter than Vote Time. Votes during bonus round may not have time to complete");
		}
	}
}

public void OnMapEnd()
{
	g_HasVoteStarted = false;
	g_WaitingForVote = false;
	g_ChangeMapAtRoundEnd = false;
	g_ChangeMapInProgress = false;
	
	g_VoteTimer = null;
	g_RetryTimer = null;
	
	char map[PLATFORM_MAX_PATH];
	GetCurrentMap(map, sizeof(map));
	g_OldMapList.PushString(map);
				
	while (g_OldMapList.Length > g_ConVars[mapvote_exclude].IntValue)
	{
		g_OldMapList.Erase(0);
	}	
}

public void OnClientDisconnect(int client)
{
	int index = g_NominateOwners.FindValue(client);
	
	if (index == -1)
	{
		return;
	}
	
	char oldmap[PLATFORM_MAX_PATH];
	g_NominateList.GetString(index, oldmap, sizeof(oldmap));
	Call_StartForward(g_NominationsResetForward);
	Call_PushString(oldmap);
	Call_PushCell(g_NominateOwners.Get(index));
	Call_Finish();
	
	g_NominateOwners.Erase(index);
	g_NominateList.Erase(index);
}

public Action Command_SetNextMap(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "[{lightgreen}MapChooser\x01] Usage: sm_setnextmap <map>");
		return Plugin_Handled;
	}

	char map[PLATFORM_MAX_PATH], displayName[PLATFORM_MAX_PATH];
	GetCmdArg(1, map, sizeof(map));

	if (FindMap(map, displayName, sizeof(displayName)) == FindMap_NotFound)
	{
		CReplyToCommand(client, "[{lightgreen}MapChooser\x01] %t", "Map was not found", map);
		return Plugin_Handled;
	}
	
	GetMapDisplayName(displayName, displayName, sizeof(displayName));
	Format(displayName, sizeof(displayName), "\x05%s\x01", displayName);
	
	CShowActivity(client, "%t", "Changed Next Map", displayName);
	LogAction(client, -1, "\"%L\" changed nextmap to \"%s\"", client, map);

	SetNextMap(map);
	g_MapVoteCompleted = true;

	return Plugin_Handled;
}

public void OnMapTimeLeftChanged()
{
	if (g_MapList.Length)
	{
		SetupTimeleftTimer();
	}
}

void SetupTimeleftTimer()
{
	int time;
	if (GetMapTimeLeft(time) && time > 0)
	{
		int startTime = g_ConVars[mapvote_start].IntValue * 60;
		if (time - startTime < 0 && g_ConVars[mapvote_endvote].BoolValue && !g_MapVoteCompleted && !g_HasVoteStarted)
		{
			InitiateVote(MapChange_MapEnd, null);
		}
		else
		{
			if (g_VoteTimer != null)
			{
				KillTimer(g_VoteTimer);
				g_VoteTimer = null;
			}	
			
			//g_VoteTimer = CreateTimer(float(time - startTime), Timer_StartMapVote, _, TIMER_FLAG_NO_MAPCHANGE);
			DataPack data;
			g_VoteTimer = CreateDataTimer(float(time - startTime), Timer_StartMapVote, data, TIMER_FLAG_NO_MAPCHANGE);
			data.WriteCell(MapChange_MapEnd);
			data.WriteCell(INVALID_HANDLE);
			data.Reset();
		}		
	}
}

public Action Timer_StartMapVote(Handle timer, DataPack data)
{
	if (timer == g_RetryTimer)
	{
		g_WaitingForVote = false;
		g_RetryTimer = null;
	}
	else
	{
		g_VoteTimer = null;
	}
	
	if (!g_MapList.Length || !g_ConVars[mapvote_endvote].BoolValue || g_MapVoteCompleted || g_HasVoteStarted)
	{
		return Plugin_Stop;
	}
	
	MapChange mapChange = view_as<MapChange>(data.ReadCell());
	ArrayList hndl = view_as<ArrayList>(data.ReadCell());

	InitiateVote(mapChange, hndl);

	return Plugin_Stop;
}

public void Event_TeamplayRestartRound(Event event, const char[] name, bool dontBroadcast)
{
	/* Game got restarted - reset our round count tracking */
	g_TotalRounds = 0;	
}

public void Event_TeamplayWinPanel(Event event, const char[] name, bool dontBroadcast)
{
	if (g_ChangeMapAtRoundEnd)
	{
		g_ChangeMapAtRoundEnd = false;
		CreateTimer(2.0, Timer_ChangeMap, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
		g_ChangeMapInProgress = true;
	}
	
	int bluescore = event.GetInt("blue_score");
	int redscore = event.GetInt("red_score");
		
	if (event.GetInt("round_complete") == 1 || StrEqual(name, "arena_win_panel"))
	{
		g_TotalRounds++;
		
		if (!g_MapList.Length || g_HasVoteStarted || g_MapVoteCompleted || !g_ConVars[mapvote_endvote].BoolValue)
		{
			return;
		}
		
		CheckMaxRounds(g_TotalRounds);
		
		switch(event.GetInt("winning_team"))
		{
			case 3:
			{
				CheckWinLimit(bluescore);
			}
			case 2:
			{
				CheckWinLimit(redscore);				
			}			
			//We need to do nothing on winning_team == 0 this indicates stalemate.
			default:
			{
				return;
			}			
		}
	}
}
/* You ask, why don't you just use team_score event? And I answer... Because CSS doesn't. */
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_ChangeMapAtRoundEnd)
	{
		g_ChangeMapAtRoundEnd = false;
		CreateTimer(2.0, Timer_ChangeMap, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
		g_ChangeMapInProgress = true;
	}
	
	int winner;
	if (strcmp(name, "round_win") == 0)
	{
		// Nuclear Dawn
		winner = event.GetInt("team");
	}
	else
	{
		winner = event.GetInt("winner");
	}
	
	if (winner == 0 || winner == 1 || !g_ConVars[mapvote_endvote].BoolValue)
	{
		return;
	}
	
	if (winner >= MAX_TEAMS)
	{
		SetFailState("Mod exceed maximum team count - Please file a bug report.");	
	}

	g_TotalRounds++;
	
	g_winCount[winner]++;
	
	if (!g_MapList.Length || g_HasVoteStarted || g_MapVoteCompleted)
	{
		return;
	}
	
	CheckWinLimit(g_winCount[winner]);
	CheckMaxRounds(g_TotalRounds);
}

public void CheckWinLimit(int winner_score)
{	
	if (g_ConVars[mp_winlimit])
	{
		int winlimit = g_ConVars[mp_winlimit].IntValue;
		if (winlimit)
		{			
			if (winner_score >= (winlimit - g_ConVars[mapvote_startround].IntValue))
			{
				InitiateVote(MapChange_MapEnd, null);
			}
		}
	}
}

public void CheckMaxRounds(int roundcount)
{		
	if (g_ConVars[mp_maxrounds])
	{
		int maxrounds = g_ConVars[mp_maxrounds].IntValue;
		if (maxrounds)
		{
			if (roundcount >= (maxrounds - g_ConVars[mapvote_startround].IntValue))
			{
				InitiateVote(MapChange_MapEnd, null);
			}			
		}
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_MapList.Length || !g_ConVars[mp_fraglimit] || g_HasVoteStarted)
	{
		return;
	}
	
	if (!g_ConVars[mp_fraglimit].IntValue || !g_ConVars[mapvote_endvote].BoolValue)
	{
		return;
	}

	if (g_MapVoteCompleted)
	{
		return;
	}

	int fragger = GetClientOfUserId(event.GetInt("attacker"));

	if (!fragger)
	{
		return;
	}

	if (GetClientFrags(fragger) >= (g_ConVars[mp_fraglimit].IntValue - g_ConVars[mapvote_startfrags].IntValue))
	{
		InitiateVote(MapChange_MapEnd, null);
	}
}

public Action Command_MapVote(int client, int args)
{
	InitiateVote(MapChange_MapEnd, null);

	return Plugin_Handled;	
}

/**
 * Starts a new map vote
 *
 * @param when			When the resulting map change should occur.
 * @param inputlist		Optional list of maps to use for the vote, otherwise an internal list of nominations + random maps will be used.
 * @param noSpecials	Block special vote options like extend/nochange (upgrade this to bitflags instead?)
 */
void InitiateVote(MapChange when, ArrayList inputlist=null)
{
	g_WaitingForVote = true;
	
	if ((g_NativeVotes && NativeVotes_IsVoteInProgress()) || (!g_NativeVotes && IsVoteInProgress()))
	//if (IsVoteInProgress())
	{
		// Can't start a vote, try again in 5 seconds.
		//g_RetryTimer = CreateTimer(5.0, Timer_StartMapVote, _, TIMER_FLAG_NO_MAPCHANGE);
		
		DataPack data;
		g_RetryTimer = CreateDataTimer(5.0, Timer_StartMapVote, data, TIMER_FLAG_NO_MAPCHANGE);
		data.WriteCell(when);
		data.WriteCell(inputlist);
		data.Reset();
		return;
	}
	
	/* If the main map vote has completed (and chosen result) and its currently changing (not a delayed change) we block further attempts */
	if (g_MapVoteCompleted && g_ChangeMapInProgress)
	{
		return;
	}
	
	g_ChangeTime = when;
	
	g_WaitingForVote = false;
		
	g_HasVoteStarted = true;
	if (g_NativeVotes)
	{
		g_VoteNative = new NativeVote(Handler_NV_MapVoteMenu, NativeVotesType_NextLevelMult, NATIVEVOTES_ACTIONS_DEFAULT | MenuAction_DisplayItem);
		g_VoteNative.VoteResultCallback = Handler_NV_MapVoteFinished;
	}
	else
	{
		g_VoteMenu = new Menu(Handler_MapVoteMenu, MENU_ACTIONS_ALL);
		g_VoteMenu.SetTitle("Vote Nextmap");
		g_VoteMenu.VoteResultCallback = Handler_MapVoteFinished;
	}

	/* Call OnMapVoteStarted() Forward */
	Call_StartForward(g_MapVoteStartedForward);
	Call_Finish();
	
	/**
	 * TODO: Make a proper decision on when to clear the nominations list.
	 * Currently it clears when used, and stays if an external list is provided.
	 * Is this the right thing to do? External lists will probably come from places
	 * like sm_mapvote from the adminmenu in the future.
	 */
	 
	char map[PLATFORM_MAX_PATH];
	
	/* No input given - User our internal nominations and maplist */
	if (inputlist == null)
	{
		int nominateCount = g_NominateList.Length;
		int voteSize = g_ConVars[mapvote_include].IntValue;
		
		// New in 1.5.1 to fix missing extend vote
		if (g_NativeVotes)
		{
			if (voteSize > NativeVotes_GetMaxItems())
			{
				voteSize = NativeVotes_GetMaxItems();
			}
			
			if (g_ConVars[mapvote_extend].IntValue && g_Extends < g_ConVars[mapvote_extend].IntValue)
			{
				voteSize--;
			}
		}
		
		/* Smaller of the two - It should be impossible for nominations to exceed the size though (cvar changed mid-map?) */
		int nominationsToAdd = nominateCount >= voteSize ? voteSize : nominateCount;
		
		for (int i = 0; i < nominationsToAdd; i++)
		{
			char displayName[PLATFORM_MAX_PATH];
			g_NominateList.GetString(i, map, sizeof(map));
			GetMapDisplayName(map, displayName, sizeof(displayName));
			
			if (g_NativeVotes)
			{
				g_VoteNative.AddItem(map, displayName);
			}
			else
			{
				g_VoteMenu.AddItem(map, displayName);
			}
			
			RemoveStringFromArray(g_NextMapList, map);
			
			/* Notify Nominations that this map is now free */
			Call_StartForward(g_NominationsResetForward);
			Call_PushString(map);
			Call_PushCell(g_NominateOwners.Get(i));
			Call_Finish();
		}
		
		/* Clear out the rest of the nominations array */
		for (int i = nominationsToAdd; i < nominateCount; i++)
		{
			g_NominateList.GetString(i, map, sizeof(map));
			/* These maps shouldn't be excluded from the vote as they weren't really nominated at all */
			
			/* Notify Nominations that this map is now free */
			Call_StartForward(g_NominationsResetForward);
			Call_PushString(map);
			Call_PushCell(g_NominateOwners.Get(i));
			Call_Finish();			
		}
		
		/* There should currently be 'nominationsToAdd' unique maps in the vote */
		
		int i = nominationsToAdd;
		int count = 0;
		int availableMaps = g_NextMapList.Length;
		
		while (i < voteSize)
		{
			if (count >= availableMaps)
			{
				//Run out of maps, this will have to do.
				break;
			}
			
			g_NextMapList.GetString(count, map, sizeof(map));
			count++;
			
			/* Insert the map and increment our count */
			char displayName[PLATFORM_MAX_PATH];
			GetMapDisplayName(map, displayName, sizeof(displayName));
			if (g_NativeVotes)
			{
				g_VoteNative.AddItem(map, displayName);
			}
			else
			{
				g_VoteMenu.AddItem(map, displayName);
			}
			i++;
		}
		
		/* Wipe out our nominations list - Nominations have already been informed of this */
		g_NominateOwners.Clear();
		g_NominateList.Clear();
	}
	else //We were given a list of maps to start the vote with
	{
		int size = inputlist.Length;
		
		for (int i = 0; i < size; i++)
		{
			inputlist.GetString(i, map, sizeof(map));
			
			if (IsMapValid(map))
			{
				char displayName[PLATFORM_MAX_PATH];
				GetMapDisplayName(map, displayName, sizeof(displayName));
				if (g_NativeVotes)
				{
					g_VoteNative.AddItem(map, displayName);
				}
				else
				{
					g_VoteMenu.AddItem(map, displayName);
				}
			}	
		}
	}
	
	/* Do we add any special items? */
	if ((when == MapChange_Instant || when == MapChange_RoundEnd) && g_ConVars[mapvote_dontchange].BoolValue)
	{
		if (g_NativeVotes)
		{
			g_VoteNative.AddItem(VOTE_DONTCHANGE, "Don't Change");
		}
		else
		{
			g_VoteMenu.AddItem(VOTE_DONTCHANGE, "Don't Change");
		}
	}
	else if (g_ConVars[mapvote_extend].BoolValue && g_Extends < g_ConVars[mapvote_extend].IntValue)
	{
		if (g_NativeVotes)
		{
			g_VoteNative.AddItem(VOTE_EXTEND, "Extend Map");
		}
		else
		{
			g_VoteMenu.AddItem(VOTE_EXTEND, "Extend Map");
		}
	}
	
	/* There are no maps we could vote for. Don't show anything. */
	if (g_NativeVotes && g_VoteNative.ItemCount == 0)
	{
		g_HasVoteStarted = false;
		g_VoteNative.Close();
		return;
	}
	else if (!g_NativeVotes && g_VoteMenu.ItemCount == 0)
	{
		g_HasVoteStarted = false;
		delete g_VoteMenu;
		return;
	}
	
	int voteDuration = g_ConVars[mapvote_voteduration].IntValue;

	if (g_NativeVotes)
	{
		g_VoteNative.DisplayVoteToAll(voteDuration);
	}
	else
	{
		g_VoteMenu.ExitButton = false;
		g_VoteMenu.DisplayVoteToAll(voteDuration);
	}

	LogAction(-1, -1, "Voting for next map has started.");
	CPrintToChatAll("[{lightgreen}MapChooser\x01] %t", "Nextmap Voting Started");
}

public void Handler_NV_VoteFinishedGeneric(NativeVote menu, int num_votes,  int num_clients, const int[] client_indexes, const int[] client_votes, int num_items, const int[] item_indexes, const int[] item_votes)
{
	int[][] client_info = new int[num_clients][2];
	int[][] item_info = new int[num_items][2];
	
	NativeVotes_FixResults(num_clients, client_indexes, client_votes, num_items, item_indexes, item_votes, client_info, item_info);
	
	char map[PLATFORM_MAX_PATH];
	char displayName[PLATFORM_MAX_PATH];
	menu.GetItem(item_indexes[0], map, sizeof(map), displayName, sizeof(displayName));
	
	Handler_VoteFinishedGenericShared(map, displayName, num_votes, num_clients, client_info, num_items, item_info, true);
}

public void Handler_VoteFinishedGeneric(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	char map[PLATFORM_MAX_PATH];
	char displayName[PLATFORM_MAX_PATH];
	menu.GetItem(item_info[0][VOTEINFO_ITEM_INDEX], map, sizeof(map), _, displayName, sizeof(displayName));
	
	Handler_VoteFinishedGenericShared(map, displayName, num_votes, num_clients, client_info, num_items, item_info, false);
}

public void Handler_VoteFinishedGenericShared(const char[] map, const char[] displayName, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info, bool isNativeVotes)
{
	if (strcmp(map, VOTE_EXTEND, false) == 0)
	{
		g_Extends++;
		
		int time;
		if (GetMapTimeLimit(time))
		{
			if (time > 0)
			{
				ExtendMapTimeLimit(g_ConVars[extendmap_timestep].IntValue * 60);						
			}
		}
		
		if (g_ConVars[mp_winlimit])
		{
			int winlimit = g_ConVars[mp_winlimit].IntValue;
			if (winlimit)
			{
				g_ConVars[mp_winlimit].IntValue = winlimit + g_ConVars[extendmap_roundstep].IntValue;
			}					
		}
		
		if (g_ConVars[mp_maxrounds])
		{
			int maxrounds = g_ConVars[mp_maxrounds].IntValue;
			if (maxrounds)
			{
				g_ConVars[mp_maxrounds].IntValue = maxrounds + g_ConVars[extendmap_roundstep].IntValue;
			}
		}
		
		if (g_ConVars[mp_fraglimit])
		{
			int fraglimit = g_ConVars[mp_fraglimit].IntValue;
			if (fraglimit)
			{
				g_ConVars[mp_fraglimit].IntValue = fraglimit + g_ConVars[extendmap_fragstep].IntValue;
			}
		}

		CPrintToChatAll("[{lightgreen}MapChooser\x01] %t", "Current Map Extended", RoundToFloor(float(item_info[0][VOTEINFO_ITEM_VOTES])/float(num_votes)*100), num_votes);
		LogAction(-1, -1, "Voting for next map has finished. The current map has been extended.");
		
		if (isNativeVotes)
		{
			g_VoteNative.DisplayPassEx(NativeVotesPass_Extend);
		}
		
		// We extended, so we'll have to vote again.
		g_HasVoteStarted = false;
		CreateNextVote();
		SetupTimeleftTimer();
		
	}
	else if (strcmp(map, VOTE_DONTCHANGE, false) == 0)
	{
		CPrintToChatAll("[{lightgreen}MapChooser\x01] %t", "Current Map Stays", RoundToFloor(float(item_info[0][VOTEINFO_ITEM_VOTES])/float(num_votes)*100), num_votes);
		LogAction(-1, -1, "Voting for next map has finished. 'No Change' was the winner");
		
		if (isNativeVotes)
		{
			g_VoteNative.DisplayPassEx(NativeVotesPass_Extend);
		}
		
		g_HasVoteStarted = false;
		CreateNextVote();
		SetupTimeleftTimer();
	}
	else
	{
		if (g_ChangeTime == MapChange_MapEnd)
		{
			SetNextMap(map);
		}
		else if (g_ChangeTime == MapChange_Instant)
		{
			DataPack data;
			CreateDataTimer(2.0, Timer_ChangeMap, data);
			data.WriteString(map);
			g_ChangeMapInProgress = false;
		}
		else // MapChange_RoundEnd
		{
			SetNextMap(map);
			g_ChangeMapAtRoundEnd = true;
		}
		
		g_HasVoteStarted = false;
		g_MapVoteCompleted = true;
		
		if (isNativeVotes)
		{
			g_VoteNative.DisplayPass(displayName);
		}
		
		Format(displayName, sizeof(displayName), "\x05%s\x01", displayName);
		CPrintToChatAll("[{lightgreen}MapChooser\x01] %t", "Nextmap Voting Finished", displayName, RoundToFloor(float(item_info[0][VOTEINFO_ITEM_VOTES])/float(num_votes)*100), num_votes);
		LogAction(-1, -1, "Voting for next map has finished. Nextmap: %s.", map);
	}	
}

public void Handler_NV_MapVoteFinished(NativeVote menu, int num_votes, int num_clients, const int[] client_indexes, const int[] client_votes, int num_items, const int[] item_indexes, const int[] item_votes)
{
	if (g_ConVars[mapvote_runoff].BoolValue && num_items > 1)
	{
		float winningvotes = float(item_votes[0]);
		float required = num_votes * (g_ConVars[mapvote_runoffpercent].FloatValue / 100.0);
		
		if (winningvotes < required)
		{
			//Added in 1.5.1
			menu.DisplayFail(NativeVotesFail_NotEnoughVotes);
			
			/* Insufficient Winning margin - Lets do a runoff */

			char map1[PLATFORM_MAX_PATH];
			char map2[PLATFORM_MAX_PATH];
			char info1[PLATFORM_MAX_PATH];
			char info2[PLATFORM_MAX_PATH];
			
			DataPack data;
			
			menu.GetItem(item_indexes[0], map1, sizeof(map1), info1, sizeof(info1));
			menu.GetItem(item_indexes[1], map2, sizeof(map2), info2, sizeof(info2));
			
			CreateDataTimer(3.0, Timer_NV_Runoff, data, TIMER_FLAG_NO_MAPCHANGE);
			
			data.WriteString(map1);
			data.WriteString(info1);
			data.WriteString(map2);
			data.WriteString(info2);
			
			data.Reset();
			
			/* Notify */
			float map1percent = float(item_votes[0])/ float(num_votes) * 100;
			float map2percent = float(item_votes[1])/ float(num_votes) * 100;
			
			
			CPrintToChatAll("[{lightgreen}MapChooser\x01] %t", "Starting Runoff", g_ConVars[mapvote_runoffpercent].FloatValue, info1, map1percent, info2, map2percent);
			LogMessage("Voting for next map was indecisive, beginning runoff vote");
					
			return;
		}
	}
	
	Handler_NV_VoteFinishedGeneric(menu, num_votes, num_clients, client_indexes, client_votes, num_items, item_indexes, item_votes);
}

// New in 1.5.1, used to fix runoff not working properly
public Action Timer_NV_Runoff(Handle timer, DataPack data)
{
	char map[PLATFORM_MAX_PATH], info[PLATFORM_MAX_PATH];
	
	g_VoteNative = new NativeVote(Handler_NV_MapVoteMenu, NativeVotesType_NextLevelMult, NATIVEVOTES_ACTIONS_DEFAULT | MenuAction_DisplayItem);
	g_VoteNative.VoteResultCallback = Handler_NV_VoteFinishedGeneric;
	
	data.ReadString(map, sizeof(map));
	data.ReadString(info, sizeof(info));
	g_VoteNative.AddItem(map, info);

	data.ReadString(map, sizeof(map));
	data.ReadString(info, sizeof(info));
	g_VoteNative.AddItem(map, info);

	int voteDuration = g_ConVars[mapvote_voteduration].IntValue;
	g_VoteNative.DisplayVoteToAll(voteDuration);
	
	return Plugin_Continue;
}

public void Handler_MapVoteFinished(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	if (g_ConVars[mapvote_runoff].BoolValue && num_items > 1)
	{
		float winningvotes = float(item_info[0][VOTEINFO_ITEM_VOTES]);
		float required = num_votes * (g_ConVars[mapvote_runoffpercent].FloatValue / 100.0);
		
		if (winningvotes < required)
		{
			/* Insufficient Winning margin - Lets do a runoff */
			g_VoteMenu = new Menu(Handler_MapVoteMenu, MENU_ACTIONS_ALL);
			g_VoteMenu.SetTitle("Runoff Vote Nextmap");
			g_VoteMenu.VoteResultCallback = Handler_VoteFinishedGeneric;

			char map[PLATFORM_MAX_PATH], info1[PLATFORM_MAX_PATH], info2[PLATFORM_MAX_PATH];
			
			menu.GetItem(item_info[0][VOTEINFO_ITEM_INDEX], map, sizeof(map), _, info1, sizeof(info1));
			g_VoteMenu.AddItem(map, info1);
			menu.GetItem(item_info[1][VOTEINFO_ITEM_INDEX], map, sizeof(map), _, info2, sizeof(info2));
			g_VoteMenu.AddItem(map, info2);
			
			int voteDuration = g_ConVars[mapvote_voteduration].IntValue;
			g_VoteMenu.ExitButton = false;
			g_VoteMenu.DisplayVoteToAll(voteDuration);
			
			/* Notify */
			float map1percent = float(item_info[0][VOTEINFO_ITEM_VOTES])/ float(num_votes) * 100;
			float map2percent = float(item_info[1][VOTEINFO_ITEM_VOTES])/ float(num_votes) * 100;
			
			CPrintToChatAll("[{lightgreen}MapChooser\x01] %t", "Starting Runoff", g_ConVars[mapvote_runoffpercent].FloatValue, info1, map1percent, info2, map2percent);
			LogMessage("Voting for next map was indecisive, beginning runoff vote");
					
			return;
		}
	}
	
	Handler_VoteFinishedGeneric(menu, num_votes, num_clients, client_info, num_items, item_info);
}

public int Handler_MapVoteMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			g_VoteMenu = null;
			delete menu;
		}
		
		case MenuAction_Display:
		{
	 		char buffer[255];
			Format(buffer, sizeof(buffer), "%t", "Vote Nextmap", param1);

			Panel panel = view_as<Panel>(param2);
			panel.SetTitle(buffer);
		}		
		
		case MenuAction_DisplayItem:
		{
			if (menu.ItemCount - 1 == param2)
			{
				char map[PLATFORM_MAX_PATH], buffer[255];
				menu.GetItem(param2, map, sizeof(map));
				if (strcmp(map, VOTE_EXTEND, false) == 0)
				{
					Format(buffer, sizeof(buffer), "%t", "Extend Map", param1);
					return RedrawMenuItem(buffer);
				}
				else if (strcmp(map, VOTE_DONTCHANGE, false) == 0)
				{
					Format(buffer, sizeof(buffer), "%t", "Dont Change", param1);
					return RedrawMenuItem(buffer);					
				}
			}
		}		
	
		case MenuAction_VoteCancel:
		{
			// If we receive 0 votes, pick at random.
			if (param1 == VoteCancel_NoVotes && g_ConVars[mapvote_novote].BoolValue)
			{
				int count = menu.ItemCount;
				char map[PLATFORM_MAX_PATH];
				menu.GetItem(0, map, sizeof(map));
				
				// Make sure the first map in the menu isn't one of the special items.
				// This would mean there are no real maps in the menu, because the special items are added after all maps. Don't do anything if that's the case.
				if (strcmp(map, VOTE_EXTEND, false) != 0 && strcmp(map, VOTE_DONTCHANGE, false) != 0)
				{
					// Get a random map from the list.
					int item = GetRandomInt(0, count - 1);
					menu.GetItem(item, map, sizeof(map));
					
					// Make sure it's not one of the special items.
					while (strcmp(map, VOTE_EXTEND, false) == 0 || strcmp(map, VOTE_DONTCHANGE, false) == 0)
					{
						item = GetRandomInt(0, count - 1);
						menu.GetItem(item, map, sizeof(map));
					}
					
					SetNextMap(map);
					g_MapVoteCompleted = true;
				}
			}
			
			g_HasVoteStarted = false;
		}
	}
	
	return 0;
}

public int Handler_NV_MapVoteMenu(NativeVote menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			g_VoteMenu = null;
			menu.Close();
		}
		
		case MenuAction_DisplayItem:
		{
			if (menu.ItemCount - 1 == param2)
			{
				char map[PLATFORM_MAX_PATH], buffer[255];
				menu.GetItem(param2, map, sizeof(map));
				if (strcmp(map, VOTE_EXTEND, false) == 0)
				{
					Format(buffer, sizeof(buffer), "%t", "Extend Map", param1);
					return view_as<int>(NativeVotes_RedrawVoteItem(buffer));
				}
				else if (strcmp(map, VOTE_DONTCHANGE, false) == 0)
				{
					Format(buffer, sizeof(buffer), "%t", "Dont Change", param1);
					return view_as<int>(NativeVotes_RedrawVoteItem(buffer));
				}
			}
		}		
	
		case MenuAction_VoteCancel:
		{
			// If we receive 0 votes, pick at random.
			if (param1 == VoteCancel_NoVotes && g_ConVars[mapvote_novote].BoolValue)
			{
				int count = menu.ItemCount;
				char map[PLATFORM_MAX_PATH], displayName[PLATFORM_MAX_PATH];
				menu.GetItem(0, map, sizeof(map));
				
				// Make sure the first map in the menu isn't one of the special items.
				// This would mean there are no real maps in the menu, because the special items are added after all maps. Don't do anything if that's the case.
				if (strcmp(map, VOTE_EXTEND, false) != 0 && strcmp(map, VOTE_DONTCHANGE, false) != 0)
				{
					// Get a random map from the list.
					int item = GetRandomInt(0, count - 1);
					menu.GetItem(item, map, sizeof(map), displayName, sizeof(displayName));
					
					// Make sure it's not one of the special items.
					while (strcmp(map, VOTE_EXTEND, false) == 0 || strcmp(map, VOTE_DONTCHANGE, false) == 0)
					{
						item = GetRandomInt(0, count - 1);
						menu.GetItem(item, map, sizeof(map), displayName, sizeof(displayName));
					}
					
					SetNextMap(map);
					g_MapVoteCompleted = true;
					menu.DisplayPass(displayName);
				}
			}
			else if (param1 == VoteCancel_NoVotes)
			{
				// We didn't have enough votes. Display the note enough votes fail message.
				menu.DisplayFail(NativeVotesFail_NotEnoughVotes);
			}
			else
			{
				// We were actually cancelled. Display the generic fail message
				menu.DisplayFail(NativeVotesFail_Generic);
			}
			
			g_HasVoteStarted = false;
		}
	}
	
	return 0;
}

public Action Timer_ChangeMap(Handle hTimer, DataPack dp)
{
	g_ChangeMapInProgress = false;
	
	char map[PLATFORM_MAX_PATH];
	
	if (dp == null)
	{
		if (!GetNextMap(map, sizeof(map)))
		{
			//No passed map and no set nextmap. fail!
			return Plugin_Stop;	
		}
	}
	else
	{
		dp.Reset();
		dp.ReadString(map, sizeof(map));		
	}
	
	ForceChangeLevel(map, "Map Vote");
	
	return Plugin_Stop;
}

bool RemoveStringFromArray(ArrayList array, char[] str)
{
	int index = array.FindString(str);
	if (index != -1)
	{
		array.Erase(index);
		return true;
	}
	
	return false;
}

void CreateNextVote()
{
	g_NextMapList.Clear();
	
	char map[PLATFORM_MAX_PATH];
	// tempMaps is a resolved map list
	ArrayList tempMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	
	for (int i = 0; i < g_MapList.Length; i++)
	{
		g_MapList.GetString(i, map, sizeof(map));
		if (FindMap(map, map, sizeof(map)) != FindMap_NotFound)
		{
			tempMaps.PushString(map);
		}
	}
	
	//GetCurrentMap always returns a resolved map
	GetCurrentMap(map, sizeof(map));
	RemoveStringFromArray(tempMaps, map);
	
	if (g_ConVars[mapvote_exclude].IntValue && tempMaps.Length > g_ConVars[mapvote_exclude].IntValue)
	{
		for (int i = 0; i < g_OldMapList.Length; i++)
		{
			g_OldMapList.GetString(i, map, sizeof(map));
			RemoveStringFromArray(tempMaps, map);
		}
	}

	int limit = (g_ConVars[mapvote_include].IntValue < tempMaps.Length ? g_ConVars[mapvote_include].IntValue : tempMaps.Length);
	for (int i = 0; i < limit; i++)
	{
		int b = GetRandomInt(0, tempMaps.Length - 1);
		tempMaps.GetString(b, map, sizeof(map));		
		g_NextMapList.PushString(map);
		tempMaps.Erase(b);
	}
	
	delete tempMaps;
}

bool CanVoteStart()
{
	return !(g_WaitingForVote || g_HasVoteStarted);
}

NominateResult InternalNominateMap(char[] map, bool force, int owner)
{
	if (!IsMapValid(map))
	{
		return Nominate_InvalidMap;
	}
	
	/* Map already in the vote */
	if (g_NominateList.FindString(map) != -1)
	{
		return Nominate_AlreadyInVote;	
	}
	
	int index;

	/* Look to replace an existing nomination by this client - Nominations made with owner = 0 aren't replaced */
	if (owner && ((index = g_NominateOwners.FindValue(owner)) != -1))
	{
		char oldmap[PLATFORM_MAX_PATH];
		g_NominateList.GetString(index, oldmap, sizeof(oldmap));
		Call_StartForward(g_NominationsResetForward);
		Call_PushString(oldmap);
		Call_PushCell(owner);
		Call_Finish();
		
		g_NominateList.SetString(index, map);
		return Nominate_Replaced;
	}
	
	/* Too many nominated maps. */
	int maxIncludes = 0;
	if (g_NativeVotes)
	{
		maxIncludes = NativeVotes_GetMaxItems();
		
		if (g_ConVars[mapvote_include].IntValue < maxIncludes)
		{
			maxIncludes = g_ConVars[mapvote_include].IntValue;
		}
		
		if (g_ConVars[mapvote_extend].BoolValue && g_Extends < g_ConVars[mapvote_extend].IntValue)
		{
			maxIncludes--;
		}
	}
	else
	{
		maxIncludes = g_ConVars[mapvote_include].IntValue;
	}
	
	if (g_NominateList.Length >= maxIncludes && !force)
	{
		return Nominate_VoteFull;
	}
	
	g_NominateList.PushString(map);
	g_NominateOwners.Push(owner);
	
	while (g_NominateList.Length > g_ConVars[mapvote_include].IntValue)
	{
		char oldmap[PLATFORM_MAX_PATH];
		g_NominateList.GetString(0, oldmap, sizeof(oldmap));
		Call_StartForward(g_NominationsResetForward);
		Call_PushString(oldmap);
		Call_PushCell(g_NominateOwners.Get(0));
		Call_Finish();
		
		g_NominateList.Erase(0);
		g_NominateOwners.Erase(0);
	}
	
	return Nominate_Added;
}

/* Add natives to allow nominate and initiate vote to be call */

/* native NominateResult NominateMap(const char[] map, bool force, int owner); */
public int Native_NominateMap(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
	
	if (len <= 0)
	{
	  return false;
	}
	
	char[] map = new char[len+1];
	GetNativeString(1, map, len+1);
	
	return view_as<int>(InternalNominateMap(map, GetNativeCell(2), GetNativeCell(3)));
}

bool InternalRemoveNominationByMap(char[] map)
{	
	for (int i = 0; i < g_NominateList.Length; i++)
	{
		char oldmap[PLATFORM_MAX_PATH];
		g_NominateList.GetString(i, oldmap, sizeof(oldmap));

		if(strcmp(map, oldmap, false) == 0)
		{
			Call_StartForward(g_NominationsResetForward);
			Call_PushString(oldmap);
			Call_PushCell(g_NominateOwners.Get(i));
			Call_Finish();

			g_NominateList.Erase(i);
			g_NominateOwners.Erase(i);

			return true;
		}
	}
	
	return false;
}

/* native bool RemoveNominationByMap(const char[] map); */
public int Native_RemoveNominationByMap(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
	
	if (len <= 0)
	{
	  return false;
	}
	
	char[] map = new char[len+1];
	GetNativeString(1, map, len+1);
	
	return InternalRemoveNominationByMap(map);
}

bool InternalRemoveNominationByOwner(int owner)
{	
	int index;

	if (owner && ((index = g_NominateOwners.FindValue(owner)) != -1))
	{
		char oldmap[PLATFORM_MAX_PATH];
		g_NominateList.GetString(index, oldmap, sizeof(oldmap));

		Call_StartForward(g_NominationsResetForward);
		Call_PushString(oldmap);
		Call_PushCell(owner);
		Call_Finish();

		g_NominateList.Erase(index);
		g_NominateOwners.Erase(index);

		return true;
	}
	
	return false;
}

/* native bool RemoveNominationByOwner(int owner); */
public int Native_RemoveNominationByOwner(Handle plugin, int numParams)
{	
	return InternalRemoveNominationByOwner(GetNativeCell(1));
}

/* native void InitiateMapChooserVote(MapChange when, ArrayList inputarray=null); */
public int Native_InitiateVote(Handle plugin, int numParams)
{
	MapChange when = view_as<MapChange>(GetNativeCell(1));
	ArrayList inputarray = view_as<ArrayList>(GetNativeCell(2));
	
	LogAction(-1, -1, "Starting map vote because outside request");
	InitiateVote(when, inputarray);

	return 0;
}

/* native bool CanMapChooserStartVote(); */
public int Native_CanVoteStart(Handle plugin, int numParams)
{
	return CanVoteStart();	
}

/* native bool HasEndOfMapVoteFinished(); */
public int Native_CheckVoteDone(Handle plugin, int numParams)
{
	return g_MapVoteCompleted;
}

/* native bool EndOfMapVoteEnabled(); */
public int Native_EndOfMapVoteEnabled(Handle plugin, int numParams)
{
	return g_ConVars[mapvote_endvote].BoolValue;
}

/* native void GetExcludeMapList(ArrayList array); */
public int Native_GetExcludeMapList(Handle plugin, int numParams)
{
	ArrayList array = view_as<ArrayList>(GetNativeCell(1));
	
	if (array == null)
	{
		return 0;	
	}
	int size = g_OldMapList.Length;
	char map[PLATFORM_MAX_PATH];
	
	for (int i = 0; i < size; i++)
	{
		g_OldMapList.GetString(i, map, sizeof(map));
		array.PushString(map);	
	}
	
	return 0;
}

/* native void GetNominatedMapList(ArrayList maparray, ArrayList ownerarray = null); */
public int Native_GetNominatedMapList(Handle plugin, int numParams)
{
	ArrayList maparray = view_as<ArrayList>(GetNativeCell(1));
	ArrayList ownerarray = view_as<ArrayList>(GetNativeCell(2));
	
	if (maparray == null)
		return 0;

	char map[PLATFORM_MAX_PATH];

	for (int i = 0; i < g_NominateList.Length; i++)
	{
		g_NominateList.GetString(i, map, sizeof(map));
		maparray.PushString(map);

		// If the optional parameter for an owner list was passed, then we need to fill that out as well
		if(ownerarray != null)
		{
			int index = g_NominateOwners.Get(i);
			ownerarray.Push(index);
		}
	}

	return 0;
}

void PopulateMapList()
{
	char mapcycleFile[PLATFORM_MAX_PATH];
	g_ConVars[mapcyclefile].GetString(mapcycleFile, sizeof(mapcycleFile));
	Format(mapcycleFile, sizeof(mapcycleFile), "cfg/%s", mapcycleFile);

	File file = OpenFile(mapcycleFile, "w");
	if (file == null)
	{
		return;
	}

	char excludePattern[512];
	g_ConVars[mapcycle_exclude].GetString(excludePattern, sizeof(excludePattern));
	Regex regex = new Regex(excludePattern);

	DirectoryListing dir = OpenDirectory("maps");
	if (dir == null)
	{
		delete regex;
		CloseHandle(file);
		return;
	}

	char mapName[PLATFORM_MAX_PATH];
	FileType type;
	int len;

	file.WriteLine("// Generated with NativeVotes MapChooser.");
	file.WriteLine("// https://github.com/Heapons/sourcemod-nativevotes-updated");

	// FastDL
	while (dir.GetNext(mapName, sizeof(mapName), type))
	{
		if (type != FileType_File)
			continue;

		len = strlen(mapName);
		if (len <= 4 || !StrEqual(mapName[len-4], ".bsp", false))
			continue;

		mapName[len-4] = '\0';

		if (regex.Match(mapName) >= 1)
			continue;

		file.WriteLine("%s", mapName);
	}
	delete dir;
	delete regex;

	// Workshop
	char workshopCollection[64];
	g_ConVars[workshop_map_collection].GetString(workshopCollection, sizeof(workshopCollection));
	if (g_RestInPawn && workshopCollection[0] != '\0')
	{
        HTTPRequest req = new HTTPRequest("https://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/");
        req.AppendFormParam("collectioncount", "1");
		req.AppendFormParam("publishedfileids[0]", workshopCollection);
        req.PostForm(HTTPResponse_GetCollectionDetails, file);
	}
	else
	{
		CloseHandle(file);
	}
}

void HTTPResponse_GetCollectionDetails(HTTPResponse response, File file)
{
	if (response.Status != HTTPStatus_OK || response.Data == null)
	{
		CloseHandle(file);
		return;
	}

	JSONObject root = view_as<JSONObject>(response.Data);
	if (root == null)
	{
		CloseHandle(file);
		return;
	}

	JSONObject responseObj = view_as<JSONObject>(root.Get("response"));
	if (responseObj == null)
	{
		delete root;
		CloseHandle(file);
		return;
	}

	JSONArray collectionDetailsArray = view_as<JSONArray>(responseObj.Get("collectiondetails"));
	if (collectionDetailsArray == null || collectionDetailsArray.Length <= 0)
	{
		delete responseObj;
		delete root;
		CloseHandle(file);
		return;
	}

	JSONObject collectionDetails = view_as<JSONObject>(collectionDetailsArray.Get(0));
	if (collectionDetails == null)
	{
		delete collectionDetailsArray;
		delete responseObj;
		delete root;
		CloseHandle(file);
		return;
	}

	JSONArray children = view_as<JSONArray>(collectionDetails.Get("children"));
	if (children != null)
	{
		ConVar sig_etc_workshop_map_fix = FindConVar("sig_etc_workshop_map_fix");
		bool workshopMapFix = sig_etc_workshop_map_fix != null ? sig_etc_workshop_map_fix.BoolValue : false;
		for (int i = 0; i < children.Length; i++)
		{
			JSONObject child = view_as<JSONObject>(children.Get(i));
			if (child == null)
			{
				continue;
			}

			if (child.GetInt("filetype") == 0) // Map
			{
				char publishedfileid[64];
				if (child.GetString("publishedfileid", publishedfileid, sizeof(publishedfileid)))
				{
					if (workshopMapFix)
					{
						ServerCommand("tf_workshop_map_sync %s", publishedfileid);
					}
					else
					{
						file.WriteLine("workshop/%s", publishedfileid);
					}
				}
			}
			delete child;
		}
		delete children;
	}
	delete collectionDetails;
	delete collectionDetailsArray;
	delete responseObj;
	delete root;
	CloseHandle(file);
}

void CleanupWorkshopMaps()
{
	KeyValues kv = new KeyValues("GameInfo");
	int appid;
	if (kv.ImportFromFile("gameinfo.txt") && kv.JumpToKey("FileSystem"))
	{
		appid = kv.GetNum("SteamAppId");
	}
	delete kv;

	char workshopDir[PLATFORM_MAX_PATH];
	Format(workshopDir, sizeof(workshopDir), "../steamapps/workshop/content/%d", appid);

	DirectoryListing dir = OpenDirectory(workshopDir);
	if (dir != null)
	{
		char ugcid[PLATFORM_MAX_PATH];
		FileType type;
		char path[PLATFORM_MAX_PATH];

		while (dir.GetNext(ugcid, sizeof(ugcid), type))
		{
			if (type != FileType_Directory)
				continue;

			Format(path, sizeof(path), "%s/%s", workshopDir, ugcid);
			DirectoryListing ugcDir = OpenDirectory(path);
			if (ugcDir != null)
			{
				char file[PLATFORM_MAX_PATH];
				FileType fileType;
				char filePath[PLATFORM_MAX_PATH];
				while (ugcDir.GetNext(file, sizeof(file), fileType))
				{
					if (fileType == FileType_File)
					{
						Format(filePath, sizeof(filePath), "%s/%s", path, file);
						DeleteFile(filePath);
					}
				}
				delete ugcDir;
			}
			RemoveDir(path);
		}
		delete dir;
	}
	RemoveDir(workshopDir);
}