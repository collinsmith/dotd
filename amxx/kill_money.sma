/*	Formatright © 2010, ConnorMcLeod

	Kill Money is free software;
	you can redistribute it and/or modify it under the terms of the
	GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with Kill Money; if not, write to the
	Free Software Foundation, Inc., 59 Temple Place - Suite 330,
	Boston, MA 02111-1307, USA.
*/

#include <amxmodx>
#include <cstrike>
#include <fakemeta>

#define VERSION "0.1.1"

enum
{	
	DeathMsg_KillerID = 1, // byte
	DeathMsg_VictimID, // byte
	DeathMsg_IsHeadshot, // byte
	DeathMsg_TruncatedWeaponName // string
}

#define Money_Amount 1

new g_iMaxPlayers
#define IsPlayer(%1)	( 1 <= %1 <= g_iMaxPlayers )

#define XTRA_OFS_PLAYER 5
#define m_iAccount 115
#define cs_set_money_value(%1,%2)	set_pdata_int(%1, m_iAccount, %2, XTRA_OFS_PLAYER)

new g_pCvarKillMoney, g_pCvarTkMoney, g_pCvarMaxMoney, g_pCvarKillMoneyHs

new g_iNewMoney
new g_iMsgHookMoney
new gmsgMoney

public plugin_init()
{
	register_plugin("Kill Money", VERSION, "ConnorMcLeod")

	g_pCvarKillMoney = register_cvar("amx_kill_money", "300")
	g_pCvarKillMoneyHs = register_cvar("amx_kill_money_hs", "1337")
	g_pCvarTkMoney = register_cvar("amx_teamkill_money", "-1337")
	g_pCvarMaxMoney = register_cvar("amx_killmoney_maxmoney", "16000")

	register_event("DeathMsg", "Event_DeathMsg", "a")

	g_iMaxPlayers = get_maxplayers()
	gmsgMoney = get_user_msgid("Money")
	
}

public Event_DeathMsg()
{
	new iKiller = read_data(DeathMsg_KillerID)
	if( IsPlayer(iKiller) && is_user_connected(iKiller) )
	{
		new iVictim = read_data(DeathMsg_VictimID)
		if( iVictim != iKiller )
		{
			g_iNewMoney = clamp
						( 
							cs_get_user_money(iKiller) + get_pcvar_num( cs_get_user_team(iVictim) == cs_get_user_team(iKiller) ? g_pCvarTkMoney : (read_data(DeathMsg_IsHeadshot) ? g_pCvarKillMoneyHs : g_pCvarKillMoney) ), 
							0, 
							get_pcvar_num(g_pCvarMaxMoney)
						)
			g_iMsgHookMoney = register_message(gmsgMoney, "Message_Money")
		}
	}
}

public Message_Money(iMsgId, iMsgDest, id)
{
	unregister_message(gmsgMoney, g_iMsgHookMoney)
	cs_set_money_value(id, g_iNewMoney)
	set_msg_arg_int(Money_Amount, ARG_LONG, g_iNewMoney)
}
