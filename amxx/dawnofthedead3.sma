#include <amxmodx>
#include <amxmisc>
#include <fun>
#include <fakemeta>
#include <engine>
#include <hamsandwich>
#include <cstrike>

#define VERSION "1.0"
#define SKYNAME "dotd"//zombiehell2

#define ADMIN_HEALTH 175.0
#define ADMIN_SPEED 260.0
#define ADMIN_RELOAD 0.7
#define ADMIN_DAMAGE 1.5

#define BASE_HEALTH 100
#define BASE_SPEED 150
#define MULT_HEALTH 50
#define MULT_SPEED 25

/*
#define BASE_HEALTH 300
#define BASE_SPEED 150
#define MULT_HEALTH 50
#define MULT_SPEED 25
*/

#define OFFSET_WPN_WIN 	  41
#define OFFSET_WPN_LINUX  4

#define DELAY_HEADSHOT 5.0
#define DELAY_NORMAL 3.0

#define MODELCHANGE_DELAY 0.5

enum (+= 5000)
{
	TASK_RESPAWN = 10000,
	TASK_MODELSET,
	TASK_LIGHTUP,
	TASK_ROUND
}

//Custom Content
new const g_szAmbience[][] =
{
	"ch_ls_istru",
	"prod_smbu2",
	"tech1",
	"tech2",
	"tech3",
	"28wl3",
	"mtrx1"
}

#define SND_ROUNDSTART "dotd/town_zombie_call1.wav"

new g_iPerk[33]
new g_iNextPerk[33]

#define MAXPERKS 8
enum
{
	PERK_NONE = -1,
	PERK_DAMAGE,
	PERK_RELOAD,
	PERK_HEALTH,
	PERK_SPEED,
	PERK_KAMAKAZI,
	PERK_PEEPINGTOM,
	PERK_REGEN,
	PERK_SEMICLIP
}

new const g_fPerkColor[MAXPERKS][3] = 
{
	{200, 000, 000},
	{000, 000, 255},
	{255, 255, 255},
	{254, 254, 034},
	{025, 025, 025},
	{146, 110, 174},
	{000, 150, 000},
	{255, 105, 180}
}

new const g_szPerkName[MAXPERKS][] =
{
	"Full Metal Jacket",
	"Speed Loader",
	"Juggernaut",
	"Adrenaline",
	"Out with a Bang",
	"Peeping Tom",
	"On the Mend",
	"Half-Ghost"
}

#define KAMA_RADIUS 330.0
#define KAMA_DAMAGE 1000.0
new g_iGrenade, g_iExplode, g_iDeathEffect
new Float:MaxHP[33]
new bool:g_isNVG[33]

new const g_szZombiePain[][] =
{
	"basebuilder/zombie/pain/beta_1.wav",
	"basebuilder/zombie/pain/beta_2.wav",
	"basebuilder/zombie/pain/beta_3.wav"
}

new const g_szZombieDie[][] =
{
	"basebuilder/zombie/death/beta_1.wav",
	"basebuilder/zombie/death/beta_2.wav",
	"basebuilder/zombie/death/beta_3.wav"
}

new const g_ZombieModels[][] = 
{
	"dotd_beta_tirant"
	//"dotd_beta1-1",
	//"dotd_beta1-2",
	//"dotd_beta1-3"
	//"dotd_crawler_b1"
}

new g_iMaxPlayers, g_msgSayText, g_msgStatusText
new g_fwKeyValue

new bool:g_isConnected[33], bool:g_isAlive[33], bool:g_isZombie[33], bool:g_isBot[33]
new bool:g_isRoundOver
new bool:g_isRoundStarted

new Float:g_fZSpeed, Float:g_fZHealth, Float:g_fDModifier
new g_iPlayerCounter
new g_iZombieSpawns[33]
new g_iZombieLevel = 1
new Float:g_vecLastOrigin[33][3]
new Float:g_vecMainOrigin[3]
new g_iEyes[33]
new g_ent_playermodel[33]
new g_iFriend[33]

new Float:g_ModelsTargetTime, Float:g_RoundStartTime
new g_szPlayerModel[33][32]

new g_iMenuOffset[33]
new g_iMenuOptions[33][8]

#define KEYS_GENERIC (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9)

new const g_szWpnEntNames[][] = { "", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
			"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
			"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
			"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
			"weapon_ak47", "weapon_knife", "weapon_p90" }

const NOCLIP_WPN_BS    = ((1<<2)|(1<<CSW_HEGRENADE)|(1<<CSW_SMOKEGRENADE)|(1<<CSW_FLASHBANG)|(1<<CSW_KNIFE)|(1<<CSW_C4))
const SHOTGUNS_BS    = ((1<<CSW_M3)|(1<<CSW_XM1014))
const m_fInReload = 54
const m_pPlayer = 41
const m_iId = 43
const m_flNextAttack = 83
const m_flTimeWeaponIdle = 48
			
stock const Float:g_fDelay[CSW_P90+1] = {
	0.00, 2.70, 0.00, 2.00, 0.00, 0.55,   0.00, 3.15, 3.30, 0.00, 4.50, 
         2.70, 3.50, 3.35, 2.45, 3.30,   2.70, 2.20, 2.50, 2.63, 4.70, 
         0.55, 3.05, 2.12, 3.50, 0.00,   2.20, 3.00, 2.45, 0.00, 3.40
}
 
