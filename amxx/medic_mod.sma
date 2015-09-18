#include <amxmodx>
#include <amxmisc>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <engine>
 
#define MAX_MAPITEMS 9999

#define TASKID_PROPANE 12000
#define DMG_HEGRENADE (1<<24)

#define PROPANE_THROW_TIME 0.5
#define PLAYER_MINHP_TO_HEAL 200
 
#define BAR_REMOVE 0

new const g_p_medic_pack_model[] = "models/medic/p_medic.mdl";
new const g_w_medic_pack_model[] = "models/medic/w_medic.mdl";

new const g_p_medic_propane[] = "models/p_propane.mdl";
new const g_w_medic_propane[] = "models/w_propane.mdl";
new const g_v_medic_propane[] = "models/v_propane.mdl";

new const g_medkit_heal[] = "medic/medic_healing.wav";
new const g_medkit_pickup[] = "items/tr_kevlar.wav";

new const medic_mod_dir_name[] = "itemorigin";
 
new bool:g_freezetime
new medic_cvar_heal_hp, medic_cvar_heal_time, medic_cvar_heal_distance,
propane_explo_radius, propane_explo_dmg;
 
new g_ent[33];
new bool:g_healing[33];
new bool:g_being_healed[33];
new bool:g_healing_teammate[33];
new g_ItemToUse[33];
new g_target[33];
new Float: Current_Speed[33];
new g_Launching[33];

new g_msgid_BarTime, explodespr, g_iGrenade;

//new HamHook:g_hTakeDamage
 
new g_max_clients;

// Items Spawn variables
new g_MapItemNum
new g_ConfigsDir[64]
new g_ItemOriginDir[64]
new g_MapItemOrgins[MAX_MAPITEMS+1][3]
new bool:g_Player_Item_Picked[33];
new bool:g_Player_Item_Picked_Pro[33];
new g_MapItemNumPro;
new g_MapItemOrginsPro[MAX_MAPITEMS+1][3];
 
public plugin_precache()
{
	precache_sound(g_medkit_heal)
	precache_sound(g_medkit_pickup)
	precache_model(g_p_medic_pack_model)
	precache_model(g_w_medic_pack_model)
	precache_model(g_p_medic_propane)
	precache_model(g_w_medic_propane)
	precache_model(g_v_medic_propane)
	precache_model("models/rpgrocket.mdl")
	
	explodespr = precache_model("sprites/fexplo1.spr");
}
 
public plugin_init()
{
	register_plugin("Medic Pack", "0.5", "xbatista");
	
	medic_cvar_heal_hp = register_cvar("medic_heal_hp","100")
	medic_cvar_heal_time = register_cvar("medic_heal_time","5")
	medic_cvar_heal_distance = register_cvar("medic_heal_distance","80")
	
	propane_explo_radius = register_cvar("prop_explo_distance","330.0")
	propane_explo_dmg = register_cvar("prop_explode_damage","400.0")
        
	register_forward(FM_CmdStart, "FwdCmdStart");
	
	new szWeaponName[ 24 ];
	for ( new WeaponId = 1; WeaponId <= 30; WeaponId++ )
	{
		if ( get_weaponname ( WeaponId, szWeaponName, charsmax ( szWeaponName ) ) )
		{
			RegisterHam( Ham_CS_Item_GetMaxSpeed , szWeaponName, "Event_ItemGetMaxSpeed", 1 );
		}
	}
	
	RegisterHam( Ham_Player_Duck, "player", "Event_PlayerDuck")
	RegisterHam( Ham_Player_Jump, "player", "Event_PlayerDuck")
	RegisterHam( Ham_TakeDamage, "info_target", "Fwd_DamageEnt" );

	register_logevent("EventRoundStart", 2, "1=Round_Start");
	register_logevent("EventRoundEnd", 2, "1=Round_End");
	register_event("HLTV", "EventNewRound", "a", "1=0", "2=0");
	register_event("TextMsg", "EventGameCommencing", "a", "2=#Game_Commencing", "2=#Game_will_restart_in");
	register_event("CurWeapon",	"Ev_CurWeapon",	"be", "1=1");
 
	register_event("DeathMsg", "event_deathmsgM", "a")
       
	g_msgid_BarTime = get_user_msgid("BarTime");

	register_clcmd("mapitems", "Open_MapItemConfig")
	register_clcmd("say mapitems", "Open_MapItemConfig")
	
	register_clcmd("say pick", "Pick_PlayerMedPropaneUse")
	register_clcmd("say /pick", "Pick_PlayerMedPropaneUse")
	register_clcmd("pick", "Pick_PlayerMedPropaneUse")
		
	register_touch("MedItem", "player", "Pickup_Items")
	register_touch("PropItem", "player", "Pickup_Items_Propane")
	
	g_iGrenade = create_entity("grenade")
	
	g_max_clients = get_maxplayers();
}

