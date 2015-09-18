//////////////////////////////////////////////////////////
// ZombieHell 1.6b - www.zombiehell.co.cc               //
////////////////////////////////////////////////////////

#include <amxmodx>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>

#define PLUGIN "Zombie Hell"
#define VERSION "1.6b"
#define AUTHOR "hectorz0r"
#define MODELSET_TASK 100
#define MODELCHANGE_DELAY 0.5
#define MAX_CLIENTS 32
#define AMMO_SLOT 376

#define AUTO_TEAM_JOIN_DELAY 0.1
#define TEAM_SELECT_VGUI_MENU_ID 2

new zombie_knife, zombie_maxslots, death_effect, zombie_level, zombie_respawns, zombie_bot, zombie_scores, survivor_classes, survivor_nades, survivor_maxnades, maxplayers//, zh_fire, gmsgDamage
new level1_name, level1_respawns, level1_health, level1_maxspeed, level1_bosshp, level1_bossmaxspeed
new level2_name, level2_respawns, level2_health, level2_maxspeed, level2_bosshp, level2_bossmaxspeed
new level3_name, level3_respawns, level3_health, level3_maxspeed, level3_bosshp, level3_bossmaxspeed
new level4_name, level4_respawns, level4_health, level4_maxspeed, level4_bosshp, level4_bossmaxspeed
new level5_name, level5_respawns, level5_health, level5_maxspeed, level5_bosshp, level5_bossmaxspeed
new level6_name, level6_respawns, level6_health, level6_maxspeed, level6_bosshp, level6_bossmaxspeed
new level7_name, level7_respawns, level7_health, level7_maxspeed, level7_bosshp, level7_bossmaxspeed
new level8_name, level8_respawns, level8_health, level8_maxspeed, level8_bosshp, level8_bossmaxspeed
new level9_name, level9_respawns, level9_health, level9_maxspeed, level9_bosshp, level9_bossmaxspeed
new level10_name, level10_respawns, level10_health, level10_maxspeed, level10_bosshp, level10_bossmaxspeed
new level1_desc[64], level2_desc[64], level3_desc[64], level4_desc[64], level5_desc[64], level6_desc[64], level7_desc[64], level8_desc[64], level9_desc[64], level10_desc[64]

new Float:g_vecLastOrigin[MAX_CLIENTS+1][3]
new Float:g_models_targettime
new Float:g_roundstarttime

new g_has_custom_model[33], g_player_model[33][32], g_zombie[33], userkill[33], g_iRespawnCount[33]/*, onfire[33]*/, player_class[33], zombie_class[33], boss_class[33]

new modname[32] = "Zombie Hell"

new smokeskele, night_clock
//new map_time, time_left, time_played, map_timelimit

new timeh = 00
new timem = 00
new times = 00

new g_pcvar_team
new g_pcvar_class

new const ZOMBIE_MODEL1[] = "zh_tirant1" 
new const ZOMBIE_MODEL2[] = "zh_tirant2"
new const ZOMBIE_MODEL3[] = "zh_tirant3" 

public plugin_precache() 
{
	precache_sound("zombiehell/zh_boss.wav")
	precache_sound("zombiehell/zh_brain.wav")
	precache_sound("zombiehell/zh_score.wav")
	precache_sound("zombiehell/zh_ambience.mp3")
	
	precache_generic("gfx/env/zombiehell2bk.tga")
	precache_generic("gfx/env/zombiehell2dn.tga")
	precache_generic("gfx/env/zombiehell2ft.tga")
	precache_generic("gfx/env/zombiehell2lf.tga")
	precache_generic("gfx/env/zombiehell2rt.tga")
	precache_generic("gfx/env/zombiehell2up.tga")
	
	//zh_fire = precache_model("sprites/zh_fire.spr")
	
	precache_model("models/player/zh_tirant1/zh_tirant1.mdl")
	precache_model("models/player/zh_tirant2/zh_tirant2.mdl")
	precache_model("models/player/zh_tirant3/zh_tirant3.mdl")

	smokeskele = precache_model("sprites/effects/death_effect_skeleton.spr")
	
	set_lights("d")
	
	new fog = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_fog"))
	DispatchKeyValue(fog, "density", "0.001")
	DispatchKeyValue(fog, "rendercolor", "10 10 10")
	
	register_forward(FM_KeyValue, "fwd_KeyValue", 1)
}

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_cvar("ZombieHell", VERSION, FCVAR_SERVER|FCVAR_SPONLY)
	
	register_event("HLTV", "event_roundstart", "a", "1=0", "2=0")
	register_event("ResetHUD", "event_power", "be")
	register_event("DeathMsg", "event_eatbrains", "a", "1>0")
	register_event("DeathMsg", "respawn_zombies", "a")
	//register_event("Damage", "event_damage", "be", "2!0", "3=0")
	register_event("CurWeapon", "check_speed", "be", "1=1")
	register_event("AmmoX", "unlimited_ammo", "be", "1=1", "1=2", "1=3", "1=4", "1=5", "1=6", "1=7", "1=8", "1=9", "1=10")
	
	register_menucmd(register_menuid("Team_Select"), MENU_KEY_1 | MENU_KEY_2, "jointeam")
	register_clcmd("jointeam 1", "jointeam")
	register_clcmd("jointeam 2", "jointeam")
	//register_clcmd("say /ammo", "unlimited_ammo")
	
	register_message(get_user_msgid("ShowMenu"), "message_show_menu")
	register_message(get_user_msgid("VGUIMenu"), "message_vgui_menu")
	
	RegisterHam(Ham_Touch, "weaponbox", "weapon_cleaner", 1)
	RegisterHam(Ham_TakeDamage, "player", "zombie_knifekill")
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn", 1)
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
	
	register_forward(FM_GetGameDescription, "gamedesc")
	register_forward(FM_SetClientKeyValue, "fw_SetClientKeyValue")
	register_forward(FM_ClientUserInfoChanged, "fw_ClientUserInfoChanged")
	register_forward(FM_SetModel, "fw_setmodel")	
	register_forward(FM_Think, "fw_think")
	
	zombie_knife = register_cvar("zh_zombie_knife", "0")
	zombie_maxslots = register_cvar("zh_zombie_maxslots", "10")
	death_effect = register_cvar("zh_death_effect", "1")
	zombie_level = register_cvar("zombie_level", "1")
	zombie_respawns = register_cvar("zh_zombie_respawns", "2")
	zombie_bot = register_cvar("zh_zombie_bot", "1")
	zombie_scores = register_cvar("zh_zombie_scores", "0")
	survivor_classes = register_cvar("zh_survivor_classes", "2")
	survivor_nades = register_cvar("zh_survivor_nades", "1")
	survivor_maxnades = register_cvar("zh_survivor_maxnades", "1")
	night_clock = register_cvar("zh_clock", "1")
	//map_timelimit = register_cvar("map_timelimit", "120")
	g_pcvar_team = register_cvar("zh_ajc_team", "2")
	g_pcvar_class = register_cvar("zh_ajc_class", "5")
	
	level1_name = register_cvar("level1_name", "The Beginning")
	level1_respawns = register_cvar("level1_respawns", "1")
	level1_health = register_cvar("level1_health", "100")
	level1_maxspeed = register_cvar("level1_maxspeed", "260.0")
	level1_bosshp = register_cvar("level1_bosshp", "500")
	level1_bossmaxspeed = register_cvar("level1_bossmaxspeed", "180.0")
	level2_name = register_cvar("level2_name", "")
	level2_respawns = register_cvar("level2_respawns", "2")
	level2_health = register_cvar("level2_health", "150")
	level2_maxspeed = register_cvar("level2_maxspeed", "270.0")
	level2_bosshp = register_cvar("level2_bosshp", "1000")
	level2_bossmaxspeed = register_cvar("level2_bossmaxspeed", "190.0")
	level3_name = register_cvar("level3_name", "")
	level3_respawns = register_cvar("level3_respawns", "3")
	level3_health = register_cvar("level3_health", "200")
	level3_maxspeed = register_cvar("level3_maxspeed", "280.0")
	level3_bosshp = register_cvar("level3_bosshp", "1500")
	level3_bossmaxspeed = register_cvar("level3_bossmaxspeed", "200.0")
	level4_name = register_cvar("level4_name", "")
	level4_respawns = register_cvar("level4_respawns", "4")
	level4_health = register_cvar("level4_health", "250")
	level4_maxspeed = register_cvar("level4_maxspeed", "290.0")
	level4_bosshp = register_cvar("level4_bosshp", "2000")
	level4_bossmaxspeed = register_cvar("level4_bossmaxspeed", "210.0")
	level5_name = register_cvar("level5_name", "The Nightmare")
	level5_respawns = register_cvar("level5_respawns", "5")
	level5_health = register_cvar("level5_health", "400")
	level5_maxspeed = register_cvar("level5_maxspeed", "300.0")
	level5_bosshp = register_cvar("level5_bosshp", "2500")
	level5_bossmaxspeed = register_cvar("level5_bossmaxspeed", "220.0")
	level6_name = register_cvar("level6_name", "")
	level6_respawns = register_cvar("level6_respawns", "6")
	level6_health = register_cvar("level6_health", "550")
	level6_maxspeed = register_cvar("level6_maxspeed", "310.0")
	level6_bosshp = register_cvar("level6_bosshp", "3000")
	level6_bossmaxspeed = register_cvar("level6_bossmaxspeed", "230.0")
	level7_name = register_cvar("level7_name", "")
	level7_respawns = register_cvar("level7_respawns", "7")
	level7_health = register_cvar("level7_health", "600")
	level7_maxspeed = register_cvar("level7_maxspeed", "320.0")
	level7_bosshp = register_cvar("level7_bosshp", "3500")
	level7_bossmaxspeed = register_cvar("level7_bossmaxspeed", "240.0")
	level8_name = register_cvar("level8_name", "Hell on Earth")
	level8_respawns = register_cvar("level8_respawns", "8")
	level8_health = register_cvar("level8_health", "750")
	level8_maxspeed = register_cvar("level8_maxspeed", "340.0")
	level8_bosshp = register_cvar("level8_bosshp", "4000")
	level8_bossmaxspeed = register_cvar("level8_bossmaxspeed", "250.0")
	level9_name = register_cvar("level9_name", "")
	level9_respawns = register_cvar("level9_respawns", "9")
	level9_health = register_cvar("level9_health", "800")
	level9_maxspeed = register_cvar("level9_maxspeed", "360.0")
	level9_bosshp = register_cvar("level9_bosshp", "4500")
	level9_bossmaxspeed = register_cvar("level9_bossmaxspeed", "260.0")
	level10_name = register_cvar("level10_name", "The End")
	level10_respawns = register_cvar("level10_respawns", "10")
	level10_health = register_cvar("level10_health", "1000")
	level10_maxspeed = register_cvar("level10_maxspeed", "385.0")
	level10_bosshp = register_cvar("level10_bosshp", "15000")
	level10_bossmaxspeed = register_cvar("level10_bossmaxspeed", "320.0")
	
	server_cmd("zombie_knife 0")
	server_cmd("zombie_level 1")
	server_cmd("sv_skyname zombiehell2")
	server_cmd("mp_roundtime 999")
	server_cmd("mp_buytime 999")
	server_cmd("mp_flashlight 0")
	server_cmd("mp_limitteams 0")
	server_cmd("mp_autoteambalance 0")
	server_cmd("mp_freezetime 0")
	server_cmd("sv_maxspeed 999")
	server_cmd("exec addons/amxmodx/configs/zombiehell.cfg")
	server_cmd("exec addons/amxmodx/configs/zombiehell_levels.cfg")
	
	set_msg_block(get_user_msgid("ClCorpse"), BLOCK_SET)
	set_msg_block(get_user_msgid("RoundTime"), BLOCK_SET)
	
	maxplayers = get_maxplayers()
	//gmsgDamage = get_user_msgid("Damage")
}

