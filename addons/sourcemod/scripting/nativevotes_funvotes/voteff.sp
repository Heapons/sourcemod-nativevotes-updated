 /**
 * vim: set ts=4 :
 * =============================================================================
 * NativeVotes Fun Votes Plugin
 * Provides vote ff functionality
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

DisplayVoteFFMenu(client)
{
	if (Internal_IsVoteInProgress())
	{
		CReplyToCommand(client, "[{lightgreen}NativeVotes\x01] %t", "Vote in Progress");
		return;
	}	
	
	if (!TestVoteDelay(client))
	{
		return;
	}
	
	LogAction(client, -1, "\"%L\" initiated a friendly fire vote.", client);
	CShowActivity2(client, "[{lightgreen}NativeVotes\x01] ", "%t", "Initiated Vote FF");
	
	g_voteType = voteType:ff;
	g_voteInfo[VOTE_NAME][0] = '\0';
	
	if (g_NativeVotes)
	{
		new Handle:hVoteMenu = NativeVotes_Create(Handler_NativeVoteCallback, NativeVotesType_Custom_YesNo, MenuAction:MENU_ACTIONS_ALL);
		
		if (GetConVarBool(g_Cvar_FF))
		{
			NativeVotes_SetTitle(hVoteMenu, "Voteff Off");
		}
		else
		{
			NativeVotes_SetTitle(hVoteMenu, "Voteff On");
		}
		NativeVotes_DisplayToAll(hVoteMenu, 20);		
	}
	else
	{
		new Handle:hVoteMenu = CreateMenu(Handler_VoteCallback, MenuAction:MENU_ACTIONS_ALL);
		
		if (GetConVarBool(g_Cvar_FF))
		{
			SetMenuTitle(hVoteMenu, "Voteff Off");
		}
		else
		{
			SetMenuTitle(hVoteMenu, "Voteff On");
		}
		
		AddMenuItem(hVoteMenu, VOTE_YES, "Yes");
		AddMenuItem(hVoteMenu, VOTE_NO, "No");
		SetMenuExitButton(hVoteMenu, false);
		VoteMenuToAll(hVoteMenu, 20);
	}
}

public AdminMenu_VoteFF(Handle:topmenu, 
							  TopMenuAction:action,
							  TopMenuObject:object_id,
							  param,
							  String:buffer[],
							  maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Vote FF", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayVoteFFMenu(param);
	}
	else if (action == TopMenuAction_DrawOption)
	{	
		/* disable this option if a vote is already running */
		buffer[0] = !Internal_IsNewVoteAllowed() ? ITEMDRAW_IGNORE : ITEMDRAW_DEFAULT;
	}
}

public Action:Command_VoteFF(client, args)
{
	if (args > 0)
	{
		CReplyToCommand(client, "[{lightgreen}NativeVotes\x01] Usage: sm_voteff");
		return Plugin_Handled;	
	}
	
	DisplayVoteFFMenu(client);
	
	return Plugin_Handled;
}