public client_disconnect(client)
{
	g_Player_Item_Picked[client] = false;
	g_Player_Item_Picked_Pro[client] = false;
	
	g_ItemToUse[client] = 0;
}

public plugin_cfg( )
{
	get_configsdir(g_ConfigsDir, 63)
	format(g_ItemOriginDir, 63, "%s/%s", g_ConfigsDir, medic_mod_dir_name)
	
	if(!dir_exists(g_ItemOriginDir)) 
	{
		mkdir(g_ItemOriginDir)
	} 
	else 
	{
		new CurMap[32]
		get_mapname(CurMap, 31)
		Load_Origins(CurMap)
		Load_Origins_Propane(CurMap)
	}
}
public Event_ItemGetMaxSpeed ( const WeapIndex )
{
	if ( !pev_valid( WeapIndex ) )
		return HAM_IGNORED;
	
	new PlayerId = get_pdata_cbase( WeapIndex, 41, 4 );
	if ( (1 <= PlayerId <= g_max_clients) )
	{
		GetOrigHamReturnFloat( Current_Speed[ PlayerId ] );
	}
	
	return HAM_IGNORED;
}
public Event_PlayerDuck( id )
{
	if ( !is_user_alive(id) ) return HAM_IGNORED;
	
	if ( g_healing[id] )
	{
		set_pev(id, pev_oldbuttons, pev(id, pev_oldbuttons) | IN_DUCK)
		set_pev(id, pev_oldbuttons, pev(id, pev_oldbuttons) | IN_JUMP)
	}
	if ( g_being_healed[g_target[id]] )
	{
		set_pev(g_target[id], pev_oldbuttons, pev(g_target[id], pev_oldbuttons) | IN_DUCK)
		set_pev(g_target[id], pev_oldbuttons, pev(g_target[id], pev_oldbuttons) | IN_JUMP)
	}
	
	return HAM_IGNORED;
} 
public Fwd_DamageEnt(ent, inflictor, attacker, Float:damage, damagebits)
{
	if( !pev_valid(ent) || !is_user_connected(attacker) ) return HAM_IGNORED;
	
	new Float:fOrigin[3], iOrigin[3], Float: Torigin[3], Float: Distance, Float: Damage;
	entity_get_vector( ent, EV_VEC_origin, fOrigin);
	
	new Classname[32];
	entity_get_string( ent, EV_SZ_classname, Classname, charsmax(Classname) );
	
	if( !equal (Classname, "PropItem") )
		return HAM_IGNORED
	
	if ( damagebits & DMG_HEGRENADE || get_user_weapon(attacker) == CSW_KNIFE )
	{
		SetHamParamFloat(4, 0.0);
		return HAM_HANDLED;
	}
	
	if ( entity_get_float( ent, EV_FL_health) - damage < 1.0 )
	{
		iOrigin[0] = floatround(fOrigin[0])
		iOrigin[1] = floatround(fOrigin[1])
		iOrigin[2] = floatround(fOrigin[2])
				
		message_begin(MSG_BROADCAST,SVC_TEMPENTITY, iOrigin)
		write_byte(TE_EXPLOSION)
		engfunc( EngFunc_WriteCoord,fOrigin[0])
		engfunc( EngFunc_WriteCoord,fOrigin[1])
		engfunc( EngFunc_WriteCoord,fOrigin[2])
		write_short(explodespr)
		write_byte(35)
		write_byte(20)
		write_byte(0)
		message_end()
			
		for(new enemy = 1; enemy <= g_max_clients; enemy++) 
		{
			if ( is_user_alive(enemy) && get_user_team(attacker) != get_user_team(enemy) && attacker != enemy)
			{
				entity_get_vector( enemy, EV_VEC_origin, Torigin)
					
				Distance = get_distance_f(fOrigin, Torigin)
					
				if ( Distance <= get_pcvar_float(propane_explo_radius) )
				{
					Damage = (((Distance / get_pcvar_float(propane_explo_radius)) * get_pcvar_float(propane_explo_dmg)) - get_pcvar_float(propane_explo_dmg)) * -1.0;
						
					if ( Damage > 0.0 )
					{
						ExecuteHam(Ham_TakeDamage, enemy, g_iGrenade, attacker, Damage, DMG_HEGRENADE);
					}
				}
			}
		}
	}
	
	return HAM_IGNORED;
}