stock const g_iReloadAnims[CSW_P90+1] = {
	-1,  5, -1, 3, -1,  6,   -1, 1, 1, -1, 14, 
	4,  2, 3,  1,  1,   13, 7, 4,  1,  3, 
	6, 11, 1,  3, -1,    4, 1, 1, -1,  1}
 
stock const g_iDftMaxClip[CSW_P90+1] = {
	-1,  13, -1, 10,  1,  7,    1, 30, 30,  1,  30, 
	20, 25, 30, 35, 25,   12, 20, 10, 30, 100, 
	8 , 30, 30, 20,  2,    7, 30, 30, -1,  50}
			
public plugin_precache()
{
	register_plugin("Dawn of the Dead", VERSION, "Tirant");
	register_cvar("dotd_version", VERSION, FCVAR_SPONLY|FCVAR_SERVER);
	set_cvar_string("dotd_version", VERSION);
	
	new szCache[64], i
	
	formatex(szCache, charsmax(szCache), "gfx/env/%sft.tga", SKYNAME );
	engfunc(EngFunc_PrecacheGeneric, szCache);
	formatex(szCache, charsmax(szCache), "gfx/env/%sbk.tga", SKYNAME );
	engfunc(EngFunc_PrecacheGeneric, szCache);
	formatex(szCache, charsmax(szCache), "gfx/env/%sup.tga", SKYNAME );
	engfunc(EngFunc_PrecacheGeneric, szCache);
	formatex(szCache, charsmax(szCache), "gfx/env/%sdn.tga", SKYNAME );
	engfunc(EngFunc_PrecacheGeneric, szCache);
	formatex(szCache, charsmax(szCache), "gfx/env/%slf.tga", SKYNAME );
	engfunc(EngFunc_PrecacheGeneric, szCache);
	formatex(szCache, charsmax(szCache), "gfx/env/%srt.tga", SKYNAME );
	engfunc(EngFunc_PrecacheGeneric, szCache);
	
	for (i=0; i<sizeof g_szZombiePain;i++) 	precache_sound(g_szZombiePain[i])
	for (i=0; i<sizeof g_szZombieDie;i++) 	precache_sound(g_szZombieDie[i])
	
	for ( i = 0; i<sizeof g_szAmbience; i++)
	{
		formatex(szCache, charsmax(szCache), "sound/dotd/ambience/%s.mp3", g_szAmbience[i] );
		engfunc(EngFunc_PrecacheGeneric, szCache);
	}

	for (i=0; i<sizeof g_ZombieModels; i++)
	{
		formatex(szCache, charsmax(szCache), "models/player/%s/%s.mdl", g_ZombieModels[i], g_ZombieModels[i] );
		engfunc(EngFunc_PrecacheModel, szCache)
		formatex(szCache, charsmax(szCache), "models/player/%s/%s-8.mdl", g_ZombieModels[i], g_ZombieModels[i] );
		engfunc(EngFunc_PrecacheModel, szCache)
	}

	engfunc(EngFunc_PrecacheSound, SND_ROUNDSTART);
	g_iExplode = precache_model("sprites/fexplo1.spr");
	g_iDeathEffect = precache_model("sprites/effects/dotd_death_beta6.spr");
	
	i = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_fog"));
	DispatchKeyValue(i, "density", "0.003");
	DispatchKeyValue(i, "rendercolor", "15 10 10");
	
	g_fwKeyValue = register_forward(FM_KeyValue, "fw_KeyValue", 1);	
}

