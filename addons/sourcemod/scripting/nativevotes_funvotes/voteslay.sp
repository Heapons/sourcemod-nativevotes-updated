/**
 * vim: set ts=4 :
 * =============================================================================
 * NativeVotes Fun Votes Plugin
 * Provides voteslay functionality
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

void DisplayVoteSlayMenu(int client, int target, char name[MAX_NAME_LENGTH])
{
	if (!IsPlayerAlive(target))
	{
		CReplyToCommand(client, "[\x04NativeVotes\x01] %t", "Cannot be performed on dead", name);
		return;
	}
	
	g_voteClient[VOTE_CLIENTID] = target;

	char playerName[MAX_NAME_LENGTH];
	GetPlayerName(target, playerName, sizeof(playerName));

	GetClientName(target, g_voteInfo[VOTE_NAME], sizeof(g_voteInfo[]));

	LogAction(client, target, "\"%L\" initiated a slay vote against %N", client, target);
	CShowActivity2(client, "[\x04NativeVotes\x01] ", "%t", "Initiated Vote Slay", playerName);
	
	g_voteType = slay;
	
	if (g_NativeVotes)
	{
		Handle hVoteMenu = NativeVotes_Create(Handler_NativeVoteCallback, NativeVotesType_Custom_YesNo, view_as<MenuAction>(MENU_ACTIONS_ALL));
		NativeVotes_SetTitle(hVoteMenu, "Voteslay Player");
		NativeVotes_SetTarget(hVoteMenu, target);
		NativeVotes_DisplayToAll(hVoteMenu, 20);
	}
	else
	{
		Handle hVoteMenu = CreateMenu(Handler_VoteCallback, view_as<MenuAction>(MENU_ACTIONS_ALL));
		SetMenuTitle(hVoteMenu, "Voteslay Player");
		AddMenuItem(hVoteMenu, VOTE_YES, "Yes");
		AddMenuItem(hVoteMenu, VOTE_NO, "No");
		SetMenuExitButton(hVoteMenu, false);
		VoteMenuToAll(hVoteMenu, 20);
	}
}

void DisplaySlayTargetMenu(int client)
{
	Handle menu = CreateMenu(MenuHandler_Slay);
	char title[100];
	Format(title, sizeof(title), "%T:", "Slay vote", client);
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	AddTargetsToMenu(menu, client, true, true);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public void AdminMenu_VoteSlay(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption:
		{
			Format(buffer, maxlength, "%T", "Slay vote", param);
		}
		case TopMenuAction_SelectOption:
		{
			DisplaySlayTargetMenu(param);
		}
		case TopMenuAction_DrawOption:
		{
			/* disable this option if a vote is already running */
			buffer[0] = !Internal_IsNewVoteAllowed() ? ITEMDRAW_IGNORE : ITEMDRAW_DEFAULT;
		}
	}
}

public int MenuHandler_Slay(Handle menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack && hTopMenu != INVALID_HANDLE)
			{
				DisplayTopMenu(hTopMenu, param1, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_Select:
		{
			char info[32], name[32];
			int userid, target;
			GetMenuItem(menu, param2, info, sizeof(info), _, name, sizeof(name));
			userid = StringToInt(info);
			
			if ((target = GetClientOfUserId(userid)) == 0)
			{
				CPrintToChat(param1, "[SM] %t", "Player no longer available");
			}
			else if (!CanUserTarget(param1, target))
			{
				CPrintToChat(param1, "[SM] %t", "Unable to target");
			}
			else if (!IsPlayerAlive(target))
			{
				CPrintToChat(param1, "[SM] %t", "Player has since died");
			}
			else
			{
				DisplayVoteSlayMenu(param1, target, name);
			}
		}
	}

	return Plugin_Continue;
}

public Action Command_VoteSlay(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "[\x04NativeVotes\x01] Usage: sm_voteslay <player>");
		return Plugin_Handled;
	}
	
	if (Internal_IsVoteInProgress())
	{
		CReplyToCommand(client, "[\x04NativeVotes\x01] %t", "Vote in Progress");
		return Plugin_Handled;
	}
	
	if (!TestVoteDelay(client))
	{
		return Plugin_Handled;
	}
	
	char text[256], arg[64];
	GetCmdArgString(text, sizeof(text));
	
	BreakString(text, arg, sizeof(arg));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_MULTI,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	DisplayVoteSlayMenu(client, target_list[0], arg);
	
	return Plugin_Handled;
}