public FwdCmdStart(client, uc_handle, seed)
{
	if( !is_user_alive(client) || get_user_team(client) == 1 ) return FMRES_IGNORED;
			
	new button = get_uc(uc_handle, UC_Buttons);
	new oldbuttons = pev(client, pev_oldbuttons);
	static target, body;
	new Float:aim_distance = get_user_aiming(client, target, body);
	new model[33];
	pev(client, pev_viewmodel2, model, 32);

	if ( !g_ItemToUse[client] )
	{
		if ( g_being_healed[client] || !g_Player_Item_Picked[client] )
			return FMRES_IGNORED;
		
		if ( (button & IN_USE) && !(oldbuttons & IN_USE) && aim_distance <= get_pcvar_float(medic_cvar_heal_distance) )
		{
			if( is_user_alive(target) && !g_being_healed[target] && !g_healing[client] 
			&& pev(target, pev_health) <= PLAYER_MINHP_TO_HEAL )
			{
				static name[32] ; get_user_name(target, name, charsmax(name));
				static name2[32] ; get_user_name(client, name2, charsmax(name2));
				client_print(client, print_center, "Your target: %s", name);
				client_print(target, print_center, "You being healed", name2);
							
				emit_sound(target, CHAN_ITEM, g_medkit_heal, 1.0, ATTN_NORM, 0, PITCH_NORM);
				if( g_freezetime )
				{
					static Float:last[33];
					new Float:gametime = get_gametime();
													
					if( gametime >= last[client] )
					{
						client_print(client,  print_center, "You cannot heal at this time.");
						last[client] = gametime + 0.2;
					}
													
					return FMRES_IGNORED;
				}
											
				g_healing_teammate[client] = true;
				g_healing[client] = true;
				g_target[client] = target;
									
				g_being_healed[target] = true;
				
				set_user_maxspeed(client, 0.1)
				set_user_maxspeed(target, 0.1)
				

				ManageBar(client, get_pcvar_num(medic_cvar_heal_time));
				ManageBar(target, get_pcvar_num(medic_cvar_heal_time));
											
				set_view(client,CAMERA_3RDPERSON);
											
				set_task(get_pcvar_float(medic_cvar_heal_time), "TaskFinishHeal", client);
			}
		}
		else if( g_healing[client] && !(button & IN_USE) )
		{
			g_healing[client] = false;
									
			g_being_healed[g_target[client]] = false;
					
			ManageBar(client, BAR_REMOVE);
			ManageBar(g_target[client], BAR_REMOVE);
									
			set_view(client,CAMERA_NONE);
			
			set_user_maxspeed(client, Current_Speed[client])
			if ( is_user_alive(g_target[client]) )
			{
				set_user_maxspeed(g_target[client], Current_Speed[g_target[client]])
			}
									
			remove_task(client);
		}

		if( (button & IN_USE) && !(oldbuttons & IN_USE) )
		{
			if( !g_being_healed[client] && !g_healing[client] 
			&& pev(client, pev_health) <= PLAYER_MINHP_TO_HEAL  )
			{
				emit_sound(client, CHAN_ITEM, g_medkit_heal, 1.0, ATTN_NORM, 0, PITCH_NORM);
				if( g_freezetime )
				{
					static Float:last[33];
					new Float:gametime = get_gametime();
											
					if( gametime >= last[client] )
					{
						client_print(client, print_chat, "You cannot heal at this time.");
						last[client] = gametime + 0.2;
					}
											
					return FMRES_IGNORED;
				}
									
				g_healing_teammate[client] = false;
				g_being_healed[client] = false;
				g_healing[client] = true;
				
				set_user_maxspeed(client, 0.1)
									
				if ( !(button & IN_JUMP) && !(button & IN_DUCK) && !(button & IN_FORWARD) && !(button & IN_BACK) &&
				!(button & IN_MOVELEFT) && !(button & IN_MOVERIGHT) && !(button & IN_ATTACK) && !(button & IN_ATTACK2))
				{
					client_print(client,  print_center, "Healing Self");
				}
				
				ManageBar(client, get_pcvar_num(medic_cvar_heal_time));
									
				set_view(client,CAMERA_3RDPERSON);
									
				set_task(get_pcvar_float(medic_cvar_heal_time), "TaskFinishHeal2", client);
			}
		}
		else if ( !(button & IN_USE) )
		{
			g_healing[client] = false;
			
			set_user_maxspeed(client, Current_Speed[client])

			ManageBar(client, BAR_REMOVE);
							
			set_view(client,CAMERA_NONE);
							
			remove_task(client);
		}
	}
	else
	{
		if ( !g_Player_Item_Picked_Pro[client] )
			return FMRES_IGNORED;
		
		if ( (button & IN_USE) && !(oldbuttons & IN_USE) && !g_freezetime && !g_Launching[client])
		{
			g_Launching[client] = true;
			
			engclient_cmd(client, "weapon_knife");
			set_pev(client, pev_viewmodel2, g_v_medic_propane);
			set_pev(client, pev_weaponmodel2, g_p_medic_propane);
			
			fm_set_animation(client, 3)
			set_task( PROPANE_THROW_TIME, "Create_Items_Propane_Throw", client + TASKID_PROPANE);
		}
		else if ( !(button & IN_USE) )
		{
			g_Launching[client] = false;
			
			if (equali(model, g_v_medic_propane))
			{
				engclient_cmd(client, "weapon_knife");
				set_pev(client, pev_weaponmodel2, "models/p_knife.mdl");
				set_pev(client, pev_viewmodel2, "models/v_knife.mdl");
			}
			
			remove_task(client + TASKID_PROPANE);
		}
	}
			
	return FMRES_IGNORED;
}