public gamedesc() 
{ 
	forward_return(FMV_STRING, modname) 
	return FMRES_SUPERCEDE
}

public event_eatbrains()
{
	new Client = read_data(1)
	new Client2 = read_data(2)
	new name[32]
	new name2[32]
	get_user_name(Client, name, 31)
	get_user_name(Client2, name2, 31)
	if(cs_get_user_team(Client) == CS_TEAM_T && is_user_alive(Client))
	{
		new Health = get_user_health(Client) + 100
		set_user_health(Client, Health)
		client_print(0, print_chat, "%s has eaten %s's brain!", name, name2)
		client_cmd(0, "spk zombiehell/zh_brain.wav")
	}
}

public weapon_cleaner(iEntity)
{
	call_think(iEntity)
}

public zombie_knifekill(id, ent, idattacker, Float:damage, damagebits)
{
	if( ent == idattacker && is_user_alive(ent) && get_user_weapon(ent) == CSW_KNIFE && cs_get_user_team(id) == CS_TEAM_CT && get_pcvar_num(zombie_knife) == 1)
	{
		new Float:flHealth
		pev(id, pev_health, flHealth)
		SetHamParamFloat(4, flHealth * 5)
		
		return HAM_HANDLED
	}
	return HAM_IGNORED
}

public event_roundstart()
{
	for(new i = 1; i <= maxplayers; i++)
	{
		g_iRespawnCount[i] = 0
		remove_task(i)
	}
	set_task(2.0, "zombie_gamestart")
	switch(get_pcvar_num(zombie_level))
	{
		case 1:
		{ 
			set_lights("d")
		}
		case 2:
		{ 
			set_lights("d")
		}
		case 3:
		{ 
			set_lights("d")
		}
		case 4:
		{ 
			set_lights("d")
		}
		case 5:
		{ 
			set_lights("c")
		}
		case 6:
		{ 
			set_lights("c")
		}
		case 7:
		{ 
			set_lights("c")
		}
		case 8:
		{ 
			set_lights("b")
		}
		case 9:
		{ 
			set_lights("b")
		}
		case 10:
		{ 
			set_lights("a")
		}
	}
	g_roundstarttime = get_gametime()
}

public game_timer()
{
	set_hudmessage(255, 255, 255, -1.0, 0.0, 0, 6.0, 1.0, 0.1, 0.2, 1)
	
	times ++
	if(times > 59)
	{
		times = 00
		timem ++
	}
	
	if(timem > 59)
	{
		timem = 00
		timeh ++
	}
	
	if(times < 10)
		show_hudmessage(0, "Night %d^n0%d:%d:0%d", get_pcvar_num(zombie_level), timeh, timem, times)
	if(timem < 10)
		show_hudmessage(0, "Night %d^n0%d:0%d:%d", get_pcvar_num(zombie_level), timeh, timem, times)
	if(timem < 10 && times < 10)
		show_hudmessage(0, "Night %d^n0%d:0%d:0%d", get_pcvar_num(zombie_level), timeh, timem, times)
	
	set_task(1.0, "game_timer")
}