public plugin_init()
{
	register_clcmd("say /tirant",	"tirant_func");
	
	register_clcmd("say", 	   	"cmdSay");
	register_clcmd("say_team",	"cmdSay");
	
	register_clcmd("chooseteam",	"clcmd_changeteam");
	register_clcmd("jointeam", 	"clcmd_changeteam");
	register_clcmd("drop", 		"clcmd_drop");
	
	register_logevent("logevent_round_start",2, 	"1=Round_Start")
	register_logevent("logevent_round_end", 2, 	"1=Round_End")
	
	register_event("HLTV", "ev_RoundStart", "a", "1=0", "2=0")
	register_event("AmmoX", "ev_AmmoX", "be", "1=1", "1=2", "1=3", "1=4", "1=5", "1=6", "1=7", "1=8", "1=9", "1=10")
	register_event("NVGToggle", "ev_NVGToggle", "be");
	register_event("StatusValue", "ev_SetTeam", "be", "1=1");
	
	register_message(get_user_msgid("ShowMenu"), "msgShowMenu");
	register_message(get_user_msgid("VGUIMenu"), "msgGUIMenu");
	register_message(get_user_msgid("TextMsg"), "msgRoundEnd")
	register_message(get_user_msgid("StatusValue"), "msgStatusValue")
	
	RegisterHam(Ham_Spawn, "player", "ham_PlayerSpawn_Post", 1)
	//RegisterHam(Ham_Killed, "player", "ham_PlayerKilled")
	for (new i = 1; i < sizeof g_szWpnEntNames; i++)
	{
		if (g_szWpnEntNames[i][0])
			RegisterHam(Ham_Item_Deploy, g_szWpnEntNames[i], "ham_ItemDeploy_Post", 1)
		if( !(NOCLIP_WPN_BS & (1<<i)) && !(SHOTGUNS_BS & (1<<i)))
			RegisterHam(Ham_Weapon_Reload, g_szWpnEntNames[i], "ham_Reload_Post", 1)
	}
	RegisterHam(Ham_Touch, "weapon_shield", "ham_WeaponCleaner_Post", 1)
	RegisterHam(Ham_Touch, "weaponbox", "ham_WeaponCleaner_Post", 1)
	RegisterHam(Ham_TakeDamage, "player", "ham_TakeDamage")
		
	unregister_forward(FM_KeyValue, g_fwKeyValue);
	register_forward(FM_GetGameDescription, "fw_GetGameDescription")
	register_forward(FM_PlayerPreThink, "fw_PlayerPreThink");
	register_forward(FM_PlayerPostThink, "fw_PlayerPostThink");
	register_forward(FM_AddToFullPack, "fw_addToFullPack", 1)
	register_forward(FM_SetModel, "fw_SetModel")	
	register_forward(FM_Think, "fw_Think")
	register_forward(FM_EmitSound, "fw_EmitSound")
	
	register_menucmd(register_menuid("PerksSelect"),KEYS_GENERIC,"perks_pushed")
	
	set_msg_block(get_user_msgid("ClCorpse"), BLOCK_SET)
	set_msg_block(get_user_msgid("RoundTime"), BLOCK_SET)
	
	server_cmd("sv_skyname %s", SKYNAME);
	
	set_lights("c")
	
	g_iMaxPlayers = get_maxplayers()
	g_msgSayText = get_user_msgid("SayText")
	g_msgStatusText = get_user_msgid("StatusText");
	
	task_SetLevel(g_iZombieLevel);
	set_task(1.5,"task_HPRegenLoop",_,_,_,"b")
}

public tirant_func(id)
{
	if (!access(id, ADMIN_LEVEL_A))
	{
		client_print(id, print_center, "Go fuck yourself <3 Tirant")
		return PLUGIN_HANDLED
	}
	
	g_iZombieLevel++
	arrayset(g_iZombieSpawns, g_iZombieLevel/2, 33)
	task_SetLevel(g_iZombieLevel);
	
	return PLUGIN_HANDLED
}

public fw_KeyValue(entId, kvd_id)
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

public task_SetLevel(level)
{
	level-=1
	
	g_fDModifier = ((g_iPlayerCounter-3)/4.0)+1.0
	
	g_fZSpeed = float(clamp(((level*MULT_SPEED) + BASE_SPEED), BASE_SPEED, 350 ))
	g_fZHealth = float(((level*MULT_HEALTH) + BASE_HEALTH))*g_fDModifier
}

public ev_AmmoX(id)
{
	set_pdata_int(id, 376 + read_data(1), 200, 5)
} 

public ev_NVGToggle(id)
	g_isNVG[id] = read_data(1)  ? true : false

public ham_PlayerSpawn_Post(id)
{
	task_LevelHUD()
	
	if (!is_user_alive(id))
		return HAM_IGNORED;
	
	remove_task(id+TASK_RESPAWN)
	
	g_isAlive[id] = true
	g_isZombie[id] = (cs_get_user_team(id) == CS_TEAM_T ? true : false)
	
	if (g_isZombie[id] && !g_isBot[id])
	{
		cs_set_user_team(id, CS_TEAM_CT)
		ExecuteHamB(Ham_CS_RoundRespawn, id)
		
		return PLUGIN_HANDLED;
	}
	
	remove_task(id + TASK_MODELSET)
	if (g_isZombie[id])
	{
		set_pev(id, pev_health, g_fZHealth)
		
		copy(g_szPlayerModel[id], charsmax(g_szPlayerModel[]), g_ZombieModels[random(sizeof g_ZombieModels)])
		fm_set_playermodel_ent(id, g_szPlayerModel[id])
		task_SetEyes(id)
	}
	else
	{
		if (g_iPerk[id] == -1)
			show_perks_menu(id, 0)
		else if (g_iPerk[id] != g_iNextPerk[id])
			g_iPerk[id] = g_iNextPerk[id]
		
		if (access(id, ADMIN_LEVEL_A) || g_iPerk[id] == PERK_HEALTH)
		{
			MaxHP[id] = ADMIN_HEALTH
			set_pev(id, pev_health, ADMIN_HEALTH)
		}
		else
			MaxHP[id] = 100.0
		
		if (g_iPerk[id] == PERK_PEEPINGTOM || access(id, ADMIN_LEVEL_A))
			cs_set_user_nvg(id, 1)
		
		give_item(id, "weapon_smokegrenade")
		give_item(id, "weapon_hegrenade")
				
		//if (g_isCustomModel[id])
		//	fm_reset_user_model(id)
	}
	
	return HAM_HANDLED;
}

