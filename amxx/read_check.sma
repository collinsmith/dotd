/* Plugin generated by AMXX-Studio */

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <engine>

#define MAXENTS 1000

public plugin_init()
{
	register_plugin("Read entities", "0.0", "Tirant")
	
	register_clcmd("say /read", "cmdReadMap")
}

public cmdReadMap(id)
{
	for ( new i = 0; i < MAXENTS; i++)
	{
		if (id == pev(i, pev_owner))
			client_print(id, print_chat, "Owning entity %d", i)

		if (id == pev(i, pev_aiment))
			client_print(id, print_chat, "Following entity %d", i)
			
		new szCache[64]
		entity_get_string(i, EV_SZ_model, szCache, charsmax(szCache))
		if (equali(szCache, "models/p_", 9))
			client_print(id, print_chat, "Entity %d = %s", i, szCache)
	}
}