public zombie_gamestart()
{
	client_cmd(0, "mp3 play sound/zombiehell/zh_ambience.mp3")
	set_task(1.0, "zombie_bots")
	set_task(1.0, "zombie_slots")
	
	if(get_pcvar_num(night_clock) == 1)
	{
		set_task(0.1, "game_timer")
	}
	switch(get_pcvar_num(zombie_level))
	{
		case 1:
		{ 
			server_cmd("zombie_knife 0")
			get_pcvar_string(level1_name, level1_desc, sizeof level1_desc -1)
			set_hudmessage(255, 0, 0, -1.0, -1.0, 2, 6.0, 10.0, 0.1, 0.2, 2)
			show_hudmessage(0, "Night %d^nChapter 1: %s^n^nBoss: %d Health / %d Velocity^nZombies: %d Health / %d Velocity / %d Respawns", get_pcvar_num(zombie_level), level1_desc, get_pcvar_num(level1_bosshp), get_pcvar_num(level1_bossmaxspeed), get_pcvar_num(level1_health), get_pcvar_num(level1_maxspeed), get_pcvar_num(level1_respawns))
		}
		case 2:
		{ 
			server_cmd("zombie_knife 0")
			get_pcvar_string(level2_name, level2_desc, sizeof level2_desc -1)
			set_hudmessage(255, 0, 0, -1.0, -1.0, 2, 6.0, 10.0, 0.1, 0.2, 2)
			show_hudmessage(0, "Night %d^n%s^n^nBoss: %d Health / %d Velocity^nZombies: %d Health / %d Velocity / %d Respawns", get_pcvar_num(zombie_level), level2_desc, get_pcvar_num(level2_bosshp), get_pcvar_num(level2_bossmaxspeed), get_pcvar_num(level2_health), get_pcvar_num(level2_maxspeed), get_pcvar_num(level2_respawns))
		}
		case 3:
		{ 
			server_cmd("zombie_knife 0")
			get_pcvar_string(level3_name, level3_desc, sizeof level3_desc -1)
			set_hudmessage(255, 0, 0, -1.0, -1.0, 2, 6.0, 10.0, 0.1, 0.2, 2)
			show_hudmessage(0, "Night %d^n%s^n^nBoss: %d Health / %d Velocity^nZombies: %d Health / %d Velocity / %d Respawns", get_pcvar_num(zombie_level), level3_desc, get_pcvar_num(level3_bosshp), get_pcvar_num(level3_bossmaxspeed), get_pcvar_num(level3_health), get_pcvar_num(level3_maxspeed), get_pcvar_num(level3_respawns))
		}
		case 4:
		{ 
			server_cmd("zombie_knife 0")
			get_pcvar_string(level4_name, level4_desc, sizeof level4_desc -1)
			set_hudmessage(255, 0, 0, -1.0, -1.0, 2, 6.0, 10.0, 0.1, 0.2, 2)
			show_hudmessage(0, "Night %d^n%s^n^nBoss: %d Health / %d Velocity^nZombies: %d Health / %d Velocity / %d Respawns", get_pcvar_num(zombie_level), level4_desc, get_pcvar_num(level4_bosshp), get_pcvar_num(level4_bossmaxspeed), get_pcvar_num(level4_health), get_pcvar_num(level4_maxspeed), get_pcvar_num(level4_respawns))
		}
		case 5:
		{ 
			server_cmd("zombie_knife 0")
			get_pcvar_string(level5_name, level5_desc, sizeof level5_desc -1)
			set_hudmessage(255, 0, 0, -1.0, -1.0, 2, 6.0, 10.0, 0.1, 0.2, 2)
			show_hudmessage(0, "Night %d^nChapter 2: %s^n^nBoss: %d Health / %d Velocity^nZombies: %d Health / %d Velocity / %d Respawns", get_pcvar_num(zombie_level), level5_desc, get_pcvar_num(level5_bosshp), get_pcvar_num(level5_bossmaxspeed), get_pcvar_num(level5_health), get_pcvar_num(level5_maxspeed), get_pcvar_num(level5_respawns))
		}
		case 6:
		{ 
			server_cmd("zombie_knife 0")
			get_pcvar_string(level6_name, level6_desc, sizeof level6_desc -1)
			set_hudmessage(255, 0, 0, -1.0, -1.0, 2, 6.0, 10.0, 0.1, 0.2, 2)
			show_hudmessage(0, "Night %d^n%s^n^nBoss: %d Health / %d Velocity^nZombies: %d Health / %d Velocity / %d Respawns", get_pcvar_num(zombie_level), level6_desc, get_pcvar_num(level6_bosshp), get_pcvar_num(level6_bossmaxspeed), get_pcvar_num(level6_health), get_pcvar_num(level6_maxspeed), get_pcvar_num(level6_respawns))
		}
		case 7:
		{ 
			server_cmd("zombie_knife 0")
			get_pcvar_string(level7_name, level7_desc, sizeof level7_desc -1)
			set_hudmessage(255, 0, 0, -1.0, -1.0, 2, 6.0, 10.0, 0.1, 0.2, 2)
			show_hudmessage(0, "Night %d^n%s^n^nBoss: %d Health / %d Velocity^nZombies: %d Health / %d Velocity / %d Respawns", get_pcvar_num(zombie_level), level7_desc, get_pcvar_num(level7_bosshp), get_pcvar_num(level7_bossmaxspeed), get_pcvar_num(level7_health), get_pcvar_num(level7_maxspeed), get_pcvar_num(level7_respawns))
		}
		case 8:
		{ 
			server_cmd("zombie_knife 0")
			get_pcvar_string(level8_name, level8_desc, sizeof level8_desc -1)
			set_hudmessage(255, 0, 0, -1.0, -1.0, 2, 6.0, 10.0, 0.1, 0.2, 2)
			show_hudmessage(0, "Night %d^nChapter 3: %s^n^nBoss: %d Health / %d Velocity^nZombies: %d Health / %d Velocity / %d Respawns", get_pcvar_num(zombie_level), level8_desc, get_pcvar_num(level8_bosshp), get_pcvar_num(level8_bossmaxspeed), get_pcvar_num(level8_health), get_pcvar_num(level8_maxspeed), get_pcvar_num(level8_respawns))
		}
		case 9:
		{ 
			server_cmd("zombie_knife 0")
			get_pcvar_string(level9_name, level9_desc, sizeof level9_desc -1)
			set_hudmessage(255, 0, 0, -1.0, -1.0, 2, 6.0, 10.0, 0.1, 0.2, 2)
			show_hudmessage(0, "Night %d^n%s^n^nBoss: %d Health / %d Velocity^nZombies: %d Health / %d Velocity / %d Respawns", get_pcvar_num(zombie_level), level9_desc, get_pcvar_num(level9_bosshp), get_pcvar_num(level9_bossmaxspeed), get_pcvar_num(level9_health), get_pcvar_num(level9_maxspeed), get_pcvar_num(level9_respawns))
		}
		case 10:
		{ 
			server_cmd("zombie_knife 0")
			get_pcvar_string(level10_name, level10_desc, sizeof level10_desc -1)
			set_hudmessage(255, 0, 0, -1.0, -1.0, 2, 6.0, 10.0, 0.1, 0.2, 2)
			show_hudmessage(0, "Night %d^n%s^n^nBoss: ????? Health / ??? Velocity^nZombies: %d Health / %d Velocity / %d Respawns", get_pcvar_num(zombie_level), level10_desc, get_pcvar_num(level10_health), get_pcvar_num(level10_maxspeed), get_pcvar_num(level10_respawns))
		}
	}
}

public zombie_slots()
{
	if(get_pcvar_num(zombie_bot))
	{
		switch(get_pcvar_num(zombie_bot))
		{
			case 1:
			{ 
				server_cmd("pb_minbots %d", get_pcvar_num(zombie_maxslots))
				server_cmd("pb_maxbots %d", get_pcvar_num(zombie_maxslots))
				server_cmd("pb_bot_quota_match 0")
			}
			case 2:
			{
				server_cmd("bot_quota %d", get_pcvar_num(zombie_maxslots))
				server_cmd("bot_quota_mode fill")
				server_cmd("bot_auto_vacate 0")
			}
		}
	}
}