stock fm_set_playermodel_ent( id, const modelname[] )
{
	// Make original player entity invisible
	set_pev( id, pev_rendermode, kRenderTransTexture )
	// This is not 0 because it would hide the shadow and some effects when firing weapons
	set_pev( id, pev_renderamt, 1.0 )
    
	// Since we're passing the short model name to the function
	// we need to make the full path out of it
	static modelpath[100]
	formatex( modelpath, charsmax( modelpath ), "models/player/%s/%s.mdl", modelname, modelname )
    
	// Check if the entity assigned to this player exists
	if ( !pev_valid( g_ent_playermodel[id] ) )
	{
		// If it doesn't, proceed to create a new one
		g_ent_playermodel[id] = engfunc( EngFunc_CreateNamedEntity, engfunc( EngFunc_AllocString, "info_target" ) )
        
		// If it failed to create for some reason, at least this will prevent further "Invalid entity" errors...
		if ( !pev_valid( g_ent_playermodel[id] ) ) return;
        
		// Set its classname
		set_pev( g_ent_playermodel[id], pev_classname, "player_model" )
        
		// Make it follow the player
		set_pev( g_ent_playermodel[id], pev_movetype, MOVETYPE_FOLLOW )
		set_pev( g_ent_playermodel[id], pev_aiment, id )
		set_pev( g_ent_playermodel[id], pev_owner, id )
	}
    
	// Entity exists now, set its model
	engfunc( EngFunc_SetModel, g_ent_playermodel[id], modelpath )
}

stock fm_has_custom_model( id ) 
{
	return pev_valid( g_ent_playermodel[id] ) ? true : false; 
}

public task_SetEyes(id)
{
	if( g_isAlive[id] && g_isZombie[id] && !g_iEyes[id]) 
	{ 	
		g_iEyes[id] = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
		
		if ( !pev_valid( g_iEyes[id] ) ) return;
			
		set_pev( g_iEyes[id], pev_classname, "weapon_model" )
		set_pev( g_iEyes[id], pev_movetype, MOVETYPE_FOLLOW )
		set_pev( g_iEyes[id], pev_aiment, id )
		set_pev( g_iEyes[id], pev_owner, id )
		
		new szCache[64]
		formatex(szCache, charsmax(szCache), "models/player/%s/%s-8.mdl", g_szPlayerModel[id], g_szPlayerModel[id] );
		entity_set_model(g_iEyes[id], szCache)
		
		set_rendering(g_iEyes[id], kRenderFxGlowShell, 0, 255, 0, kRenderNormal, 1)
	}
}

public client_death(attacker, victim, wpnindex, hitplace, TK)
{
	if (is_user_alive(victim))
		return PLUGIN_HANDLED;

	remove_task(victim+TASK_LIGHTUP)
		
	g_isAlive[victim] = false;
	
	pev(victim, pev_origin, g_vecLastOrigin[victim]);
	
	if (g_isZombie[victim])
	{
			// Alphablend sprite, move vertically 30 pps, se to spawn at around thigh level
			engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, g_vecLastOrigin[victim], 0)
			write_byte(TE_SMOKE)
			engfunc(EngFunc_WriteCoord, g_vecLastOrigin[victim][0])
			engfunc(EngFunc_WriteCoord, g_vecLastOrigin[victim][1]) 
			engfunc(EngFunc_WriteCoord, (g_vecLastOrigin[victim][2]+18.0)) 
			write_short(g_iDeathEffect)
			write_byte(6)
			write_byte(8)
			message_end()	
	}
	
	if (g_iPerk[victim] == PERK_KAMAKAZI || access(victim, ADMIN_LEVEL_A))
	{
		new iOrigin[3], Float:fOrigin[3], Float:Distance, Float:Damage
		iOrigin[0] = floatround(g_vecLastOrigin[victim][0])
		iOrigin[1] = floatround(g_vecLastOrigin[victim][1])
		iOrigin[2] = floatround(g_vecLastOrigin[victim][2])
				
		message_begin(MSG_BROADCAST,SVC_TEMPENTITY, iOrigin)
		write_byte(TE_EXPLOSION)
		engfunc( EngFunc_WriteCoord,g_vecLastOrigin[victim][0])
		engfunc( EngFunc_WriteCoord,g_vecLastOrigin[victim][1])
		engfunc( EngFunc_WriteCoord,g_vecLastOrigin[victim][2])
		write_short(g_iExplode)
		write_byte(35)
		write_byte(20)
		write_byte(0)
		message_end()
			
		for(new enemy = 1; enemy <= g_iMaxPlayers; enemy++) 
		{
			if ( is_user_alive(enemy) && get_user_team(victim) != get_user_team(enemy) && victim != enemy)
			{
				entity_get_vector( enemy, EV_VEC_origin, fOrigin)
					
				Distance = get_distance_f(g_vecLastOrigin[victim], fOrigin)
					
				if ( Distance <= KAMA_RADIUS )
				{
					Damage = (((Distance / KAMA_RADIUS) * KAMA_DAMAGE) - KAMA_DAMAGE) * -1.0;
						
					if ( Damage > 0.0 )
					{
						ExecuteHam(Ham_TakeDamage, enemy, g_iGrenade, victim, Damage, (1<<24));
					}
				}
			}
		}
	}
	
	switch (g_isZombie[victim])
	{
		case true:
		{
			//if (g_iZombieSpawns[victim])
			//{
			//	g_iZombieSpawns[victim]--
			set_task((hitplace == HIT_HEAD ? DELAY_HEADSHOT : DELAY_NORMAL) , "task_Respawn", victim+TASK_RESPAWN);
			//}
		}
		//case false: g_iPlayerCounter=g_iPlayerCounter
	}
	
	task_LevelHUD()
	
	return PLUGIN_HANDLED;
}