public EventRoundStart()
{
	g_freezetime = false;
}

public EventNewRound()
{
	Spawn_Items()
	Spawn_Items_Propane()
	
	g_freezetime = true;
}
 
public EventRoundEnd()
{
	for(new id = 1; id <= g_max_clients; id++) 
	{ 
		if( pev_valid(g_ent[id]) )
		{
			engfunc(EngFunc_RemoveEntity, g_ent[id]);
			g_ent[id] = 0;
		}
		
		g_Player_Item_Picked[id] = false;
		g_Player_Item_Picked_Pro[id] = false;
	}
	
	remove_items()
	remove_items_pro()
}
public EventGameCommencing()
{
	for(new id = 1; id <= g_max_clients; id++) 
	{
		g_Player_Item_Picked[id] = false;
		g_Player_Item_Picked_Pro[id] = false;
	}
}
public Ev_CurWeapon(id)
{
	if( !is_user_alive(id) )
		return PLUGIN_HANDLED;
	
	new Weapon = read_data(2)
	
	if ( Weapon != CSW_KNIFE )
	{
		if ( g_Launching[id] )
		{
			g_Launching[id] = false;
			
			remove_task(id + TASKID_PROPANE);
		}
	}
	
	return PLUGIN_CONTINUE;
}
	

public remove_items()
{
	new items = find_ent_by_class(-1, "MedItem")
	while(items) 
	{
		remove_entity(items)
		items = find_ent_by_class(items, "MedItem")
	}
}
public remove_items_pro()
{
	new items = find_ent_by_class(-1, "PropItem")
	while(items) 
	{
		remove_entity(items)
		items = find_ent_by_class(items, "PropItem")
	}
}