public zombie_bots()
{
	if(get_pcvar_num(zombie_bot))
	{
		switch(get_pcvar_num(zombie_bot))
		{
			case 1:
			{ 
				server_cmd("pb_mapstartbotdelay 1")
				server_cmd("pb_bot_join_team T")
				server_cmd("pb_spray 0")
				server_cmd("pb_minbotskill 100")
				server_cmd("pb_maxbotskill 100")
				server_cmd("pb_maxweaponpickup 1")
				server_cmd("pb_maxcamptime 5")
				server_cmd("pb_jasonmode 1")
				server_cmd("pb_detailnames 0")
				server_cmd("pb_dangerfactor 0")
				server_cmd("pb_chat 0")
				server_cmd("pb_latencybot 1")
				server_cmd("pb_radio 0")
				server_cmd("pb_aim_type 4")
			}
			case 2:
			{ 
				server_cmd("bot_difficulty 4")
				server_cmd("bot_chatter off")
				server_cmd("bot_auto_follow 0")
				server_cmd("bot_join_after_player 0")
				server_cmd("bot_defer_to_human 1")
				server_cmd("bot_prefix -[zombie]-")
				server_cmd("bot_allow_rogues 0")
				server_cmd("bot_walk 0")
				server_cmd("bot_join_team T")
				server_cmd("bot_eco_limit 800")
				server_cmd("bot_allow_grenades 0")
				server_cmd("bot_knives_only")
				server_cmd("bot_allow_grenades 0")
				server_cmd("bot_allow_pistols 0")
				server_cmd("bot_allow_sub_machine_guns 0")
				server_cmd("bot_allow_shotguns 0")
				server_cmd("bot_allow_rifles 0")
				server_cmd("bot_allow_snipers 0")
				server_cmd("bot_allow_machine_guns 0")
			}
		}
	}
}

public event_power(id)
{
	player_class[id] = 0
	if (cs_get_user_team(id) == CS_TEAM_CT)
	{
		set_task(0.1, "survivor_power", id)
	}
	if (cs_get_user_team(id) == CS_TEAM_T)
	{
		switch(get_pcvar_num(zombie_level))
		{
			case 1:
			{ 
				set_task(0.1, "zombie_power_1", id)
			}
			case 2:
			{ 
				set_task(0.1, "zombie_power_2", id)
			}
			case 3:
			{ 
				set_task(0.1, "zombie_power_3", id)
			}
			case 4:
			{ 
				set_task(0.1, "zombie_power_4", id)
			}
			case 5:
			{ 
				set_task(0.1, "zombie_power_5", id)
			}
			case 6:
			{ 
				set_task(0.1, "zombie_power_6", id)
			}
			case 7:
			{ 
				set_task(0.1, "zombie_power_7", id)
			}
			case 8:
			{ 
				set_task(0.1, "zombie_power_8", id)
			}
			case 9:
			{ 
				set_task(0.1, "zombie_power_9", id)
			}
			case 10:
			{ 
				set_task(0.1, "zombie_power_10", id)
			}
		}
	}
}

public zombie_power_1(id)
{
	cs_set_user_money(id, 0)
	boss_class[id] = 0
	zombie_class[id] = 1
	//cs_set_user_nvg(id, 1)
	//engclient_cmd(id, "nightvision")
	strip_user_weapons(id)
	give_item(id, "weapon_knife")
	set_user_health(id, get_pcvar_num(level1_health))
	set_user_maxspeed(id, get_pcvar_float(level1_maxspeed))
}

public zombie_power_2(id)
{
	cs_set_user_money(id, 0)
	boss_class[id] = 0
	zombie_class[id] = 2
	//cs_set_user_nvg(id, 1)
	//engclient_cmd(id, "nightvision")
	strip_user_weapons(id)
	give_item(id, "weapon_knife")
	set_user_health(id, get_pcvar_num(level2_health))
	set_user_maxspeed(id, get_pcvar_float(level2_maxspeed))
}

public zombie_power_3(id)
{
	cs_set_user_money(id, 0)
	boss_class[id] = 0
	zombie_class[id] = 3
	//cs_set_user_nvg(id, 1)
	//engclient_cmd(id, "nightvision")
	strip_user_weapons(id)
	give_item(id, "weapon_knife")
	set_user_health(id, get_pcvar_num(level3_health))
	set_user_maxspeed(id, get_pcvar_float(level3_maxspeed))
}

public zombie_power_4(id)
{
	cs_set_user_money(id, 0)
	boss_class[id] = 0
	zombie_class[id] = 4
	//cs_set_user_nvg(id, 1)
	//engclient_cmd(id, "nightvision")
	strip_user_weapons(id)
	give_item(id, "weapon_knife")
	set_user_health(id, get_pcvar_num(level4_health))
	set_user_maxspeed(id, get_pcvar_float(level4_maxspeed))
}

public zombie_power_5(id)
{
	cs_set_user_money(id, 0)
	boss_class[id] = 0
	zombie_class[id] = 5
	//cs_set_user_nvg(id, 1)
	//engclient_cmd(id, "nightvision")
	strip_user_weapons(id)
	give_item(id, "weapon_knife")
	set_user_health(id, get_pcvar_num(level5_health))
	set_user_maxspeed(id, get_pcvar_float(level5_maxspeed))
}

public zombie_power_6(id)
{
	cs_set_user_money(id, 0)
	boss_class[id] = 0
	zombie_class[id] = 6
	//cs_set_user_nvg(id, 1)
	//engclient_cmd(id, "nightvision")
	strip_user_weapons(id)
	give_item(id, "weapon_knife")
	set_user_health(id, get_pcvar_num(level6_health))
	set_user_maxspeed(id, get_pcvar_float(level6_maxspeed))
}

public zombie_power_7(id)
{
	cs_set_user_money(id, 0)
	boss_class[id] = 0
	zombie_class[id] = 7
	//cs_set_user_nvg(id, 1)
	//engclient_cmd(id, "nightvision")
	strip_user_weapons(id)
	give_item(id, "weapon_knife")
	set_user_health(id, get_pcvar_num(level7_health))
	set_user_maxspeed(id, get_pcvar_float(level7_maxspeed))
}

public zombie_power_8(id)
{
	cs_set_user_money(id, 0)
	boss_class[id] = 0
	zombie_class[id] = 8
	//cs_set_user_nvg(id, 1)
	//engclient_cmd(id, "nightvision")
	strip_user_weapons(id)
	give_item(id, "weapon_knife")
	set_user_health(id, get_pcvar_num(level8_health))
	set_user_maxspeed(id, get_pcvar_float(level8_maxspeed))
}

public zombie_power_9(id)
{
	cs_set_user_money(id, 0)
	boss_class[id] = 0
	zombie_class[id] = 9
	//cs_set_user_nvg(id, 1)
	//engclient_cmd(id, "nightvision")
	strip_user_weapons(id)
	give_item(id, "weapon_knife")
	set_user_health(id, get_pcvar_num(level9_health))
	set_user_maxspeed(id, get_pcvar_float(level9_maxspeed))
}

public zombie_power_10(id)
{
	cs_set_user_money(id, 0)
	boss_class[id] = 0
	zombie_class[id] = 10
	//cs_set_user_nvg(id, 1)
	//engclient_cmd(id, "nightvision")
	strip_user_weapons(id)
	give_item(id, "weapon_knife")
	set_user_health(id, get_pcvar_num(level10_health))
	set_user_maxspeed(id, get_pcvar_float(level10_maxspeed))
}