/*public ham_PlayerKilled(victim, attacker, shouldgib)
{
	if (is_user_alive(victim))
		return HAM_IGNORED;
		
	g_isAlive[victim] = false;
	
	pev(victim, pev_origin, g_vecLastOrigin[victim]);
	
	switch (g_isZombie[victim])
	{
		case true:
		{
			g_iCounterZombie--
			set_task((hitplace == HIT_HEAD ? DELAY_HEADSHOT : DELAY_NORMAL) , "task_Respawn", victim+TASK_RESPAWN);
		}
		case false:g_iCounterHuman--
	}
	
	return HAM_HANDLED;
}*/

public ham_ItemDeploy_Post(weapon_ent)
{
	static owner
	owner = get_pdata_cbase(weapon_ent, OFFSET_WPN_WIN, OFFSET_WPN_LINUX);

	static weaponid
	weaponid = cs_get_weapon_id(weapon_ent)
	
	if (g_isZombie[owner] && weaponid == CSW_KNIFE)
	{
		entity_set_string( owner , EV_SZ_weaponmodel , "" ) 
		//new szCache[64]
		//formatex(szCache, charsmax(szCache), "models/player/%s/%s-8.mdl", g_szPlayerModel[owner], g_szPlayerModel[owner] );
		//entity_set_string( owner , EV_SZ_weaponmodel , szCache ) 
	}
	
	if (g_isZombie[owner] && weaponid != CSW_KNIFE)
		engclient_cmd(owner, "weapon_knife")
}

public ham_Reload_Post(iEnt)
{    
	if( get_pdata_int(iEnt, m_fInReload, 4) )
	{
		new id = get_pdata_cbase(iEnt, m_pPlayer, 4)
		if(access(id, ADMIN_LEVEL_A) || g_iPerk[id] == PERK_RELOAD)
		{
			new Float:fDelay = g_fDelay[get_pdata_int(iEnt, m_iId, 4)] * ADMIN_RELOAD
			set_pdata_float(id, m_flNextAttack, fDelay, 5)
			set_pdata_float(iEnt, m_flTimeWeaponIdle, fDelay, 4)
			set_pev(id, pev_frame, 200.0)
		}
	}
}

public ham_WeaponCleaner_Post(iEnt)
	call_think(iEnt)

public ham_TakeDamage(victim, inflictor, attacker, Float:damage, damagebits)
{
	if (!is_valid_ent(victim) || !is_valid_ent(attacker) || !g_isAlive[victim] || !g_isConnected[attacker]) return HAM_IGNORED

	if (access(attacker, ADMIN_LEVEL_A) || g_iPerk[attacker] == PERK_DAMAGE)
		damage*=ADMIN_DAMAGE

	SetHamParamFloat(4, damage)
	return HAM_HANDLED
}
	
	
public fw_GetGameDescription()
{
	forward_return(FMV_STRING, "Dawn of the Dead")
	return FMRES_SUPERCEDE;
}

new bool:g_isSolid[33]
new bool:g_isSemiClip[33]
new g_iPlayers[32], g_iNum, g_iPlayer

public fw_PlayerPreThink(id)
{
	if (!g_isConnected[id])
		return FMRES_IGNORED
	
	/*new Float: fVelocity[3]
	entity_get_vector(id, EV_VEC_velocity, fVelocity)
	
	if (g_isZombie[id] && g_isBot[id] && g_iFriend[id] != 1)
	{
		if(fVelocity[0] == 0.0 || fVelocity[1] == 0.0)
		{
			fVelocity[1] = 10.0
			fVelocity[2] = 220.0
			entity_set_vector(id, EV_VEC_velocity, fVelocity)
		}
	}*/
	
	if (g_isZombie[id] && g_isRoundStarted)
		set_pev(id, pev_maxspeed, g_fZSpeed)
	else if ((access(id, ADMIN_LEVEL_A) || g_iPerk[id] == PERK_SPEED) && g_isRoundStarted)
		set_pev(id, pev_maxspeed, ADMIN_SPEED)
	
	if ((g_iPerk[id] == PERK_PEEPINGTOM || access(id, ADMIN_LEVEL_A)) && g_isNVG[id])
		client_cmd(id, "gl_fog 0")
	else
		client_cmd(id, "gl_fog 1")
	client_cmd(id, "cl_minmodels 0")
		
	if (!g_isAlive[id])
		return FMRES_IGNORED
	

	get_players(g_iPlayers, g_iNum, "a")
	
	static i
	for (i = 0; i < g_iNum; i++)
	{
		g_iPlayer = g_iPlayers[i]
		if (!g_isSemiClip[g_iPlayer])
			g_isSolid[g_iPlayer] = true
		else
			g_isSolid[g_iPlayer] = false
	}
	
	if (g_isSolid[id])
		for (i = 0; i < g_iNum; i++)
		{
			g_iPlayer = g_iPlayers[i]
			
			if (!g_isSolid[g_iPlayer] || g_iPlayer == id/*  || (!access(id, ADMIN_LEVEL_A) && g_iPerk[id] != PERK_SEMICLIP)*/)
				continue
			if (get_user_team(g_iPlayer) != get_user_team(id))
				continue
			
			set_pev(g_iPlayer, pev_solid, SOLID_NOT)
			g_isSemiClip[g_iPlayer] = true
		}
		
	return FMRES_IGNORED
}