public Open_MapItemConfig(id)
{
	if ( get_user_flags(id) & ADMIN_RCON )
	{
		new menu = menu_create("Map Item Menu" , "map_item_menu");
		menu_additem(menu ,"Create MedKit \yby Aim", "1" , 0); 
		menu_additem(menu ,"Remove All MedKits", "2" , 0); 
		menu_additem(menu ,"Create Propane tank \yby Aim", "3" , 0); 
		menu_additem(menu ,"Remove All Propane tanks", "4" , 0); 
		
		menu_setprop(menu , MPROP_EXIT , MEXIT_ALL);
		menu_display(id , menu , 0); 
	}
	
	return PLUGIN_HANDLED;
}
public map_item_menu(id , menu , item) 
{ 
	if(item == MENU_EXIT) 
	{ 
		menu_destroy(menu); 
		return PLUGIN_HANDLED;
	} 
	new data[6], iName[64];
	new MapName[33]
	get_mapname(MapName, 32)
	new access, callback;
	menu_item_getinfo(menu, item, access, data,5, iName, 63, callback);

	new key = str_to_num(data);
	
	switch(key) 
	{
		case 1:
		{
			if(g_MapItemNum >= MAX_MAPITEMS)
			{
				client_print(id, print_chat, "Max map items reached!")
				return PLUGIN_HANDLED
			}
			
			new Origin[3]
			get_user_origin(id, Origin, 3)

			Create_Items(Origin)
			Save_Origin(MapName, Origin)
			Load_Origins(MapName)
			
			Open_MapItemConfig(id)
			client_print(id, print_chat, "Item spawn point created by aim!")
		}
		case 2: 
		{
			RemoveMapItems()
			remove_items()
			client_print(id, print_chat, "All spawn points removed!")
		}
		case 3:
		{
			if(g_MapItemNumPro >= MAX_MAPITEMS)
			{
				client_print(id, print_chat, "Max map items(Propane) reached!")
				return PLUGIN_HANDLED
			}
			
			new Origin[3]
			get_user_origin(id, Origin, 3)

			Create_Items_Propane_Idle(Origin)
			Save_Origin_Propane(MapName, Origin)
			Load_Origins_Propane(MapName)
			
			Open_MapItemConfig(id)
			client_print(id, print_chat, "Item spawn point created by aim! (Propane)")
		}
		case 4: 
		{
			RemoveMapItems_Propane()
			remove_items_pro()
			client_print(id, print_chat, "All spawn points removed! (Propane)")
		}
	}
	
	menu_destroy(menu); 
	return PLUGIN_HANDLED;
}
public Pick_PlayerMedPropaneUse(id)
{
	if ( is_user_connected(id) )
	{
		new menu = menu_create("Pick Item to use :" , "PlayerMedPropaneUse");

		if ( g_Player_Item_Picked[id] )
		{
			menu_additem(menu ,"Medkit", "1" , 0); 
		}
		else
		{
			menu_additem(menu, "Medkit", "999", 0, menu_makecallback("CallbackMenu"));
		}

		if ( g_Player_Item_Picked_Pro[id] )
		{
			menu_additem(menu ,"Propane tank", "2" , 0);
		} 
		else
		{
			menu_additem(menu, "Propane tank", "999", 0, menu_makecallback("CallbackMenu"));
		}

		menu_setprop(menu , MPROP_EXIT , MEXIT_ALL);
		menu_display(id , menu , 0); 
	}
	
	return PLUGIN_HANDLED;
}
public PlayerMedPropaneUse(id , menu , item) 
{ 
	if(item == MENU_EXIT) 
	{ 
		menu_destroy(menu); 
		return PLUGIN_HANDLED;
	} 
	new data[6], iName[64];
	new MapName[33]
	get_mapname(MapName, 32)
	new access, callback;
	menu_item_getinfo(menu, item, access, data,5, iName, 63, callback);

	new key = str_to_num(data);
	
	switch(key) 
	{
		case 1:
		{
			g_ItemToUse[id] = 0
		}
		case 2:
		{
			g_ItemToUse[id] = 1
		}
	}
	
	menu_destroy(menu); 
	return PLUGIN_HANDLED;
}
public CallbackMenu(id, menu, item) 
{ 
    return ITEM_DISABLED; 
}

public Pickup_Items(ptr, ptd)
{
	if( is_user_alive(ptd) && pev_valid(ptr) && !g_Player_Item_Picked[ptd] && get_user_team(ptd) == 2 ) 
	{ 	
		g_Player_Item_Picked[ptd] = true;
		g_ItemToUse[ptd] = 0
		emit_sound(ptd, CHAN_ITEM, g_medkit_pickup, 1.0, ATTN_NORM, 0, PITCH_NORM);
		
		new ent = create_entity("info_target");
					
		entity_set_model(ent, g_p_medic_pack_model)
					
		entity_set_int(ent, EV_INT_movetype, MOVETYPE_FOLLOW)
		entity_set_edict(ent, EV_ENT_aiment, ptd );
					
		g_ent[ptd] = ent;
					
		remove_entity(ptr)
	}
}
public Pickup_Items_Propane(ptr, ptd)
{
	if( is_user_alive(ptd) && pev_valid(ptr) && !g_Player_Item_Picked_Pro[ptd] && get_user_team(ptd) == 2 ) 
	{ 	
		g_Player_Item_Picked_Pro[ptd] = true;
		g_ItemToUse[ptd] = 1
		emit_sound(ptd, CHAN_ITEM, g_medkit_pickup, 1.0, ATTN_NORM, 0, PITCH_NORM);
		
		remove_entity(ptr)
	}
}

Save_Origin(CurMap[], Origin[3])
{	
	new MapFile[64], Text[64]
	format(MapFile, 63, "%s/%s.cfg", g_ItemOriginDir, CurMap)
	if(!file_exists(MapFile)) 
	{
		new Comments[64]
		format(Comments, 63, "; Map item origins for %s", CurMap)
		write_file(MapFile, Comments, -1)
	}
	
	format(Text, 63, "%i %i %i", Origin[0], Origin[1], Origin[2])
	write_file(MapFile, Text, -1)
}
Save_Origin_Propane(CurMap[], Origin[3])
{	
	new MapFile[64], Text[64]
	format(MapFile, 63, "%s/%s_propane.cfg", g_ItemOriginDir, CurMap)
	if(!file_exists(MapFile)) 
	{
		new Comments[64]
		format(Comments, 63, "; Map item origins for %s Propane", CurMap)
		write_file(MapFile, Comments, -1)
	}
	
	format(Text, 63, "%i %i %i", Origin[0], Origin[1], Origin[2])
	write_file(MapFile, Text, -1)
}