public survivor_power(id) {
	if (get_pcvar_num(zombie_level) >= 8)
	{
		cs_set_user_nvg(id, 1)
	}
	if(get_pcvar_num(survivor_nades) == 1)
	{
		give_item(id, "weapon_smokegrenade")
		cs_set_user_bpammo(id, CSW_SMOKEGRENADE, get_pcvar_num(survivor_maxnades))
		give_item(id, "weapon_hegrenade")
		cs_set_user_bpammo(id, CSW_HEGRENADE, get_pcvar_num(survivor_maxnades))
	}
	if (get_pcvar_num(survivor_classes) == 1)
	{
		set_task(1.0, "class_menu", id)
	}
	if(get_pcvar_num(survivor_classes) == 2)
	{
		give_item(id, "weapon_m4a1")
		cs_set_user_bpammo(id, CSW_M4A1, 666)
		set_user_gravity(id, 2.5)
	}
}

public fw_PlayerSpawn( id )
{
	if ( !is_user_alive( id ) || !cs_get_user_team( id ) )
		return
	g_zombie[id] = cs_get_user_team( id ) == CS_TEAM_T ? true : false
	remove_task( id + MODELSET_TASK )
	if ( g_zombie[id] )
	{
		switch (random_num(1, 3))
		{
			case 1: copy(g_player_model[id], charsmax( g_player_model[] ), ZOMBIE_MODEL1)
				case 2: copy(g_player_model[id], charsmax( g_player_model[] ), ZOMBIE_MODEL2)
				case 3: copy(g_player_model[id], charsmax( g_player_model[] ), ZOMBIE_MODEL3)
			}
		new currentmodel[32]
		fm_get_user_model( id, currentmodel, charsmax( currentmodel ) )
		if ( !equal( currentmodel, g_player_model[id] ) )
		{
			if ( get_gametime() - g_roundstarttime < 5.0 )
				set_task( 5.0 * MODELCHANGE_DELAY, "fm_user_model_update", id + MODELSET_TASK )
			else
				fm_user_model_update( id + MODELSET_TASK )
		}
	}
	else if ( g_has_custom_model[id] )
	{
		fm_reset_user_model( id )
	}
}

public fw_SetClientKeyValue( id, const infobuffer[], const key[] )
{   
	if ( g_has_custom_model[id] && equal( key, "model" ) )
		return FMRES_SUPERCEDE
	return FMRES_IGNORED
}

public fw_ClientUserInfoChanged( id )
{
	if ( !g_has_custom_model[id] )
		return FMRES_IGNORED
	static currentmodel[32]
	fm_get_user_model( id, currentmodel, charsmax( currentmodel ) )
	if ( !equal( currentmodel, g_player_model[id] ) && !task_exists( id + MODELSET_TASK ) )
		fm_set_user_model( id + MODELSET_TASK )
	return FMRES_IGNORED
}

public fm_user_model_update( taskid )
{
	static Float:current_time
	current_time = get_gametime()
	
	if ( current_time - g_models_targettime >= MODELCHANGE_DELAY )
	{
		fm_set_user_model( taskid )
		g_models_targettime = current_time
	}
	else
	{
		set_task( (g_models_targettime + MODELCHANGE_DELAY) - current_time, "fm_set_user_model", taskid )
		g_models_targettime = g_models_targettime + MODELCHANGE_DELAY
	}
}

public fm_set_user_model( player )
{
	player -= MODELSET_TASK
	engfunc( EngFunc_SetClientKeyValue, player, engfunc( EngFunc_GetInfoKeyBuffer, player ), "model", g_player_model[player] )
	g_has_custom_model[player] = true
}

stock fm_get_user_model( player, model[], len )
{
	engfunc( EngFunc_InfoKeyValue, engfunc( EngFunc_GetInfoKeyBuffer, player ), "model", model, len )
}

stock fm_reset_user_model( player )
{
	g_has_custom_model[player] = false
	dllfunc( DLLFunc_ClientUserInfoChanged, player, engfunc( EngFunc_GetInfoKeyBuffer, player ) )
}

public client_disconnect(id)
{
	remove_task(id)
	g_iRespawnCount[id] = 0
}

