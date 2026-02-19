/**
 * vim: set ts=4 :
 * =============================================================================
 * NativeVotes Basic Votes Plugin
 * Provides map functionality
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

Handle g_MapList;
int g_mapCount;

Handle g_SelectedMaps;
bool g_VoteMapInUse;

void DisplayVoteMapMenu(int client, int mapCount, char maps[5][PLATFORM_MAX_PATH])
{
	LogAction(client, -1, "\"%L\" initiated a map vote.", client);
	CShowActivity2(client, PLUGIN_PREFIX ... " %t", "Initiated Vote Map");
	
	g_VoteType = map;

	char resolvedMaps[5][PLATFORM_MAX_PATH];
	char displayNames[5][PLATFORM_MAX_PATH];
	for (int i = 0; i < mapCount; i++)
	{
		FindMap(maps[i], resolvedMaps[i], sizeof(resolvedMaps[]));
		GetMapDisplayName(resolvedMaps[i], displayNames[i], sizeof(displayNames[]));
	}

	if (g_NativeVotes && (mapCount == 1 || NativeVotes_IsVoteTypeSupported(NativeVotesType_NextLevelMult)) )
	{
		Handle voteMenu;
		if (mapCount == 1)
		{
			strcopy(g_VoteInfo[VOTE_NAME], sizeof(g_VoteInfo[]), displayNames[0]);
			
			voteMenu = NativeVotes_Create(Handler_NativeVoteCallback, NativeVotesType_ChgLevel, view_as<MenuAction>(MENU_ACTIONS_ALL));
			
			// No title, builtin type
			NativeVotes_SetDetails(voteMenu, displayNames[0]);
		}
		else
		{
			voteMenu = NativeVotes_Create(Handler_NativeVoteCallback, NativeVotesType_NextLevelMult, view_as<MenuAction>(MENU_ACTIONS_ALL));
			
			g_VoteInfo[VOTE_NAME][0] = '\0';
			
			// No title, builtin type
			for (int i = 0; i < mapCount; i++)
			{
				NativeVotes_AddItem(voteMenu, resolvedMaps[i], displayNames[i]);
			}
		}
		NativeVotes_DisplayToAll(voteMenu, g_ConVars[sv_vote_timer_duration].IntValue);
	}
	else
	{
		Handle voteMenu = CreateMenu(Handler_VoteCallback, MENU_ACTIONS_ALL);
		
		if (mapCount == 1)
		{
			strcopy(g_VoteInfo[VOTE_NAME], sizeof(g_VoteInfo[]), displayNames[0]);

			SetMenuTitle(voteMenu, "Change Map To");
			AddMenuItem(voteMenu, resolvedMaps[0], "Yes");
			AddMenuItem(voteMenu, VOTE_NO, "No");
		}
		else
		{
			g_VoteInfo[VOTE_NAME][0] = '\0';
			
			SetMenuTitle(voteMenu, "Map Vote");
			for (int i = 0; i < mapCount; i++)
			{
				AddMenuItem(voteMenu, resolvedMaps[i], displayNames[i]);
			}
		}
		SetMenuExitButton(voteMenu, false);
		VoteMenuToAll(voteMenu, g_ConVars[sv_vote_timer_duration].IntValue);
	}
}

void ResetMenu()
{
	g_VoteMapInUse = false;
	ClearArray(g_SelectedMaps);
}

void ConfirmVote(int client)
{
	Handle menu = CreateMenu(MenuHandler_Confirm);
	char title[100];
	
	Format(title, sizeof(title), "%T:", "Confirm Vote", client);
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	char itemtext[256];
	Format(itemtext, sizeof(itemtext), "%T", "Start the Vote", client);
	AddMenuItem(menu, "Confirm", itemtext);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_Confirm(Handle menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			CloseHandle(menu);
			g_VoteMapInUse = false;
		}
		case MenuAction_Cancel:
		{
			ResetMenu();
			if (param2 == MenuCancel_ExitBack && g_TopMenu != INVALID_HANDLE)
			{
				DisplayTopMenu(g_TopMenu, param1, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_Select:
		{
			char maps[5][64];
			int selectedmaps = GetArraySize(g_SelectedMaps);
			for (int i = 0; i < selectedmaps; i++)
			{
				GetArrayString(g_SelectedMaps, i, maps[i], sizeof(maps[]));
			}
			DisplayVoteMapMenu(param1, selectedmaps, maps);
			ResetMenu();
		}
	}

	return Plugin_Continue;
}

public int MenuHandler_Map(Handle menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack && g_TopMenu != INVALID_HANDLE)
			{
				ConfirmVote(param1);
			}
			else // no action was selected.
			{
				/* Re-enable the menu option */
				ResetMenu();
			}
		}
		case MenuAction_DrawItem:
		{
			char info[32], name[32];
			GetMenuItem(menu, param2, info, sizeof(info), _, name, sizeof(name));
			if (FindStringInArray(g_SelectedMaps, info) != -1)
			{
				return ITEMDRAW_IGNORE;
			}
			else
			{
				return ITEMDRAW_DEFAULT;
			}
		}
		case MenuAction_Select:
		{
			char info[32], name[32];
			GetMenuItem(menu, param2, info, sizeof(info), _, name, sizeof(name));
			PushArrayString(g_SelectedMaps, info);
			/* Redisplay the list */
			if (GetArraySize(g_SelectedMaps) < 5)
			{
				DisplayMenu(g_MapList, param1, MENU_TIME_FOREVER);
			}
			else
			{
				ConfirmVote(param1);
			}
		}
		case MenuAction_Display:
		{
			char title[128];
			Format(title, sizeof(title), "%T", "Please select a map", param1);
			SetPanelTitle(view_as<Handle>(param2), title);
		}
	}
	
	return Plugin_Continue;
}