Load_Origins(CurMap[])
{
	new MapFile[64]
	format(MapFile, 63, "%s/%s.cfg", g_ItemOriginDir, CurMap)
	if(!file_exists(MapFile))
		return PLUGIN_CONTINUE;

	g_MapItemNum = 0
	for(new i = 1; i <= MAX_MAPITEMS; ++i) 
	{
		g_MapItemOrgins[i][0] = 0
		g_MapItemOrgins[i][1] = 0
		g_MapItemOrgins[i][2] = 0
	}
	
	new Text[64], Line = 0, Len = 0
	while(read_file(MapFile, Line++, Text, 63, Len))
	{
		if((Text[0]==';') || !Len) {
		 	continue
		}
		
		if(g_MapItemNum >= MAX_MAPITEMS) 
		{
			log_amx("Max map items reached, please increase MAX_MAPITEMS")
			break
		}
		
		new iOrigin[3][16]
		parse(Text, iOrigin[0], 15, iOrigin[1], 15, iOrigin[2], 15)
		
		g_MapItemNum++
		g_MapItemOrgins[g_MapItemNum][0] = str_to_num(iOrigin[0])
		g_MapItemOrgins[g_MapItemNum][1] = str_to_num(iOrigin[1])
		g_MapItemOrgins[g_MapItemNum][2] = str_to_num(iOrigin[2])
	}
	
	return PLUGIN_CONTINUE
}
Load_Origins_Propane(CurMap[])
{
	new MapFile[64]
	format(MapFile, 63, "%s/%s_propane.cfg", g_ItemOriginDir, CurMap)
	if( !file_exists(MapFile) )
		return PLUGIN_CONTINUE;

	g_MapItemNumPro = 0
	for(new i = 1; i <= MAX_MAPITEMS; ++i) 
	{
		g_MapItemOrginsPro[i][0] = 0
		g_MapItemOrginsPro[i][1] = 0
		g_MapItemOrginsPro[i][2] = 0
	}
	
	new Text[64], Line = 0, Len = 0
	while(read_file(MapFile, Line++, Text, 63, Len))
	{
		if((Text[0]==';') || !Len) {
		 	continue
		}
		
		if(g_MapItemNumPro >= MAX_MAPITEMS) 
		{
			log_amx("Max map items reached, please increase MAX_MAPITEMS")
			break
		}
		
		new iOrigin[3][16]
		parse(Text, iOrigin[0], 15, iOrigin[1], 15, iOrigin[2], 15)
		
		g_MapItemNumPro++
		g_MapItemOrginsPro[g_MapItemNumPro][0] = str_to_num(iOrigin[0])
		g_MapItemOrginsPro[g_MapItemNumPro][1] = str_to_num(iOrigin[1])
		g_MapItemOrginsPro[g_MapItemNumPro][2] = str_to_num(iOrigin[2])
	}
	
	return PLUGIN_CONTINUE
}

public Spawn_Items()
{
	for(new i = 1; i <= MAX_MAPITEMS; ++i)
	{
		if((g_MapItemOrgins[i][0] == 0) 
		&& (g_MapItemOrgins[i][1] == 0) 
		&& g_MapItemOrgins[i][2] == 0) { 
				continue
		}
		Create_Items(g_MapItemOrgins[i])
	}
}
public Spawn_Items_Propane()
{
	for(new i = 1; i <= MAX_MAPITEMS; ++i)
	{
		if((g_MapItemOrginsPro[i][0] == 0) 
		&& (g_MapItemOrginsPro[i][1] == 0) 
		&& g_MapItemOrginsPro[i][2] == 0) { 
				continue
		}
		Create_Items_Propane_Idle(g_MapItemOrginsPro[i])
	}
}

RemoveMapItems()
{
	new MapFile[64], CurMap[32]
	get_mapname(CurMap, 31)
	format(MapFile, 63, "%s/%s.cfg", g_ItemOriginDir, CurMap)
	if(file_exists(MapFile)) {
		delete_file(MapFile)
	}

	g_MapItemNum = 0
	for(new i = 1; i <= MAX_MAPITEMS; ++i) 
	{
		g_MapItemOrgins[i][0] = 0
		g_MapItemOrgins[i][1] = 0
		g_MapItemOrgins[i][2] = 0
	}
}
RemoveMapItems_Propane()
{
	new MapFile[64], CurMap[32]
	get_mapname(CurMap, 31)
	format(MapFile, 63, "%s/%s_propane.cfg", g_ItemOriginDir, CurMap)
	if(file_exists(MapFile)) {
		delete_file(MapFile)
	}

	g_MapItemNumPro = 0
	for(new i = 1; i <= MAX_MAPITEMS; ++i) 
	{
		g_MapItemOrginsPro[i][0] = 0
		g_MapItemOrginsPro[i][1] = 0
		g_MapItemOrginsPro[i][2] = 0
	}
}