public fw_PlayerKilled(victim, attacker, shouldgib)
{
	new cts[32], ts[32], ctsnum, tsnum
	new CsTeams:team
	
	for (new i=1; i<=maxplayers; i++)
	{
		if (!is_user_alive(i))
		{
			continue
		}
		team = cs_get_user_team(i)
		if (team == CS_TEAM_T)
		{
			ts[tsnum++] = i
			} else if (team == CS_TEAM_CT) {
			cts[ctsnum++] = i
		}
	}
	if (ctsnum == 0)
	{
		switch(get_pcvar_num(zombie_level))
		{
			case 1:
			{
				server_cmd("zombie_level 1")
				server_cmd("zombie_respawns %d", get_pcvar_num(level1_respawns))
			}
			case 2:
			{
				server_cmd("zombie_level 2")
				server_cmd("zombie_respawns %d", get_pcvar_num(level2_respawns))
			}
			case 3:
			{
				server_cmd("zombie_level 3")
				server_cmd("zombie_respawns %d", get_pcvar_num(level3_respawns))
			}
			case 4:
			{
				server_cmd("zombie_level 4")
				server_cmd("zombie_respawns %d", get_pcvar_num(level4_respawns))
			}
			case 5:
			{
				server_cmd("zombie_level 5")
				server_cmd("zombie_respawns %d", get_pcvar_num(level5_respawns))
			}
			case 6:
			{
				server_cmd("zombie_level 6")
				server_cmd("zombie_respawns %d", get_pcvar_num(level6_respawns))
			}
			case 7:
			{
				server_cmd("zombie_level 7")
				server_cmd("zombie_respawns %d", get_pcvar_num(level7_respawns))
			}
			case 8:
			{
				server_cmd("zombie_level 8")
				server_cmd("zombie_respawns %d", get_pcvar_num(level8_respawns))
			}
			case 9:
			{
				server_cmd("zombie_level 9")
				server_cmd("zombie_respawns %d", get_pcvar_num(level9_respawns))
			}
			case 10:
			{
				server_cmd("zombie_level 10")
				server_cmd("zombie_respawns %d", get_pcvar_num(level10_respawns))
			}
		}
	}
	if(tsnum == 0)
	{
		switch(get_pcvar_num(zombie_level))
		{
			case 1:
			{
				server_cmd("zombie_level 2")
				server_cmd("zombie_respawns %d", get_pcvar_num(level2_respawns))
			}
			case 2:
			{ 
				server_cmd("zombie_level 3")
				server_cmd("zombie_respawns %d", get_pcvar_num(level3_respawns))
			}
			case 3:
			{ 
				server_cmd("zombie_level 4")
				server_cmd("zombie_respawns %d", get_pcvar_num(level4_respawns))
			}
			case 4:
			{
				server_cmd("zombie_level 5")
				server_cmd("zombie_respawns %d", get_pcvar_num(level5_respawns))
			}
			case 5:
			{ 
				server_cmd("zombie_level 6")
				server_cmd("zombie_respawns %d", get_pcvar_num(level6_respawns))
			}
			case 6:
			{ 
				server_cmd("zombie_level 7")
				server_cmd("zombie_respawns %d", get_pcvar_num(level7_respawns))
			}
			case 7:
			{
				server_cmd("zombie_level 8")
				server_cmd("zombie_respawns %d", get_pcvar_num(level8_respawns))
			}
			case 8:
			{ 
				server_cmd("zombie_level 9")
				server_cmd("zombie_respawns %d", get_pcvar_num(level9_respawns))
			}
			case 9:
			{ 
				server_cmd("zombie_level 10")
				server_cmd("zombie_respawns %d", get_pcvar_num(level10_respawns))
			}
			case 10:
			{
				set_task(3.0, "new_map")
				server_cmd("zombie_level 1")
				server_cmd("zombie_respawns %d", get_pcvar_num(level1_respawns))
			}
		}
	}  
	if(tsnum == 1)
	{
		switch(get_pcvar_num(zombie_level))
		{
			case 1:
			{ 
				boss_class[ts[0]] = 1
				new tname[32]
				get_user_name(ts[0], tname, 31)
				set_hudmessage(255, 255, 255, -1.0, 0.20, 0, 6.0, 10.0, 0.1, 0.2, 3)
				show_hudmessage(0, "%s is the Boss!", tname)
				client_cmd(0, "spk zombiehell/zh_boss.wav")
				set_user_health(ts[0], get_pcvar_num(level1_bosshp))
				set_user_maxspeed(ts[0], get_pcvar_float(level1_bossmaxspeed))
				server_cmd("zombie_knife 1")
			}
			case 2:
			{ 
				boss_class[ts[0]] = 2
				new tname[32]
				get_user_name(ts[0], tname, 31)
				set_hudmessage(255, 255, 255, -1.0, 0.20, 0, 6.0, 10.0, 0.1, 0.2, 3)
				show_hudmessage(0, "%s is the Boss!", tname)
				client_cmd(0, "spk zombiehell/zh_boss.wav")
				set_user_health(ts[0], get_pcvar_num(level2_bosshp))
				set_user_maxspeed(ts[0], get_pcvar_float(level2_bossmaxspeed))
				server_cmd("zombie_knife 1")
			}
			case 3:
			{ 
				boss_class[ts[0]] = 3
				new tname[32]
				get_user_name(ts[0], tname, 31)
				set_hudmessage(255, 255, 255, -1.0, 0.20, 0, 6.0, 10.0, 0.1, 0.2, 3)
				show_hudmessage(0, "%s is the Boss!", tname)
				client_cmd(0, "spk zombiehell/zh_boss.wav")
				set_user_health(ts[0], get_pcvar_num(level3_bosshp))
				set_user_maxspeed(ts[0], get_pcvar_float(level3_bossmaxspeed))
				server_cmd("zombie_knife 1")
			}
			case 4:
			{ 
				boss_class[ts[0]] = 4
				new tname[32]
				get_user_name(ts[0], tname, 31)
				set_hudmessage(255, 255, 255, -1.0, 0.20, 0, 6.0, 10.0, 0.1, 0.2, 3)
				show_hudmessage(0, "%s is the Boss!", tname)
				client_cmd(0, "spk zombiehell/zh_boss.wav")
				set_user_health(ts[0], get_pcvar_num(level4_bosshp))
				set_user_maxspeed(ts[0], get_pcvar_float(level4_bossmaxspeed))
				server_cmd("zombie_knife 1")
			}
			case 5:
			{ 
				boss_class[ts[0]] = 5
				new tname[32]
				get_user_name(ts[0], tname, 31)
				set_hudmessage(255, 255, 255, -1.0, 0.20, 0, 6.0, 10.0, 0.1, 0.2, 3)
				show_hudmessage(0, "%s is the Boss!", tname)
				client_cmd(0, "spk zombiehell/zh_boss.wav")
				set_user_health(ts[0], get_pcvar_num(level5_bosshp))
				set_user_maxspeed(ts[0], get_pcvar_float(level5_bossmaxspeed))
				server_cmd("zombie_knife 1")
			}
			case 6:
			{ 
				boss_class[ts[0]] = 6
				new tname[32]
				get_user_name(ts[0], tname, 31)
				set_hudmessage(255, 255, 255, -1.0, 0.20, 0, 6.0, 10.0, 0.1, 0.2, 3)
				show_hudmessage(0, "%s is the Boss!", tname)
				client_cmd(0, "spk zombiehell/zh_boss.wav")
				set_user_health(ts[0], get_pcvar_num(level6_bosshp))
				set_user_maxspeed(ts[0], get_pcvar_float(level6_bossmaxspeed))
				server_cmd("zombie_knife 1")
			}
			case 7:
			{ 
				boss_class[ts[0]] = 7
				new tname[32]
				get_user_name(ts[0], tname, 31)
				set_hudmessage(255, 255, 255, -1.0, 0.20, 0, 6.0, 10.0, 0.1, 0.2, 3)
				show_hudmessage(0, "%s is the Boss!", tname)
				client_cmd(0, "spk zombiehell/zh_boss.wav")
				set_user_health(ts[0], get_pcvar_num(level7_bosshp))
				set_user_maxspeed(ts[0], get_pcvar_float(level7_bossmaxspeed))
				server_cmd("zombie_knife 1")
			}
			case 8:
			{ 
				boss_class[ts[0]] = 8
				new tname[32]
				get_user_name(ts[0], tname, 31)
				set_hudmessage(255, 255, 255, -1.0, 0.20, 0, 6.0, 10.0, 0.1, 0.2, 3)
				show_hudmessage(0, "%s is the Boss!", tname)
				client_cmd(0, "spk zombiehell/zh_boss.wav")
				set_user_health(ts[0], get_pcvar_num(level8_bosshp))
				set_user_maxspeed(ts[0], get_pcvar_float(level8_bossmaxspeed))
				server_cmd("zombie_knife 1")
			}
			case 9:
			{ 
				boss_class[ts[0]] = 9
				new tname[32]
				get_user_name(ts[0], tname, 31)
				set_hudmessage(255, 255, 255, -1.0, 0.20, 0, 6.0, 10.0, 0.1, 0.2, 3)
				show_hudmessage(0, "%s is the Boss!", tname)
				client_cmd(0, "spk zombiehell/zh_boss.wav")
				set_user_health(ts[0], get_pcvar_num(level9_bosshp))
				set_user_maxspeed(ts[0], get_pcvar_float(level9_bossmaxspeed))
				server_cmd("zombie_knife 1")
			}
			case 10:
			{ 
				boss_class[ts[0]] = 10
				new tname[32]
				get_user_name(ts[0], tname, 31)
				set_hudmessage(255, 255, 255, -1.0, 0.20, 0, 6.0, 10.0, 0.1, 0.2, 3)
				show_hudmessage(0, "Defeat the final boss!")
				client_cmd(0, "spk zombiehell/zh_boss.wav")
				set_user_health(ts[0], get_pcvar_num(level10_bosshp))
				set_user_maxspeed(ts[0], get_pcvar_float(level10_bossmaxspeed))
				server_cmd("zombie_knife 1")
			}
		}
	}  
	if( cs_get_user_team(victim) == CS_TEAM_T && get_pcvar_num(death_effect) == 1 )
	{
		static Float:FOrigin2[3]
		pev(victim, pev_origin, FOrigin2)
		// Alphablend sprite, move vertically 30 pps, se to spawn at around thigh level
		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, FOrigin2, 0)
		write_byte(TE_SMOKE)
		engfunc(EngFunc_WriteCoord, FOrigin2[0])
		engfunc(EngFunc_WriteCoord, FOrigin2[1]) 
		engfunc(EngFunc_WriteCoord, (FOrigin2[2])) 
		write_short(smokeskele)
		write_byte(7)
		write_byte(1)
		message_end()
	}
}  

public new_map()
{
	new nextmap[32]
	get_cvar_string("amx_nextmap", nextmap, 31)
	server_cmd("changelevel %s", nextmap)
}