public fw_PlayerPostThink(id)
{
	if (!g_isAlive[id])
		return FMRES_IGNORED
	
	get_players(g_iPlayers, g_iNum, "a")
	
	static i
	for (i = 0; i < g_iNum; i++)
	{
		g_iPlayer = g_iPlayers[i]
		if (g_isSemiClip[g_iPlayer])
		{
			set_pev(g_iPlayer, pev_solid, SOLID_SLIDEBOX)
			g_isSemiClip[g_iPlayer] = false
		}
	}
	
	return FMRES_IGNORED
}

public fw_addToFullPack(es, e, ent, host, hostflags, player, pSet)
{
	if ( !player && (ent == g_ent_playermodel[host] || ent == g_iEyes[host]) )
		return FMRES_SUPERCEDE;
		
	if(player)
	{
		if (!g_isZombie[host])
		{
			if (access(host, ADMIN_LEVEL_A))
				set_user_rendering(host, kRenderFxGlowShell, random(255),random(255), random(255), kRenderNormal, 1)
			else if (g_iPerk[host] != -1)
				set_user_rendering(host, kRenderFxGlowShell, g_fPerkColor[g_iPerk[host]][0], g_fPerkColor[g_iPerk[host]][1], g_fPerkColor[g_iPerk[host]][2], kRenderNormal,1)
			else
				set_user_rendering(host, kRenderFxGlowShell, 255, 117, 056, kRenderNormal,1)
		}
		else
			set_user_rendering(ent, kRenderFxNone, 255, 255, 255, kRenderTransTexture, 1)
		
		if (!g_isAlive[host] || !g_isSolid[host])
			return FMRES_IGNORED
		if (get_user_team(ent) != get_user_team(host))
			return FMRES_IGNORED
			
		set_es(es, ES_Solid, SOLID_NOT)
	}
	return FMRES_IGNORED
}

public fw_SetModel(ent, model[]) 
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

public fw_Think(ent) 
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

public fw_EmitSound(id,channel,const sample[],Float:volume,Float:attn,flags,pitch)
{
	if (!is_user_connected(id) || !g_isZombie[id])
		return FMRES_IGNORED;
		
	if(equal(sample[7], "die", 3) || equal(sample[7], "dea", 3))
	{
		emit_sound(id,channel,g_szZombieDie[random(sizeof g_szZombieDie - 1)],volume,attn,flags,pitch)
		return FMRES_SUPERCEDE
	}
	
	if(equal(sample[7], "bhit", 4))
	{
		emit_sound(id,channel,g_szZombiePain[random(sizeof g_szZombiePain - 1)],volume,attn,flags,pitch)
		return FMRES_SUPERCEDE
	}
	
	return FMRES_IGNORED
}

public msgShowMenu(msgid, dest, id) 
{
	if (get_user_team(id) || g_isBot[id])
		return PLUGIN_CONTINUE

	static team_select[] = "#Team_Select"
	static menu_text_code[sizeof team_select]
	get_msg_arg_string(4, menu_text_code, sizeof menu_text_code - 1)
	if (!equal(menu_text_code, team_select))
		return PLUGIN_CONTINUE

	static param_menu_msgid[2]
	param_menu_msgid[0] = msgid
	set_task(0.1, "task_TeamJoin", id, param_menu_msgid, sizeof param_menu_msgid)

	return PLUGIN_HANDLED
}

public msgGUIMenu(msgid, dest, id) 
{
	if (get_msg_arg_int(1) != 2 || get_user_team(id) || g_isBot[id])
		return PLUGIN_CONTINUE
		
	static param_menu_msgid[2]
	param_menu_msgid[0] = msgid
	set_task(0.1, "task_TeamJoin", id, param_menu_msgid, sizeof param_menu_msgid)

	return PLUGIN_HANDLED
}

public msgRoundEnd(const MsgId, const MsgDest, const MsgEntity)
{
	static Message[192]
	get_msg_arg_string(2, Message, 191)

	if (equal(Message, "#Terrorists_Win"))
	{
		set_msg_arg_string(2, "")
		g_isRoundOver = true
		return PLUGIN_HANDLED
	}
	else if (equal(Message, "#CTs_Win"))
	{
		set_msg_arg_string(2, "")
		g_iZombieLevel++
		task_SetLevel(g_iZombieLevel)
		g_isRoundOver = true
		return PLUGIN_HANDLED
	}
	return PLUGIN_HANDLED
}

public clcmd_changeteam(id)
	return PLUGIN_HANDLED;

public clcmd_drop(id)
	return PLUGIN_HANDLED;

public client_putinserver(id)
{
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	g_isConnected[id] = true;
	g_isAlive[id] = false;
	g_isZombie[id] = false;
	g_isBot[id] = is_user_bot(id) ? true : false;
	if (!g_isBot[id]) g_iPlayerCounter++
	g_isNVG[id] = false;
	
	g_iPerk[id] = PERK_NONE
	g_iNextPerk[id] = PERK_NONE
	
	return PLUGIN_HANDLED;
}

