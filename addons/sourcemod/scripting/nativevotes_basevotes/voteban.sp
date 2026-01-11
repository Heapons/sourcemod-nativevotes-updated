/**
 * vim: set ts=4 :
 * =============================================================================
 * NativeVotes Basic Votes Plugin
 * Provides ban functionality
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

void DisplayVoteBanMenu(int client, int target)
{
	g_voteClient[VOTE_CLIENTID] = target;
	g_voteClient[VOTE_USERID] = GetClientUserId(target);

	char playerName[MAX_NAME_LENGTH]; int r, g, b, a, color;
	GetEntityRenderColor(target, r, g, b, a);
	color = (r << 16) | (g << 8) | b;
	if (color != 0xFFFFFF) {
		Format(playerName, sizeof(playerName), "{#%06X}%N\x01", color, target);
	}
	else {
		Format(playerName, sizeof(playerName), "{teamcolor}%N\x01", target);
	}

	GetClientName(target, g_voteInfo[VOTE_NAME], sizeof(g_voteInfo[]));
	GetClientIP(target, g_voteInfo[VOTE_IP], sizeof(g_voteInfo[]));

	LogAction(client, target, "\"%L\" initiated a ban vote against %s", client, playerName);
	CShowActivity2(client, "[{lightgreen}NativeVotes\x01] ", "%t", "Initiated Vote Ban", playerName);

	g_voteType = ban;
	
	if (g_NativeVotes)
	{
		Handle voteMenu = NativeVotes_Create(Handler_NativeVoteCallback, NativeVotesType_Custom_YesNo, view_as<MenuAction>(MENU_ACTIONS_ALL));
		NativeVotes_SetTitle(voteMenu, "Voteban Player");
		NativeVotes_SetTarget(voteMenu, target); // Doesn't work for some reason(?)
		NativeVotes_DisplayToAll(voteMenu, 20);
	}
	else
	{
		Handle voteMenu = CreateMenu(Handler_VoteCallback, view_as<MenuAction>(MENU_ACTIONS_ALL));
		SetMenuTitle(voteMenu, "Voteban Player");
		AddMenuItem(voteMenu, VOTE_YES, "Yes");
		AddMenuItem(voteMenu, VOTE_NO, "No");
		SetMenuExitButton(voteMenu, false);
		VoteMenuToAll(voteMenu, 20);
	}
}

void DisplayBanTargetMenu(int client)
{
	Handle menu = CreateMenu(MenuHandler_Ban);
	char title[100];
	Format(title, sizeof(title), "%T:", "Ban vote", client);
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	AddTargetsToMenu(menu, client, false, false);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public void AdminMenu_VoteBan(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Ban vote", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayBanTargetMenu(param);
	}
	else if (action == TopMenuAction_DrawOption)
	{
		/* disable this option if a vote is already running */
		buffer[0] = Internal_IsNewVoteAllowed() ? ITEMDRAW_IGNORE : ITEMDRAW_DEFAULT;
	}
}

public int MenuHandler_Ban(Handle menu, MenuAction action, int param1, int param2)
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
				CPrintToChat(param1, "[{lightgreen}NativeVotes\x01] %t", "Player no longer available");
			}
			else if (!CanUserTarget(param1, target))
			{
				CPrintToChat(param1, "[{lightgreen}NativeVotes\x01] %t", "Unable to target");
			}
			else
			{
				g_voteArg[0] = '\0';
				DisplayVoteBanMenu(param1, target);
			}
		}
	}
	
	return Plugin_Continue;
}

public Action Command_Voteban(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "[{lightgreen}NativeVotes\x01] Usage: sm_voteban <player> [reason]");
		return Plugin_Handled;
	}
	
	if (Internal_IsVoteInProgress())
	{
		CReplyToCommand(client, "[{lightgreen}NativeVotes\x01] %t", "Vote in Progress");
		return Plugin_Handled;
	}
	
	if (!TestVoteDelay(client))
	{
		return Plugin_Handled;
	}

	char text[256], arg[64];
	GetCmdArgString(text, sizeof(text));
	int len = BreakString(text, arg, sizeof(arg));
	if (len != -1)
	{
		strcopy(g_voteArg, sizeof(g_voteArg), text[len]);
	}
	else
	{
		g_voteArg[0] = '\0';
	}

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_MULTI|COMMAND_FILTER_NO_BOTS,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	DisplayVoteBanMenu(client, target_list[0]);
	return Plugin_Handled;
}