public respawn_zombies()
{
	new killzor = read_data(1)
	new zrespawn = read_data(2)
	set_pev(zrespawn, pev_effects, EF_NODRAW)
	pev(zrespawn, pev_origin, g_vecLastOrigin[zrespawn])
	if(get_user_team(zrespawn) == 1)
	{
		if(++g_iRespawnCount[zrespawn] > get_pcvar_num(zombie_respawns))
		{
			return
		}        
		set_task(5.0, "taskRespawn", zrespawn)
	}
	userkill[zrespawn] = 0
	userkill[killzor]++
	new team2 = get_user_team(killzor)
	static name3[33]
	get_user_name(killzor,name3,32)
	set_hudmessage(255, 255, 255, -1.0, 0.30, 0, 6.0, 6.0, 0.1, 0.2, 3)
	if(get_pcvar_num(zombie_scores) == 1)
	{
		switch(userkill[killzor])
		{
			case 5:
			{
				switch(team2)
				{
					case 1:
					{
						client_cmd(0, "spk zombiehell/zh_score.wav")
						show_hudmessage(0, "%s NEEDS MORE SURVIVORS FOR HIS BURGUER!", name3)
					}
					case 2:
					{
						client_cmd(0, "spk zombiehell/zh_score.wav")
						show_hudmessage(0, "%s SEEMS TO BE A ZOMBIE KILLER!", name3)
					}
				}
			}
			case 10:
			{
				switch(team2)
				{
					case 1:
					{
						client_cmd(0, "spk zombiehell/zh_score.wav")
						show_hudmessage(0, "%s NEEDS MORE FRESH MEAT!", name3)
					}
					case 2:
					{
						client_cmd(0, "spk zombiehell/zh_score.wav")
						show_hudmessage(0, "%s IS A CRAZY ZOMBIE HEADHUNTER!", name3)
					}
				}
			}
			case 15:
			{
				switch(team2)
				{
					case 1:
					{
						client_cmd(0, "spk zombiehell/zh_score.wav")
						show_hudmessage(0, "%s IS HUNGRY AND MUST EAT MORE BRAINS!", name3)
					}
					case 2:
					{
						client_cmd(0, "spk zombiehell/zh_score.wav")
						show_hudmessage(0, "%s CANNOT STOP BLOW ZOMBIE HEADS OFF!", name3)
					}
				}
			}
			case 20:
			{
				switch(team2)
				{
					case 1:
					{
						client_cmd(0, "spk zombiehell/zh_score.wav")
						show_hudmessage(0, "%s IS AN ASSASSIN ZOMBIE!", name3)
					}
					case 2:
					{
						client_cmd(0, "spk zombiehell/zh_score.wav")
						show_hudmessage(0, "%s IS A BRAVE SOLDIER!", name3)
					}
				}
			}
			case 25:
			{
				switch(team2)
				{
					case 1:
					{
						client_cmd(0, "spk zombiehell/zh_score.wav")
						show_hudmessage(0, "%s IS A LUNATIC ZOMBIEEE!", name3)
					}
					case 2:
					{
						client_cmd(0, "spk zombiehell/zh_score.wav")
						show_hudmessage(0, "%s IS DEADLY, BETTER YOU RUN ZOMBIES!", name3)
					}
				}
			}
			case 30:
			{
				switch(team2)
				{
					case 1:
					{
						client_cmd(0, "spk zombiehell/zh_score.wav")
						show_hudmessage(0, "%s IS A SURVIVOR SLAYER!", name3)
					}
					case 2:
					{
						client_cmd(0, "spk zombiehell/zh_score.wav")
						show_hudmessage(0, "%s IS A ZOMBIE SLAYER!", name3)
					}
				}
			}
			case 35:
			{
				switch(team2)
				{
					case 1:
					{
						client_cmd(0, "spk zombiehell/zh_score.wav")
						show_hudmessage(0, "%s IS THE KING OF ZOMBIES!", name3)
					}
					case 2:
					{
						client_cmd(0, "spk zombiehell/zh_score.wav")
						show_hudmessage(0, "%s IS THE KING OF SURVIVORS!", name3)
					}
				}
			}
			case 50:
			{
				switch(team2)
				{
					case 1:
					{
						client_cmd(0, "spk zombiehell/zh_score.wav")
						show_hudmessage(0, "%s IS THE GOD OF ZOMBIES!", name3)
					}
					case 2:
					{
						client_cmd(0, "spk zombiehell/zh_score.wav")
						show_hudmessage(0, "%s IS THE GOD OF SURVIVORS!", name3)
					}
				}
			}
		}
	}
}

public taskRespawn(zrespawn)
{
	new cts[32], ts[32], ctsnum, tsnum
	new CsTeams:team
	
	for (new i=1; i<=maxplayers; i++)
	{
		if (!is_user_alive(i))
		{
			continue
		}
		team = cs_get_user_team(i)
		if (team == CS_TEAM_T)
		{
			ts[tsnum++] = i
			} else if (team == CS_TEAM_CT) {
			cts[ctsnum++] = i
		}
	}
	if (tsnum > 1)
	{
		ExecuteHamB(Ham_CS_RoundRespawn, zrespawn)
		engfunc(EngFunc_SetOrigin, zrespawn, g_vecLastOrigin[zrespawn])
	}
}

public fwd_KeyValue(entId, kvd_id)
{
	if(!pev_valid(entId))
		return FMRES_IGNORED
		
	static className[64]
	get_kvd(kvd_id, KV_ClassName, className, 63)

	if(containi(className, "func_bomb_target") != -1
	|| containi(className, "info_bomb_target") != -1
	|| containi(className, "hostage_entity") != -1
	|| containi(className, "monster_scientist") != -1
	|| containi(className, "func_hostage_rescue") != -1
	|| containi(className, "info_hostage_rescue") != -1
	|| containi(className, "info_vip_start") != -1
	|| containi(className, "func_vip_safetyzone") != -1
	|| containi(className, "func_escapezone") != -1)
	engfunc(EngFunc_RemoveEntity, entId)

	return FMRES_HANDLED
}

public fw_setmodel(ent, model[]) 
{
	if (!pev_valid(ent) || !is_user_alive(pev(ent, pev_owner)))
		return FMRES_IGNORED
	
	new Float: duration = 60.0
	
	if (equali(model,"models/w_smokegrenade.mdl"))
	{
		new className[33]
		pev(ent, pev_classname, className, 32)
		
		set_pev(ent, pev_nextthink, get_gametime() + duration)
		set_pev(ent,pev_effects,EF_BRIGHTLIGHT)
	}
	
	return FMRES_IGNORED
}

public fw_think(ent) 
{
	if (!pev_valid(ent) || !is_user_alive(pev(ent, pev_owner)))
		return FMRES_IGNORED
	
	static classname[33]
	pev(ent, pev_classname, classname, sizeof classname - 1)
	static model[33]
	pev(ent, pev_model, model, sizeof model - 1)
	
	if( equal(model, "models/w_smokegrenade.mdl") && equal(classname, "grenade"))
		engfunc(EngFunc_RemoveEntity, ent)
	
	return FMRES_IGNORED
}

