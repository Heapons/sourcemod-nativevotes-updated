 /**
 * vim: set ts=4 :
 * =============================================================================
 * NativeVotes Fun Votes Plugin
 * Provides votegravity functionality
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

void DisplayVoteGravityMenu(int client, int count, char items[5][64])
{
	LogAction(client, -1, "\"%L\" initiated a gravity vote.", client);
	CShowActivity2(client, PLUGIN_PREFIX ... " ", "%t", "Initiated Vote Gravity");
	
	g_VoteType = gravity;
	
	if (g_NativeVotes && (count == 1 || NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_Mult)) )
	{
		Handle hVoteMenu;
		if (count == 1)
		{
			strcopy(g_VoteInfo[VOTE_NAME], sizeof(g_VoteInfo[]), items[0]);

			hVoteMenu = NativeVotes_Create(Handler_NativeVoteCallback, NativeVotesType_Custom_YesNo, view_as<MenuAction>(MENU_ACTIONS_ALL));
			NativeVotes_SetTitle(hVoteMenu, "Change Gravity To");
			// No details for custom votes
		}
		else
		{
			hVoteMenu = NativeVotes_Create(Handler_NativeVoteCallback, NativeVotesType_Custom_Mult, view_as<MenuAction>(MENU_ACTIONS_ALL));
			NativeVotes_SetTitle(hVoteMenu, "Gravity Vote");
			for (int i = 0; i < count; i++)
			{
				NativeVotes_AddItem(hVoteMenu, items[i], items[i]);
			}	
		}
		NativeVotes_DisplayToAll(hVoteMenu, g_ConVars[sv_vote_timer_duration].IntValue);
	}
	else
	{
		Handle hVoteMenu = CreateMenu(Handler_VoteCallback, view_as<MenuAction>(MENU_ACTIONS_ALL));
		
		if (count == 1)
		{
			strcopy(g_VoteInfo[VOTE_NAME], sizeof(g_VoteInfo[]), items[0]);
				
			SetMenuTitle(hVoteMenu, "Change Gravity To");
			AddMenuItem(hVoteMenu, items[0], "Yes");
			AddMenuItem(hVoteMenu, VOTE_NO, "No");
		}
		else
		{
			g_VoteInfo[VOTE_NAME][0] = '\0';
			
			SetMenuTitle(hVoteMenu, "Gravity Vote");
			for (int i = 0; i < count; i++)
			{
				AddMenuItem(hVoteMenu, items[i], items[i]);
			}	
		}
		
		SetMenuExitButton(hVoteMenu, false);
		VoteMenuToAll(hVoteMenu, g_ConVars[sv_vote_timer_duration].IntValue);
	}
}

public void AdminMenu_VoteGravity(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Gravity vote", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		/* Might need a better way of selecting the list of pre-defined gravity choices */
		char items[5][5] ={"200","400","800","1600","3200"};
		DisplayVoteGravityMenu(param,5, items);
	}
	else if (action == TopMenuAction_DrawOption)
	{
		/* disable this option if a vote is already running */
		buffer[0] = !Internal_IsNewVoteAllowed() ? ITEMDRAW_IGNORE : ITEMDRAW_DEFAULT;
	}
}

public Action Command_VoteGravity(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, PLUGIN_PREFIX ... " Usage: sm_votegravity <amount> [amount2] ... [amount5]");
		return Plugin_Handled;
	}
	
	if (Internal_IsVoteInProgress())
	{
		CReplyToCommand(client, PLUGIN_PREFIX ... " %t", "Vote in Progress");
		return Plugin_Handled;
	}
	
	if (!TestVoteDelay(client))
	{
		return Plugin_Handled;
	}
	
	char text[256];
	GetCmdArgString(text, sizeof(text));
	
	char items[5][64];
	int count;
	int len, pos;
	
	while (pos != -1 && count < 5)
	{
		pos = BreakString(text[len], items[count], sizeof(items[]));
		
		float temp;
		if (StringToFloatEx(items[count], temp) == 0)
		{
			CReplyToCommand(client, PLUGIN_PREFIX ... " %t", "Invalid Amount");
			return Plugin_Handled;
		}

		count++;
		
		if (pos != -1)
		{
			len += pos;
		}
	}
	
	DisplayVoteGravityMenu(client, count, items);
	
	return Plugin_Handled;
}