public client_disconnect(id)
{
	remove_task(id+TASK_RESPAWN)
	remove_task(id+TASK_LIGHTUP)
	
	g_isConnected[id] = false;
	g_isAlive[id] = false;
	g_isZombie[id] = false;
	if (!g_isBot[id]) g_iPlayerCounter--
	g_isBot[id] = false;
	g_isNVG[id] = false;
	
	if ( g_ent_playermodel[id] )
		remove_entity(g_ent_playermodel[id])
	
	if (g_iEyes[id] )
		remove_entity(g_iEyes[id])
	
	g_iPerk[id] = PERK_NONE
	g_iNextPerk[id] = PERK_NONE
}

public ev_RoundStart()
{
	g_isRoundOver = false
	g_isRoundStarted = false
	arrayset(g_iZombieSpawns, g_iZombieLevel/2, 33)
	
	g_RoundStartTime = get_gametime()
}

new g_iCountDown
public logevent_round_start()
{
	g_isRoundStarted = true
	client_cmd(0, "mp3 play sound/dotd/ambience/%s.mp3", g_szAmbience[random(sizeof g_szAmbience)])
	client_cmd(0, "spk %s", SND_ROUNDSTART)
	
	set_hudmessage(255, 0, 0, -1.0, -1.0, 2, 6.0, 5.0, 0.1, 0.2, 2)
	show_hudmessage(0, "Level %d^nDifficulty Modifier: %f^nHealth: %d Speed: %d", g_iZombieLevel, g_fDModifier, floatround(g_fZHealth), floatround(g_fZSpeed))
	
	task_LevelHUD()

	remove_task(TASK_ROUND)
	set_task(1.0, "task_CountDown", TASK_ROUND,_, _, "b");
	g_iCountDown = 60
}

public task_CountDown()
{
	g_iCountDown--
	new mins = g_iCountDown/60, secs = g_iCountDown%60
	if (g_iCountDown>0)
		client_print(0, print_center, "Next Level in %d:%s%d", mins, (secs < 10 ? "0" : ""), secs)
	else
	{
		g_iZombieLevel++
		task_SetLevel(g_iZombieLevel)
		task_LevelHUD()
		
		client_cmd(0, "mp3 play sound/dotd/ambience/%s.mp3", g_szAmbience[random(sizeof g_szAmbience)])
		client_cmd(0, "spk %s", SND_ROUNDSTART)
		
		set_hudmessage(255, 0, 0, -1.0, -1.0, 2, 6.0, 5.0, 0.1, 0.2, 2)
		show_hudmessage(0, "Level %d^nDifficulty Modifier: %f^nHealth: %d Speed: %d", g_iZombieLevel, g_fDModifier, floatround(g_fZHealth), floatround(g_fZSpeed))
		
		new players[32], num, player
		get_players(players, num)
		for (new i = 0; i < num; i++)
		{
			player = players[i]
			if (is_user_connected(player) && !g_isZombie[player])
			{
				if (is_user_alive(player))
				{
					pev(player, pev_origin, g_vecMainOrigin);
					g_vecMainOrigin[2]+=18.0
					break;
				}
			}
		}
		
		get_players(players, num)
		for (new i = 0; i < num; i++)
		{
			player = players[i]
			if (is_user_connected(player) && !g_isZombie[player])
			{
				if (!is_user_alive(player))
				{
					ExecuteHamB(Ham_CS_RoundRespawn, player)
					engfunc(EngFunc_SetOrigin, player, g_vecMainOrigin)
					
					set_hudmessage(255, 0, 0, -1.0, -1.0, 2, 6.0, 5.0, 0.1, 0.2, 2)
					show_hudmessage(player, "The gods have blessed you with a second chance");
				}
			}
		}
		
		
		g_iCountDown = 60
		return PLUGIN_HANDLED;
	}
	
	new szTimer[32]
	if (g_iCountDown>10)
	{
		if (mins && !secs) num_to_word(mins, szTimer, 31)
		else if (!mins && secs == 30) num_to_word(secs, szTimer, 31)
		else return PLUGIN_HANDLED;
		
		client_cmd(0, "spk ^"fvox/%s %s remaining^"", szTimer, (mins ? "minutes" : "seconds"))
	}
	else
	{
		num_to_word(g_iCountDown, szTimer, 31)
		client_cmd(0, "spk ^"fvox/%s^"", szTimer)
	}
	return PLUGIN_CONTINUE;
}

public logevent_round_end()
{
	remove_task(TASK_ROUND)
}

public task_Respawn(taskid)
{
	if (g_isRoundOver) return PLUGIN_HANDLED;
	
	taskid-=TASK_RESPAWN
	
	g_vecLastOrigin[taskid][2]+=18.0
		
	ExecuteHamB(Ham_CS_RoundRespawn, taskid)
	if (g_isZombie[taskid])
		engfunc(EngFunc_SetOrigin, taskid, g_vecLastOrigin[taskid])

	return PLUGIN_HANDLED;
}

public task_LevelHUD()
{
	set_hudmessage(255, 255, 255, -1.0, 0.0, 0, 600.0, 12.0, 0.1, 0.2, 1);
	show_hudmessage(0, "Level %d", g_iZombieLevel)
}

public task_TeamJoin(menu_msgid[], id) 
{
	if (get_user_team(id))
		return

	static msg_block
	msg_block = get_msg_block(menu_msgid[0])
	set_msg_block(menu_msgid[0], BLOCK_SET)
	engclient_cmd(id, "jointeam", "5")
	engclient_cmd(id, "joinclass", "5")
	set_msg_block(menu_msgid[0], msg_block)
}