public void AdminMenu_VoteMap(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption:
		{
			Format(buffer, maxlength, "%T", "Map vote", param);
		}
		case TopMenuAction_SelectOption:
		{
			if (!g_VoteMapInUse)
			{
				ResetMenu();
				g_VoteMapInUse = true;
				DisplayMenu(g_MapList, param, MENU_TIME_FOREVER);
			}
			else
			{
				CPrintToChat(param, PLUGIN_PREFIX ... " %t", "Map Vote In Use", param);
			}
		}
		case TopMenuAction_DrawOption:
		{
			/* disable this option if a vote is already running, theres no maps listed or someone else has already acessed this menu */
			buffer[0] = (!IsNewVoteAllowed() || g_mapCount < 1 || g_VoteMapInUse) ? ITEMDRAW_IGNORE : ITEMDRAW_DEFAULT;
		}
	}
}

public Action Command_Votemap(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, PLUGIN_PREFIX ... " Usage: sm_votemap <mapname> [mapname2] ... [mapname5]");
		return Plugin_Handled;
	}
	
	if (Internal_IsVoteInProgress())
	{
		CReplyToCommand(client, PLUGIN_PREFIX ... " %t", "Vote in Progress");
		return Plugin_Handled;
	}
	
	if (!TestVoteDelay(client) && !CheckCommandAccess(client, "sm_votemap", ADMFLAG_CHANGEMAP))
	{
		return Plugin_Handled;
	}
	
	char text[256];
	GetCmdArgString(text, sizeof(text));
	
	char maps[5][PLATFORM_MAX_PATH];
	int mapCount;
	int len, pos;
	
	while (pos != -1 && mapCount < 5)
	{
		pos = BreakString(text[len], maps[mapCount], sizeof(maps[]));
		
		if (!IsMapValid(maps[mapCount]))
		{
			CReplyToCommand(client, PLUGIN_PREFIX ... " %t", "Map was not found", maps[mapCount]);
			return Plugin_Handled;
		}

		mapCount++;
		
		if (pos != -1)
		{
			len += pos;
		}
	}

	DisplayVoteMapMenu(client, mapCount, maps);
	
	return Plugin_Handled;
}

Handle g_map_array = INVALID_HANDLE;
int g_map_serial = -1;

int LoadMapList(Handle menu)
{
	Handle map_array;
	if ((map_array = ReadMapList(g_map_array,
			g_map_serial,
			"sm_votemap menu",
			MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_NO_DEFAULT|MAPLIST_FLAG_MAPSFOLDER))
		!= INVALID_HANDLE)
	{
		g_map_array = map_array;
	}
	
	if (g_map_array == INVALID_HANDLE)
	{
		return 0;
	}
	
	RemoveAllMenuItems(menu);
	
	char map_name[PLATFORM_MAX_PATH];
	int map_count = GetArraySize(g_map_array);
	
	for (int i = 0; i < map_count; i++)
	{
		GetArrayString(g_map_array, i, map_name, sizeof(map_name));
		AddMenuItem(menu, map_name, map_name);
	}
	
	return map_count;
}
