#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>

#include <PugCS>
#include <PugConst>
#include <PugNatives>
#include <PugForwards>

#pragma semicolon 1

#define isTeam(%0) (CS_TEAM_T <= cs_get_user_team(%0) <= CS_TEAM_CT)

new g_pForceRestart;
new g_pSwitchDelay;
new g_pBlockShield;
new g_pBlockGrenades;
new g_pTeamMoney;

new g_pPlayersMin;
new g_pPlayersMax;
new g_pAllowSpec;
new g_pSvRestart;
new g_pMpStartMoney;

new g_iEventReturn;
new g_iEventJoinedTeam;
new g_iEventSpawn;
new g_iEventKilled;

new g_sEntities[][] =
{
	"func_bomb_target",
	"info_bomb_target",
	"hostage_entity",
	"func_hostage_rescue",
	"info_hostage_rescue",
	"info_vip_start",
	"func_vip_safetyzone",
	"func_escapezone"
};

new g_sEntitiesChanged[][] =
{
	"_func_bomb_target",
	"_info_bomb_target",
	"_hostage_entity",
	"_func_hostage_rescue",
	"_info_hostage_rescue",
	"_info_vip_start",
	"_func_vip_safetyzone",
	"_func_escapezone"
};

public plugin_init()
{
	register_plugin("Pug Mod (CS)",PUG_MOD_VERSION,PUG_MOD_AUTHOR);
	
	register_dictionary("PugCS.txt");
	
	g_pForceRestart		= create_cvar("pug_force_restart","1",FCVAR_NONE,"Force a restart when swap teams");
	g_pSwitchDelay		= create_cvar("pug_switch_delay","5.0",FCVAR_NONE,"Delay to swap teams after Half-Time start");
	g_pBlockShield		= create_cvar("pug_block_shield","1",FCVAR_NONE,"Block shield from game");
	g_pBlockGrenades	= create_cvar("pug_block_grenades","1",FCVAR_NONE,"Block grenades at warmup rounds");
	g_pTeamMoney		= create_cvar("pug_show_money","1",FCVAR_NONE,"Display the money of team in every respawn");
	
	g_pPlayersMin		= get_cvar_pointer("pug_players_min");
	g_pPlayersMax		= get_cvar_pointer("pug_players_max");
	g_pAllowSpec		= get_cvar_pointer("pug_allow_spectators");
	g_pSvRestart		= get_cvar_pointer("sv_restart");
	g_pMpStartMoney		= get_cvar_pointer("mp_startmoney");
	
	g_iEventJoinedTeam	= CreateMultiForward("PugPlayerJoined",ET_IGNORE,FP_CELL,FP_CELL);
	g_iEventSpawn		= CreateMultiForward("PugPlayerSpawned",ET_IGNORE,FP_CELL);
	g_iEventKilled		= CreateMultiForward("PugPlayerKilled",ET_IGNORE,FP_CELL);
	
	register_event("SendAudio","CS_WonTR","a","2=%!MRAD_terwin");
	register_event("SendAudio","CS_WonCT","a","2=%!MRAD_ctwin");
	register_event("SendAudio","CS_RoundDraw","a","2=%!MRAD_rounddraw");
	
	register_logevent("CS_RoundStart",2,"1=Round_Start");
	register_logevent("CS_RoundEnd",2,"1=Round_End");
	
	register_clcmd("jointeam","CS_JoinTeam");

	register_menucmd(-2,MENU_KEY_1|MENU_KEY_2|MENU_KEY_5|MENU_KEY_6,"CS_TeamSelect");
	register_menucmd(register_menuid("Team_Select",1),MENU_KEY_1|MENU_KEY_2|MENU_KEY_5|MENU_KEY_6,"CS_TeamSelect");
	
	RegisterHamPlayer(Ham_Spawn,"CS_SpawnPost",true);
	RegisterHamPlayer(Ham_Killed,"CS_KilledPost",true);
	
	register_clcmd("joinclass","CS_JoinedClass");
	register_clcmd("menuselect","CS_JoinedClass");
}

public plugin_cfg()
{
	PugRegisterTeam("Terrorists");
	PugRegisterTeam("Counter-Terrorists");
}	