stock fm_get_user_model(player, model[], len)
{
	engfunc(EngFunc_InfoKeyValue, engfunc(EngFunc_GetInfoKeyBuffer, player), "model", model, len)
}

stock fm_reset_user_model(player)
{
	g_isCustomModel[player] = false
	dllfunc(DLLFunc_ClientUserInfoChanged, player, engfunc(EngFunc_GetInfoKeyBuffer, player))
}

public show_perks_menu(id,offset)
{
	if (access(id, ADMIN_LEVEL_A))
		return PLUGIN_HANDLED;
		
	if(offset<0) offset = 0

	new keys, curnum, menu[2048]
	for(new i=offset;i<MAXPERKS;i++)
	{
		g_iMenuOptions[id][curnum] = i
		keys += (1<<curnum)
	
		curnum++
		if (g_iPerk[id] == i)
			format(menu,2047,"\y%s^n\r%d. %s", menu, curnum, g_szPerkName[i])
		else
			format(menu,2047,"\y%s^n\w%d. %s", menu, curnum, g_szPerkName[i])
	
		if(curnum==8)
			break;
	}

	format(menu,2047,"\yChoose your perk:^n^n%s^n", menu)
	if(curnum==8 && offset<12)
	{
		keys += (1<<8)
		format(menu,2047,"%s^n\w9. Next",menu)
	}
	if(offset)
	{
		keys += (1<<9)
		format(menu,2047,"%s^n\w0. Back",menu)
	}

	show_menu(id,keys,menu,-1,"PerksSelect")
	
	return PLUGIN_CONTINUE;
}

public perks_pushed(id,key)
{
	if(key<8)
	{
		g_iNextPerk[id] = g_iMenuOptions[id][key]
		if (g_iPerk[id] == PERK_NONE)
		{
			g_iPerk[id] = g_iNextPerk[id]
			print_color(id, "You have selected^x04 %s^x01 as your perk", g_szPerkName[g_iNextPerk[id]])
		}
		else
		{
			print_color(id, "You have selected^x04 %s^x01 as your perk", g_szPerkName[g_iPerk[id]])
			print_color(id, "It will load when you respawn next round")
		}
		g_iMenuOffset[id] = 0
	}
	else
	{
		if(key==8)
			g_iMenuOffset[id] += 8
		if(key==9)
			g_iMenuOffset[id] -= 8
		show_perks_menu(id,g_iMenuOffset[id])
	}

	return ;
}

public cmdSay(id)
{
	if (!g_isConnected[id])
		return PLUGIN_HANDLED;

	new szMessage[32]
	read_args(szMessage, charsmax(szMessage));
	remove_quotes(szMessage);
		
	if(szMessage[0] == '/')
	{
		if (equali(szMessage, "/perks") == 1)
			show_perks_menu(id, 0)
	}
	
	return PLUGIN_CONTINUE;
}

public msgStatusValue()
	set_msg_block(g_msgStatusText, BLOCK_SET);

public ev_SetTeam(id)
	g_iFriend[id] = read_data(2)

public task_HPRegenLoop()
{
	new players[32], num
	get_players(players, num, "ac")
			
	new player, Float:NewHP
	for (new i = 0; i < num; i++)
	{
		player = players[i]

		if(g_iPerk[player] == PERK_REGEN || access(player, ADMIN_LEVEL_A)) 
		{
			if (get_user_health(player)<MaxHP[player])
			{
				NewHP = get_user_health(player) + floatmul(MaxHP[player],0.01)
			
				if(NewHP >= MaxHP[player]) 
					NewHP = MaxHP[player]
				set_user_health(player,floatround(NewHP))
			}
			else
			{
				set_user_health(player,floatround(MaxHP[player]))
			}
		}
	}
	
	return PLUGIN_CONTINUE
}

print_color(target, const message[], any:...)
{
	static buffer[512], i, argscount
	argscount = numargs()
	
	// Send to everyone
	if (!target)
	{
		static player
		for (player = 1; player <= g_iMaxPlayers; player++)
		{
			// Not connected
			if (!g_isConnected[player])
				continue;
			
			// Remember changed arguments
			static changed[5], changedcount // [5] = max LANG_PLAYER occurencies
			changedcount = 0
			
			// Replace LANG_PLAYER with player id
			for (i = 2; i < argscount; i++)
			{
				if (getarg(i) == LANG_PLAYER)
				{
					setarg(i, 0, player)
					changed[changedcount] = i
					changedcount++
				}
			}
			
			// Format message for player
			vformat(buffer, charsmax(buffer), message, 3)
			
			// Send it
			message_begin(MSG_ONE_UNRELIABLE, g_msgSayText, _, player)
			write_byte(player)
			write_string(buffer)
			message_end()
			
			// Replace back player id's with LANG_PLAYER
			for (i = 0; i < changedcount; i++)
				setarg(changed[i], 0, LANG_PLAYER)
		}
	}
	// Send to specific target
	else
	{
		// Format message for player
		vformat(buffer, charsmax(buffer), message, 3)
		
		// Send it
		message_begin(MSG_ONE, g_msgSayText, _, target)
		write_byte(target)
		write_string(buffer)
		message_end()
	}
}
