 /**
 * vim: set ts=4 :
 * =============================================================================
 * NativeVotes Fun Votes Plugin
 * Provides votealltalk functionality
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

void DisplayVoteAllTalkMenu(int client)
{
	if (Internal_IsVoteInProgress())
	{
		CReplyToCommand(client, "[\x04NativeVotes\x01] %t", "Vote in Progress");
		return;
	}	
	
	if (!TestVoteDelay(client))
	{
		return;
	}
	
	LogAction(client, -1, "\"%L\" initiated an alltalk vote.", client);
	CShowActivity2(client, "[\x04NativeVotes\x01] ", "%t", "Initiated Vote Alltalk");
	
	g_voteType = voteType:alltalk;
	g_voteInfo[VOTE_NAME][0] = '\0';

	if (g_NativeVotes)
	{
		Handle hVoteMenu;
		if (NativeVotes_IsVoteTypeSupported(NativeVotesType_AlltalkOn))
		{
			new NativeVotesType:nVoteType;
			if (GetConVarBool(g_ConVars[sv_alltalk]))
			{
				nVoteType = NativeVotesType_AlltalkOff;
			}
			else
			{
				nVoteType = NativeVotesType_AlltalkOn;
			}
			hVoteMenu = NativeVotes_Create(Handler_NativeVoteCallback, nVoteType, view_as<MenuAction>(MENU_ACTIONS_ALL));
		}
		else
		{
			hVoteMenu = NativeVotes_Create(Handler_NativeVoteCallback, NativeVotesType_Custom_YesNo, view_as<MenuAction>(MENU_ACTIONS_ALL));

			if (GetConVarBool(g_ConVars[sv_alltalk]))
			{
				NativeVotes_SetTitle(hVoteMenu, "Votealltalk Off");
			}
			else
			{
				NativeVotes_SetTitle(hVoteMenu, "Votealltalk On");
			}
		}
		
		NativeVotes_DisplayToAll(hVoteMenu, 20);
	}
	else
	{
		Handle hVoteMenu = CreateMenu(Handler_VoteCallback, MENU_ACTIONS_ALL);
		
		if (GetConVarBool(g_ConVars[sv_alltalk]))
		{
			SetMenuTitle(hVoteMenu, "Votealltalk Off");
		}
		else
		{
			SetMenuTitle(hVoteMenu, "Votealltalk On");
		}
		
		AddMenuItem(hVoteMenu, VOTE_YES, "Yes");
		AddMenuItem(hVoteMenu, VOTE_NO, "No");
		SetMenuExitButton(hVoteMenu, false);
		VoteMenuToAll(hVoteMenu, 20);
	}
}


public void AdminMenu_VoteAllTalk(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption:
		{
			Format(buffer, maxlength, "%T", "Alltalk vote", param);
		}
		case TopMenuAction_SelectOption:
		{
			DisplayVoteAllTalkMenu(param);
		}
		case TopMenuAction_DrawOption:
		{
			/* disable this option if a vote is already running */
			buffer[0] = !Internal_IsNewVoteAllowed() ? ITEMDRAW_IGNORE : ITEMDRAW_DEFAULT;
		}
	}
}

public Action Command_VoteAlltalk(int client, int args)
{
	if (args > 0)
	{
		CReplyToCommand(client, "[\x04NativeVotes\x01] Usage: sm_votealltalk");
		return Plugin_Handled;
	}
	
	DisplayVoteAllTalkMenu(client);
	
	return Plugin_Handled;
}