public plugin_natives()
{
	register_library("PugCS");
	
	register_native("PugGetClientTeam","CS_GetClientTeam");
	register_native("PugSetClientTeam","CS_SetClientTeam");
	
	register_native("PugGetPlayers","CS_GetPlayers");
	
	register_native("PugIsTeam","CS_IsTeam");
	register_native("PugRespawn","CS_Respawn");
	register_native("PugSetGodMode","CS_SetGodMode");
	register_native("PugSetMoney","CS_SetMoney");
	register_native("PugMapObjectives","CS_MapObjectives");
	register_native("PugSetScore","CS_SetScore");
	
	register_native("PugTeamsRandomize","CS_TeamsRandomize");
	register_native("PugTeamsBalance","CS_TeamsBalance");
	register_native("PugTeamsOptmize","CS_TeamsOptmize");
}

public CS_GetClientTeam()
{
	return _:cs_get_user_team(get_param(1));
}

public CS_SetClientTeam()
{
	cs_set_user_team(get_param(1),_:get_param(2));
}

public CS_GetPlayers()
{
	new iPlayers[32],iNum,iCount = 0;
	get_players(iPlayers,iNum,get_param(1) ? "h" : "ch");
	
	for(new i;i < iNum;i++)
	{
		if(isTeam(iPlayers[i]))
		{
			iCount++;
		}
	}

	return iCount;
}

public CS_IsTeam()
{
	if(isTeam(get_param(1)))
	{
		return true;
	}
	
	return false;
}

public CS_Respawn()
{
	ExecuteHamB(Ham_CS_RoundRespawn,get_param(1));
}

public CS_SetGodMode()
{
	set_pev(get_param(1),pev_takedamage,get_param(2) ? DAMAGE_NO : DAMAGE_AIM);
}

public CS_SetMoney()
{
	cs_set_user_money(get_param(1),get_param(2),get_param(3));
}

public CS_MapObjectives(id,iParams)
{
	new iEnt = -1;
	new iRemove = get_param(1);
	
	for(new i;i < sizeof(g_sEntities);i++)
	{
		while((iEnt = engfunc(EngFunc_FindEntityByString,iEnt,"classname",iRemove ? g_sEntities[i] : g_sEntitiesChanged[i])) > 0)
		{
			set_pev(iEnt,pev_classname,iRemove ? g_sEntitiesChanged[i] : g_sEntities[i]);
		}
	}
}

public CS_SetScore(id,iParams)
{
	new iPlayer = get_param(1);
	
	set_pev(iPlayer,pev_frags,float(get_param(2)));
	set_ent_data(iPlayer,"CBasePlayer","m_iDeaths",get_param(3));
	
	ExecuteHam(Ham_AddPoints,iPlayer,0,true);
}

public CS_TeamsRandomize()
{
	new iPlayers[32],iNum;
	get_players(iPlayers,iNum);
	
	for(new i;i < iNum;i++)
	{
		if(!isTeam(iPlayers[i]))
		{
			iPlayers[i--] = iPlayers[--iNum];
		}
	}
	
	new iPlayer,CsTeams:iTeam = random(2) ? CS_TEAM_T : CS_TEAM_CT;
	
	new iRandom;
	
	while(iNum)
	{
		iRandom = random(iNum);
		
		iPlayer = iPlayers[iRandom];
		
		cs_set_user_team(iPlayer,iTeam);
		
		iPlayers[iRandom] = iPlayers[--iNum];
		
		iTeam = CsTeams:((_:iTeam) % 2 + 1);
	}
}

public CS_TeamsBalance()
{
	new iPlayers[32],iNum,iPlayer;
	get_players(iPlayers,iNum,"h");

	new a,b,aPlayer,bPlayer;
	
	for(new i;i < iNum;i++)
	{
		iPlayer = iPlayers[i];

		switch(cs_get_user_team(iPlayer))
		{
			case CS_TEAM_T:
			{
				++a;
				aPlayer = iPlayer;
			}
			case CS_TEAM_CT:
			{
				++b;
				bPlayer = iPlayer;
			}
		}
	}
	
	if(a == b) 
	{
		return;
	}
	else if((a + 2) == b)
	{
		cs_set_user_team(aPlayer,CS_TEAM_T);
	}
	else if((b + 2) == a)
	{
		cs_set_user_team(bPlayer,CS_TEAM_CT);
	}
	else if((a + b) < get_pcvar_num(g_pPlayersMin))
	{
		a = PugGetTeamScore(1);
		b = PugGetTeamScore(2);

		if(a < b)
		{
			cs_set_user_team(aPlayer,CS_TEAM_T);
		}
		else if(b < a)
		{
			cs_set_user_team(bPlayer,CS_TEAM_CT);
		}
	}
}