Create_Items(Origin[3])
{
	new Float:flOrigin[3]
	IVecFVec(Origin, flOrigin)
	
	new Float:fGlowColors[3] = {80.0, 0.0, 255.0}
	new item_ent = create_entity("info_target")
	if(pev_valid(item_ent))
	{
		entity_set_string(item_ent, EV_SZ_classname, "MedItem")
				
		entity_set_int(item_ent, EV_INT_solid, SOLID_TRIGGER)
		entity_set_int(item_ent, EV_INT_movetype, MOVETYPE_TOSS)
		entity_set_int(item_ent, EV_ENT_owner, 0)
		entity_set_int(item_ent, EV_INT_renderfx, kRenderFxGlowShell)
		entity_set_vector(item_ent, EV_VEC_rendercolor, fGlowColors)

		drop_to_floor(item_ent)
		entity_set_vector(item_ent, EV_VEC_origin, flOrigin)
		
		entity_set_model(item_ent, g_w_medic_pack_model)
		entity_set_size(item_ent, Float:{-2.5, -2.5, -1.5}, Float:{2.5, 2.5, 1.5})
	}
}
Create_Items_Propane_Idle(Origin[3])
{
	new Float:flOrigin[3]
	IVecFVec(Origin, flOrigin)
	
	new Float:fGlowColors[3] = {80.0, 0.0, 255.0}
	new item_ent = create_entity("info_target")
	
	if ( !pev_valid(item_ent) )
		return

	entity_set_string(item_ent, EV_SZ_classname, "PropItem")
	
	entity_set_float( item_ent, EV_FL_takedamage, 1.0);
	entity_set_float( item_ent, EV_FL_health, 100.0);
				
	entity_set_int(item_ent, EV_INT_solid, SOLID_TRIGGER)
	entity_set_int(item_ent, EV_INT_movetype, MOVETYPE_TOSS)
	entity_set_float(item_ent, EV_FL_gravity, 0.55);
	entity_set_int(item_ent, EV_INT_renderfx, kRenderFxGlowShell)
	entity_set_vector(item_ent, EV_VEC_rendercolor, fGlowColors)

	drop_to_floor(item_ent)
	entity_set_vector(item_ent, EV_VEC_origin, flOrigin)
		
	entity_set_model(item_ent, g_w_medic_propane)
	entity_set_size(item_ent, Float:{-3.5, -5.5, -8.5}, Float:{3.5, 5.5, 8.5})
}
public Create_Items_Propane_Throw(id)
{
	id -= TASKID_PROPANE
	
	if ( !is_user_alive(id) || !g_Player_Item_Picked_Pro[id] )
		return;
	
	g_Player_Item_Picked_Pro[id] = false;
	fm_set_animation(id, 2);
	
	emit_sound(id, CHAN_ITEM, g_medkit_pickup, 1.0, ATTN_NORM, 0, PITCH_NORM);
	
	new Float: fOrigin[3], Float:fAngle[3],Float: fVelocity[3];

	entity_get_vector( id, EV_VEC_origin, fOrigin);
	entity_get_vector( id, EV_VEC_view_ofs, fAngle);

	fOrigin[0] += fAngle[0];
	fOrigin[1] += fAngle[1];
	fOrigin[2] += fAngle[2] + 35.0;
	
	fm_velocity_by_aim(id, 0.8, fVelocity, fAngle);
	fAngle[0] *= -1.0;
	
	new item_ent = create_entity("info_target");

	entity_set_string( item_ent, EV_SZ_classname, "PropItem");
	
	entity_set_float( item_ent, EV_FL_takedamage, 1.0);
	entity_set_float( item_ent, EV_FL_health, 20.0);
	
	entity_set_int( item_ent, EV_INT_solid, SOLID_BBOX)
	entity_set_int( item_ent, EV_INT_movetype, MOVETYPE_TOSS)
	entity_set_float( item_ent, EV_FL_gravity, 0.55);
	
	entity_set_int(item_ent, EV_INT_renderfx, kRenderFxGlowShell)
	entity_set_vector(item_ent, EV_VEC_rendercolor, Float:{80.0, 0.0, 255.0})
	
	entity_set_vector( item_ent, EV_VEC_origin, fOrigin);

	fOrigin[0] += fVelocity[0];
	fOrigin[1] += fVelocity[1];
	fOrigin[2] += fVelocity[2];
	
	fVelocity[0] *= 1000.0;
	fVelocity[1] *= 1000.0;
	fVelocity[2] *= 1000.0;

	entity_set_vector( item_ent, EV_VEC_velocity, fVelocity);
	entity_set_vector( item_ent, EV_VEC_angles, fAngle);
	
	entity_set_model( item_ent, g_w_medic_propane);

	entity_set_size(item_ent, Float:{-3.5, -5.5, -8.5}, Float:{3.5, 5.5, 8.5})
	
	set_task(0.5, "Set_Back_Model", id);
}