/*public event_damage(id)
{
	new bodypart, weapon
	new enemy = get_user_attacker(id, weapon, bodypart)
	if(weapon == CSW_HEGRENADE && cs_get_user_team(id) == CS_TEAM_T && is_user_alive(id)) 
	{
		new Name[33]
		get_user_name(id,Name,32)
		onfire[id] = 1
		ignite_player(id)
		ignite_effects(id)
		client_print(id, print_chat, "You are burning, lol!")
		client_print(enemy, print_chat, "You caught %s on fire!", Name)
		set_task(20.0,"water_timer",id)
	}
}

public water_timer(id)
{
	if(is_user_alive(id))
	{
		onfire[id] = 0
	}
}

public ignite_effects(skIndex)
{
	new kIndex = skIndex
	
	if (is_user_alive(kIndex) && onfire[kIndex])
	{
		new korigin[3]
		get_user_origin(kIndex,korigin)
		
		message_begin( MSG_BROADCAST,SVC_TEMPENTITY)
		write_byte(17)
		write_coord(korigin[0])
		write_coord(korigin[1])
		write_coord(korigin[2])
		write_short(zh_fire)
		write_byte(10)
		write_byte(200)
		message_end()
		
		set_task(0.2, "ignite_effects" ,skIndex)
	}
	else {
		if(onfire[kIndex])
		{
			onfire[kIndex] = 0
		}
	}
	return PLUGIN_CONTINUE
}

public ignite_player(skIndex)
{
	new kIndex = skIndex
	
	if (is_user_alive(kIndex) && onfire[kIndex])
	{
		new korigin[3]
		new players[32]
		new pOrigin[3]
		new kHeath = get_user_health(kIndex)
		get_user_origin(kIndex,korigin)
		
		set_user_health(kIndex,kHeath - 2)
		message_begin(MSG_ONE, gmsgDamage, {0,0,0}, kIndex)
		write_byte(30)
		write_byte(30)
		write_long(1<<21) 
		write_coord(korigin[0]) 
		write_coord(korigin[1]) 
		write_coord(korigin[2])
		message_end()
		
		players[0] = 0 
		pOrigin[0] = 0                
		korigin[0] = 0       
	}
	set_task(2.0, "ignite_player" , skIndex) 
}*/

public class_menu(id)
{
	if (cs_get_user_team(id) == CS_TEAM_CT) 
	{
		new menu = menu_create("\rChoose your class:", "menu_handler")
		menu_additem(menu, "\wUrban", "1", 0)
		menu_additem(menu, "\wGIGN", "2", 0)
		menu_additem(menu, "\wSAS", "3", 0)
		menu_additem(menu, "\wGSG9", "4", 0)
		menu_additem(menu, "\wGuerilla", "5", 0)
		menu_additem(menu, "\wPhoenix", "6", 0)
		menu_additem(menu, "\wLeet", "7", 0)
		menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
		menu_display(id, menu, 0)
	}
}

public menu_handler(id, menu, item)
{
	if( item == MENU_EXIT )
	{
		menu_destroy(menu)
		set_task(0.1, "weapon_menu", id)
		return PLUGIN_HANDLED
	}
	new data[6], iName[64]
	new access, callback
	menu_item_getinfo(menu, item, access, data,5, iName, 63, callback)
	new key = str_to_num(data)
	switch(key)
	{
		case 1:
		{
			player_class[id] = 1
			set_user_health(id, 145)
			set_user_maxspeed(id, 230.0)
		}
		case 2:
		{
			player_class[id] = 2
			set_user_health(id, 130)
			set_user_maxspeed(id, 240.0)
		}
		case 3: 
		{
			player_class[id] = 3
			set_user_health(id, 115)
			set_user_maxspeed(id, 250.0)
		}
		case 4: 
		{
			player_class[id] = 4
			set_user_health(id, 90)
			set_user_maxspeed(id, 275.0)
		}
		case 5: 
		{
			player_class[id] = 5
			set_user_health(id, 140)
			set_user_maxspeed(id, 220.0)
		}
		case 6: 
		{
			player_class[id] = 6
			set_user_health(id, 100)
			set_user_maxspeed(id, 270.0)
		}
		case 7: 
		{
			player_class[id] = 7
			set_user_health(id, 80)
			set_user_maxspeed(id, 280.0)
		}
	}
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

public check_speed(id)
{
	if(player_class[id])
	{
		switch(player_class[id])
		{
			case 1:
			{ 
				set_user_maxspeed(id, 230.0)
			}
			case 2:
			{ 
				set_user_maxspeed(id, 240.0)
			}
			case 3:
			{ 
				set_user_maxspeed(id, 250.0)
			}
			case 4:
			{ 
				set_user_maxspeed(id, 275.0)
			}
			case 5:
			{ 
				set_user_maxspeed(id, 220.0)
			}
			case 6:
			{ 
				set_user_maxspeed(id, 270.0)
			}
			case 7:
			{ 
				set_user_maxspeed(id, 280.0)
			}
		}
	}
	if(zombie_class[id])
	{
		switch(zombie_class[id])
		{
			case 1:
			{
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level1_maxspeed))
			}
			case 2:
			{
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level2_maxspeed))
			}
			case 3: 
			{
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level3_maxspeed))
			}
			case 4: 
			{
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level4_maxspeed))
			}
			case 5: 
			{
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level5_maxspeed))
			}
			case 6: 
			{
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level6_maxspeed))
			}
			case 7: 
			{
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level7_maxspeed))
			}
			case 9:
			{ 
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level8_maxspeed))
			}
			case 8:
			{ 
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level9_maxspeed))
			}
			case 10:
			{ 
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level10_maxspeed))
			}
		}
	}
	if(boss_class[id])
	{
		switch(boss_class[id])
		{
			case 1:
			{
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level1_bossmaxspeed))
			}
			case 2:
			{ 
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level2_bossmaxspeed))
			}
			case 3:
			{ 
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level3_bossmaxspeed))
			}
			case 4:
			{ 
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level4_bossmaxspeed))
			}
			case 5:
			{ 
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level5_bossmaxspeed))
			}
			case 6:
			{ 
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level6_bossmaxspeed))
			}
			case 7:
			{ 
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level7_bossmaxspeed))
			}
			case 9:
			{ 
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level8_bossmaxspeed))
			}
			case 8:
			{ 
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level9_bossmaxspeed))
			}
			case 10:
			{ 
				engclient_cmd(id, "weapon_knife")
				set_user_maxspeed(id, get_pcvar_float(level10_bossmaxspeed))
			}
		}
	}
}

public jointeam(id) 
{
	engclient_cmd(id, "jointeam", "2")
	return PLUGIN_HANDLED
}

public unlimited_ammo(id)
{
    set_pdata_int(id, AMMO_SLOT + read_data(1), 200, 5)
} 

public message_show_menu(msgid, dest, id) {
	if (!should_autojoin(id))
		return PLUGIN_CONTINUE

	static team_select[] = "#Team_Select"
	static menu_text_code[sizeof team_select]
	get_msg_arg_string(4, menu_text_code, sizeof menu_text_code - 1)
	if (!equal(menu_text_code, team_select))
		return PLUGIN_CONTINUE

	set_force_team_join_task(id, msgid)

	return PLUGIN_HANDLED
}

public message_vgui_menu(msgid, dest, id) {
	if (get_msg_arg_int(1) != TEAM_SELECT_VGUI_MENU_ID || !should_autojoin(id))
		return PLUGIN_CONTINUE

	set_force_team_join_task(id, msgid)

	return PLUGIN_HANDLED
}

bool:should_autojoin(id) {
	return (!get_user_team(id) && !is_user_bot(id))
}

set_force_team_join_task(id, menu_msgid) {
	static param_menu_msgid[2]
	param_menu_msgid[0] = menu_msgid
	set_task(AUTO_TEAM_JOIN_DELAY, "task_force_team_join", id, param_menu_msgid, sizeof param_menu_msgid)
}

public task_force_team_join(menu_msgid[], id) {
	if (get_user_team(id))
		return

	static team[2], class[2]
	get_pcvar_string(g_pcvar_team, team, sizeof team - 1)
	get_pcvar_string(g_pcvar_class, class, sizeof class - 1)
	force_team_join(id, menu_msgid[0], team, class)
}

stock force_team_join(id, menu_msgid, /* const */ team[] = "5", /* const */ class[] = "0") {
	static jointeam[] = "jointeam"
	if (class[0] == '0') {
		engclient_cmd(id, jointeam, team)
		return
	}

	static msg_block, joinclass[] = "joinclass"
	msg_block = get_msg_block(menu_msgid)
	set_msg_block(menu_msgid, BLOCK_SET)
	engclient_cmd(id, jointeam, team)
	engclient_cmd(id, joinclass, class)
	set_msg_block(menu_msgid, msg_block)
}