public CS_TeamsOptmize()
{
	new iSkills[MAX_PLAYERS+1],iSorted[MAX_PLAYERS+1];
	new iPlayers[MAX_PLAYERS],iNum,iPlayer;
	
	for(new i;i < iNum;i++)
	{
		iPlayer = iPlayers[i];
		
		iSorted[iPlayer] = iSkills[iPlayer] = (get_user_time(iPlayer,1) / get_user_frags(iPlayer));
	}
	
	SortIntegers(iSorted,sizeof(iSorted),Sort_Descending);

	new iCheck = 1,iTeams = PugNumTeams();
	
	for(new i;i < sizeof(iSorted);i++)
	{
		for(new a;a < iNum;a++)
		{
			iPlayer = iPlayers[a];
			
			if(iSkills[iPlayer] == iSorted[i])
			{
				PugSetClientTeam(iPlayer,iCheck);
				
				iCheck++;
				
				if(iCheck > iTeams)
				{
					iCheck = 1;
				}
			}
		}
	}
}

public CS_RoundStart()
{
	PugRoundStart();
}

public CS_RoundEnd()
{
	PugRoundEnd();
}

public CS_WonTR()
{
	PugRoundWinner(_:CS_TEAM_T);
}

public CS_WonCT()
{
	PugRoundWinner(_:CS_TEAM_CT);
}

public CS_RoundDraw()
{
	PugRoundWinner(0);
}

public PugEventHalfTime()
{
	set_task(get_pcvar_float(g_pSwitchDelay),"CS_SwitchTeams");
}

public CS_SwitchTeams()
{
	new iScore = PugGetTeamScore(1);
	PugSetTeamScore(1,PugGetTeamScore(2));
	PugSetTeamScore(2,iScore);
	
	new iPlayers[32],iNum,iPlayer;
	get_players(iPlayers,iNum,"h");
	
	for(new i;i < iNum;i++)
	{
		iPlayer = iPlayers[i];
		
		switch(cs_get_user_team(iPlayer))
		{
			case CS_TEAM_T:
			{
				cs_set_user_team(iPlayer,CS_TEAM_CT);
			}
			case CS_TEAM_CT:
			{
				cs_set_user_team(iPlayer,CS_TEAM_T);
			}
		}
	}
	
	if(get_pcvar_num(g_pForceRestart))
	{
		set_pcvar_num(g_pSvRestart,1);
	}
}

public CS_JoinTeam(id)
{
	new sArg[3];
	read_argv(1,sArg,charsmax(sArg));
	
	return CS_CheckTeam(id,CsTeams:str_to_num(sArg));
}

public CS_TeamSelect(id,iKey)
{
	return CS_CheckTeam(id,CsTeams:(iKey + 1));
}