public Set_Back_Model(id)
{
	if ( is_user_alive(id) )
	{
		new model[33];
		pev(id, pev_viewmodel2, model, 32);
		
		if (equali(model, g_v_medic_propane))
		{
			engclient_cmd(id, "weapon_knife");
			set_pev(id, pev_weaponmodel2, "models/p_knife.mdl");
			set_pev(id, pev_viewmodel2, "models/v_knife.mdl");
		}
	}
}
 
public event_deathmsgM()
{
	if( !(1 <= read_data(2) <= g_max_clients) ) return;
	
	g_Player_Item_Picked[read_data(2)] = false;
	g_Player_Item_Picked_Pro[read_data(2)] = false;

	if ( g_healing[read_data(2)] )
	{
		set_view(read_data(2),CAMERA_NONE);
	}
 
	ResetItems(read_data(2));
}
public TaskFinishHeal(client)
{
	if( !is_user_alive(client) ) return;
	
	if( pev_valid(g_ent[client]) )
	{
		engfunc(EngFunc_RemoveEntity, g_ent[client]);
		g_ent[client] = 0;
	}
	
	new target = g_target[client];
        
	set_pev(target, pev_health, get_pcvar_float(medic_cvar_heal_hp));
	
	set_user_maxspeed(client, Current_Speed[client])
	set_user_maxspeed(target, Current_Speed[target])	
		
	ManageBar(client, BAR_REMOVE);
	ManageBar(target, BAR_REMOVE);
			
	g_healing[client] = false;
			
	g_being_healed[target] = false;
			
	g_Player_Item_Picked[client] = false;
			
	set_view(client,CAMERA_NONE);
}
public TaskFinishHeal2(client)
{
	if( !is_user_alive(client) ) return;
	
	if( pev_valid(g_ent[client]) )
	{
		engfunc(EngFunc_RemoveEntity, g_ent[client]);
		g_ent[client] = 0;
	}
	
	set_pev(client, pev_health, get_pcvar_float(medic_cvar_heal_hp));
		
	set_user_maxspeed(client, Current_Speed[client])	
		
	ManageBar(client, BAR_REMOVE);
			
	g_healing[client] = false;
	
	g_being_healed[client] = false;
			
	g_Player_Item_Picked[client] = false;
			
	set_view(client,CAMERA_NONE);
}
 
ResetItems(client)
{
	if( !(1 <= client <= g_max_clients) ) return;
	
	if( pev_valid(g_ent[client]) )
	{
		engfunc(EngFunc_RemoveEntity, g_ent[client]);
		g_ent[client] = 0;
	}
			
	new target = g_target[client];
	if( g_being_healed[target] )
	{
		g_being_healed[target] = false;
		
		set_user_maxspeed(target, Current_Speed[target])
					
		ManageBar(target, BAR_REMOVE);
	}
			
	if( g_healing[client] )
	{
		g_healing[client] = false;
		
		set_user_maxspeed(client, Current_Speed[client])
					
		ManageBar(client, BAR_REMOVE);
	}
	
	g_Launching[client] = false;
			
	remove_task(client);
}
 
ManageBar(const client, bartime)
{
	new count = 1
	new players[32];
	if (client) players[0] = client; else get_players(players,count,"ch");
	for (new i=0;i<count;i++)
	if (is_user_connected(players[i]))
	{
		message_begin(MSG_ONE_UNRELIABLE, g_msgid_BarTime, _, players[i]);
		write_short(bartime);
		message_end();
	}
}
stock fm_velocity_by_aim(iIndex, Float:fDistance, Float:fVelocity[3], Float:fViewAngle[3])
{
	//new Float:fViewAngle[3]
	pev(iIndex, pev_v_angle, fViewAngle)
	fVelocity[0] = floatcos(fViewAngle[1], degrees) * fDistance
	fVelocity[1] = floatsin(fViewAngle[1], degrees) * fDistance
	fVelocity[2] = floatcos(fViewAngle[0] + 90.0, degrees) * fDistance
	return 1
}
stock fm_set_animation(id, anim) 
{
    set_pev(id, pev_weaponanim, anim)
    
    message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
    write_byte(anim)
    write_byte(pev(id, pev_body))
    message_end()
}