public CS_CheckTeam(id,CsTeams:iTeamNew) 
{
	new CsTeams:iTeamOld = cs_get_user_team(id);
	
	if(iTeamOld == iTeamNew)
	{
		client_print_color
		(
			id,
			print_team_red,
			"%s %L",
			g_sHead,
			LANG_SERVER,
			"PUG_SELECTTEAM_SAMETEAM"
		);
		
		return PLUGIN_HANDLED;
	}
	
	if(STAGE_START <= GET_PUG_STAGE() <= STAGE_OVERTIME)
	{
		if((iTeamOld == CS_TEAM_T) || (iTeamOld == CS_TEAM_CT))
		{
			client_print_color
			(
				id,
				print_team_red,
				"%s %L",
				g_sHead,
				LANG_SERVER,
				"PUG_SELECTTEAM_NOSWITCH"
			);
			
			return PLUGIN_HANDLED;
		}
	}
	
	switch(iTeamNew)
	{
		case CS_TEAM_T,CS_TEAM_CT:
		{
			new iMaxTeamPlayers = (get_pcvar_num(g_pPlayersMax) / 2);
			
			new iPlayers[MAX_PLAYERS],iNum;
			get_players(iPlayers,iNum,"h");
			
			new iCount[2] = {0,0};
			
			for(new i;i < iNum;i++)
			{
				switch(cs_get_user_team(iPlayers[i]))
				{
					case CS_TEAM_T:
					{
						iCount[0]++;
					}
					case CS_TEAM_CT:
					{
						iCount[1]++;
					}
				}
			}
			
			if((iCount[0] >= iMaxTeamPlayers) && (iTeamNew == CS_TEAM_T))
			{
				client_print_color
				(
					id,
					print_team_red,
					"%s %L",
					g_sHead,
					LANG_SERVER,
					"PUG_SELECTTEAM_TEAMFULL"
				);
				
				return PLUGIN_HANDLED;
			}
			else if((iCount[1] >= iMaxTeamPlayers) && (iTeamNew == CS_TEAM_CT))
			{
				client_print_color
				(
					id,
					print_team_red,
					"%s %L",
					g_sHead,
					LANG_SERVER,
					"PUG_SELECTTEAM_TEAMFULL"
				);
				
				return PLUGIN_HANDLED;
			}
		}
		case 5:
		{
			client_print_color
			(
				id,
				print_team_red,
				"%s %L",
				g_sHead,
				LANG_SERVER,
				"PUG_SELECTTEAM_NOAUTO"
			);
			
			return PLUGIN_HANDLED;
		}
		case CS_TEAM_SPECTATOR:
		{
			if(!get_pcvar_num(g_pAllowSpec) && !access(id,PUG_CMD_LVL))
			{
				client_print_color
				(
					id,
					print_team_red,
					"%s %L",
					g_sHead,
					LANG_SERVER,
					"PUG_SELECTTEAM_NOSPC"
				);
				
				return PLUGIN_HANDLED;
			}
		}
	}

	return PLUGIN_CONTINUE;
}

public CS_SpawnPost(id)
{
	ExecuteForward(g_iEventSpawn,g_iEventReturn,id);
}

public PugPlayerSpawned(id)
{
	new iStage = GET_PUG_STAGE();
	
	if((iStage == STAGE_FIRSTHALF) || (iStage == STAGE_SECONDHALF) || (iStage == STAGE_OVERTIME))
	{
		if(is_user_alive(id) && isTeam(id) && get_pcvar_num(g_pTeamMoney) && (cs_get_user_money(id) != get_pcvar_num(g_pMpStartMoney)))
		{
			set_task(0.1,"CS_MoneyTeam",id);
		}
	}
}

public CS_KilledPost(id)
{
	ExecuteForward(g_iEventKilled,g_iEventReturn,id);
}

public CS_MoneyTeam(id)
{
	new sTeam[13];
	get_user_team(id,sTeam,charsmax(sTeam));

	new iPlayers[32],iNum,iPlayer;
	get_players(iPlayers,iNum,"aeh",sTeam);

	new sName[32],sHud[512],iMoney;

	for(new i;i < iNum;i++)
	{
		iPlayer = iPlayers[i];

		iMoney = cs_get_user_money(iPlayer);
		get_user_name(iPlayer,sName,charsmax(sName));

		format
		(
			sHud,
			charsmax(sHud),
			"%s%s $ %i^n",
			sHud,
			sName,
			iMoney
		);
	}
	
	set_hudmessage(0,255,0,0.58,0.02,0,0.0,10.0,0.0,0.0,1);
	show_hudmessage(id,(sTeam[0] == 'T') ? "Terrorists" : "Counter-Terrorists");
	
	set_hudmessage(255,255,225,0.58,0.05,0,0.0,10.0,0.0,0.0,2);
	show_hudmessage(id,sHud);
}

public CS_OnBuy(id,iWeapon)
{
	switch(iWeapon)
	{
		case CSI_FLASHBANG,CSI_HEGRENADE,CSI_SMOKEGRENADE:
		{
			new iStage = GET_PUG_STAGE();
			
			if((iStage == STAGE_FIRSTHALF) || (iStage == STAGE_SECONDHALF) || (iStage == STAGE_OVERTIME))
			{
				return PLUGIN_CONTINUE;
			}
			
			return get_pcvar_num(g_pBlockGrenades) ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
		}
		case CSI_SHIELD:
		{
			return get_pcvar_num(g_pBlockShield) ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
		}
	}

	return PLUGIN_CONTINUE;
}

public CS_JoinedClass(id)
{
	if(get_ent_data(id,"CBasePlayer","m_iMenu") == CS_Menu_ChooseAppearance)
	{
		ExecuteForward(g_iEventJoinedTeam,g_iEventReturn,id,cs_get_user_team(id));
	}
}
