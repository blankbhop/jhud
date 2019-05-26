#include <sourcemod>
#include <clientprefs>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name = "[shavit] jhud",
	author = "Blank",
	description = "Center of screen SSJ",
	version = "0.9",
	url = ""
};

#define JHUD_INTERVAL 15
#define l1 "#l1"
#define l2 "#l2"
#define l3 "#l3"
#define l4 "#l4"
#define l5 "#l5"

Handle gH_JHUDCookie;
bool gB_JHUD[MAXPLAYERS + 1] = {false, ...};

int g_iTicksOnGround[MAXPLAYERS+1];
int g_strafeTick[MAXPLAYERS+1];
int g_syncedTick[MAXPLAYERS+1];
int g_iJump[MAXPLAYERS+1];

float g_flRawGain[MAXPLAYERS+1];
float g_flTrajectory[MAXPLAYERS+1];
float g_vecTraveledDistance[MAXPLAYERS+1][3];

public void OnAllPluginsLoaded()
{
	HookEvent("player_jump", OnPlayerJump);
}

public void OnPluginStart()
{
	LoadTranslations("shavit-jhud.phrases");
	
	RegConsoleCmd("sm_jhud", Command_JHUD, "Toggles JHUD");
   
	gH_JHUDCookie = RegClientCookie("JHUD_enabled", "JHUD_enabled", CookieAccess_Protected);
   
	for(int i = 1; i <= MaxClients; i++)
	{
		if(AreClientCookiesCached(i))
		{
			OnClientPostAdminCheck(i);
			OnClientCookiesCached(i);
		}
	}
}

public void OnClientDisconnect(int client)
{
	gB_JHUD[client] = false;
}

public void OnClientCookiesCached(int client)
{
	gB_JHUD[client] = GetClientCookieBool(client, gH_JHUDCookie);
}

public void OnClientPostAdminCheck(int client)
{
	g_iJump[client] = 0;
	g_strafeTick[client] = 0;
	g_syncedTick[client] = 0;
	g_flRawGain[client] = 0.0;
	g_flTrajectory[client] = 0.0;
	g_vecTraveledDistance[client] = NULL_VECTOR;
	g_iTicksOnGround[client] = 0;
}

public Action OnPlayerJump(Event event, char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);

	if(IsFakeClient(client))
		return;   
	if(g_iJump[client] && g_strafeTick[client] <= 0)
		return;

	g_iJump[client]++;
	float velocity[3];
	float origin[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);
	GetClientAbsOrigin(client, origin);
	velocity[2] = 0.0;

	for(int i=1; i<MaxClients;i++)
	{
		if(IsClientInGame(i) && ((!IsPlayerAlive(i) && GetEntPropEnt(i, Prop_Data, "m_hObserverTarget") == client && GetEntProp(i, Prop_Data, "m_iObserverMode") != 7 && gB_JHUD[i]) || ((i == client && gB_JHUD[i]))))
			JHUD_DrawStats(i, client);
	}

	g_flRawGain[client] = 0.0;
	g_strafeTick[client] = 0;
	g_syncedTick[client] = 0;
	g_flTrajectory[client] = 0.0;
	g_vecTraveledDistance[client] = NULL_VECTOR;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(IsFakeClient(client)) return Plugin_Continue;

	if(GetEntityFlags(client) & FL_ONGROUND)
	{
		if(g_iTicksOnGround[client] > JHUD_INTERVAL)
		{
			g_iJump[client] = 0;
			g_strafeTick[client] = 0;
			g_syncedTick[client] = 0;
			g_flRawGain[client] = 0.0;
			g_flTrajectory[client] = 0.0;
			g_vecTraveledDistance[client] = NULL_VECTOR;
		}
		g_iTicksOnGround[client]++;
	}
	else
	{
		if(GetEntityMoveType(client) != MOVETYPE_NONE && GetEntityMoveType(client) != MOVETYPE_NOCLIP && GetEntityMoveType(client) != MOVETYPE_LADDER && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2)
		{
			JHUD_GetStats(client, vel, angles);
		}
		g_iTicksOnGround[client] = 0;
	}
	return Plugin_Continue;
}

public Action Command_JHUD(int client, any args)
{
	if (client != 0)
	{
		gB_JHUD[client] = !gB_JHUD[client];
		Command_JHUDM(client, 1);
		return Plugin_Handled;
	}  
	return Plugin_Handled;
}

public int MenuHandle(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, l1))
			{
				gB_JHUD[client] = !gB_JHUD[client];
				SetClientCookieBool(client, gH_JHUDCookie, gB_JHUD[client]);
				Command_JHUDM(client, 1);
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public Action Command_JHUDM(int client, int args)
{
	char sStatus[32];
	FormatEx(sStatus, sizeof(sStatus), "Jump Hud: [%s]", gB_JHUD[client] ? "+" : "-");
	
	Menu menu = new Menu(MenuHandle);
	menu.SetTitle("Jump Hud Menu");
	menu.AddItem(l1, sStatus);
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}


void JHUD_GetStats(int client, float vel[3], float angles[3])
{
	float velocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);

	float gaincoeff;
	g_strafeTick[client]++;

	g_vecTraveledDistance[client][0] += velocity[0] *  GetTickInterval() * GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");
	g_vecTraveledDistance[client][1] += velocity[1] *  GetTickInterval() * GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");
	velocity[2] = 0.0;
	g_flTrajectory[client] += GetVectorLength(velocity) * GetTickInterval() * GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");

	float fore[3], side[3], wishvel[3], wishdir[3];
	float wishspeed, wishspd, currentgain;

	GetAngleVectors(angles, fore, side, NULL_VECTOR);

	fore[2] = 0.0;
	side[2] = 0.0;
	NormalizeVector(fore, fore);
	NormalizeVector(side, side);

	for(int i = 0; i < 2; i++)
		wishvel[i] = fore[i] * vel[0] + side[i] * vel[1];
   
	wishspeed = NormalizeVector(wishvel, wishdir);
	if(wishspeed > GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") && GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") != 0.0)
		wishspeed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");

	if(wishspeed)
	{
		wishspd = (wishspeed > 30.0) ? 30.0 : wishspeed;

		currentgain = GetVectorDotProduct(velocity, wishdir);
		if(currentgain < 30.0)
		{
			g_syncedTick[client]++;
			gaincoeff = (wishspd - FloatAbs(currentgain)) / wishspd;
		}
		g_flRawGain[client] += gaincoeff;
	}
}

void JHUD_DrawStats(int client, int target)
{
	float velocity[3];
	float origin[3];
	GetEntPropVector(target, Prop_Data, "m_vecAbsVelocity", velocity);
	GetClientAbsOrigin(target, origin);
	velocity[2] = 0.0;

	float coeffsum = g_flRawGain[target];
	coeffsum /= g_strafeTick[target];
	coeffsum *= 100.0;

	coeffsum = RoundToFloor(coeffsum * 100.0 + 0.5) / 100.0;

	int r, g, b;
	if (g_iJump[target] == 1 && RoundToFloor(GetVectorLength(velocity)) < 280)
		r = 255, g = 0, b = 0;
	else if (g_iJump[target] == 1 && RoundToFloor(GetVectorLength(velocity)) >= 280 && RoundToFloor(GetVectorLength(velocity)) <= 281)
		r = 255, g = 165, b = 0;
	else if (g_iJump[target] == 1 && RoundToFloor(GetVectorLength(velocity)) > 281 && RoundToFloor(GetVectorLength(velocity)) <= 286)
		r = 0, g = 255, b = 0;
	else if (g_iJump[target] == 1 && RoundToFloor(GetVectorLength(velocity)) > 286)
		r = 0, g = 191, b = 255;
	else if (g_iJump[target] == 2 && RoundToFloor(GetVectorLength(velocity)) < 365)
		r = 255, g = 0, b = 0;
	else if (g_iJump[target] == 2 && RoundToFloor(GetVectorLength(velocity)) >= 365 && RoundToFloor(GetVectorLength(velocity)) <= 369)
		r = 255, g = 165, b = 0;
	else if (g_iJump[target] == 2 && RoundToFloor(GetVectorLength(velocity)) > 369 && RoundToFloor(GetVectorLength(velocity)) <= 374)
		r = 0, g = 255, b = 0;
	else if (g_iJump[target] == 2 && RoundToFloor(GetVectorLength(velocity)) > 374)
		r = 0, g = 191, b = 255;
	else if (g_iJump[target] == 3 && RoundToFloor(GetVectorLength(velocity)) < 438)
		r = 255, g = 0, b = 0;
	else if (g_iJump[target] == 3 && RoundToFloor(GetVectorLength(velocity)) >= 438 && RoundToFloor(GetVectorLength(velocity)) <= 441)
		r = 255, g = 165, b = 0;
	else if (g_iJump[target] == 3 && RoundToFloor(GetVectorLength(velocity)) > 441 && RoundToFloor(GetVectorLength(velocity)) <= 449)
		r = 0, g = 255, b = 0;
	else if (g_iJump[target] == 3 && RoundToFloor(GetVectorLength(velocity)) > 449)
		r = 0, g = 191, b = 255;
	else if (g_iJump[target] == 4 && RoundToFloor(GetVectorLength(velocity)) < 500)
		r = 255, g = 0, b = 0;
	else if (g_iJump[target] == 4 && RoundToFloor(GetVectorLength(velocity)) >= 500 && RoundToFloor(GetVectorLength(velocity)) <= 504)
		r = 255, g = 165, b = 0;
	else if (g_iJump[target] == 4 && RoundToFloor(GetVectorLength(velocity)) > 504 && RoundToFloor(GetVectorLength(velocity)) <= 514)
		r = 0, g = 255, b = 0;
	else if (g_iJump[target] == 4 && RoundToFloor(GetVectorLength(velocity)) > 514)
		r = 0, g = 191, b = 255;
	else if (g_iJump[target] == 5 && RoundToFloor(GetVectorLength(velocity)) < 555)
		r = 255, g = 0, b = 0;
	else if (g_iJump[target] == 5 && RoundToFloor(GetVectorLength(velocity)) >= 555 && RoundToFloor(GetVectorLength(velocity)) <= 559)
		r = 255, g = 165, b = 0;
	else if (g_iJump[target] == 5 && RoundToFloor(GetVectorLength(velocity)) > 559 && RoundToFloor(GetVectorLength(velocity)) <= 569)
		r = 0, g = 255, b = 0;
	else if (g_iJump[target] == 5 && RoundToFloor(GetVectorLength(velocity)) > 569)
		r = 0, g = 191, b = 255;
	else if (g_iJump[target] == 6 && RoundToFloor(GetVectorLength(velocity)) < 605)
		r = 255, g = 0, b = 0;
	else if (g_iJump[target] == 6 && RoundToFloor(GetVectorLength(velocity)) >= 605 && RoundToFloor(GetVectorLength(velocity)) <= 609)
		r = 255, g = 165, b = 0;
	else if (g_iJump[target] == 6 && RoundToFloor(GetVectorLength(velocity)) > 609 && RoundToFloor(GetVectorLength(velocity)) <= 619)
		r = 0, g = 255, b = 0;
	else if (g_iJump[target] == 6 && RoundToFloor(GetVectorLength(velocity)) > 619)
		r = 0, g = 191, b = 255;
	else if (g_iJump[target] == 16 && RoundToFloor(GetVectorLength(velocity)) < 965)
		r = 255, g = 0, b = 0;
	else if (g_iJump[target] == 16 && RoundToFloor(GetVectorLength(velocity)) >= 965 && RoundToFloor(GetVectorLength(velocity)) <= 979)
		r = 255, g = 165, b = 0;
	else if (g_iJump[target] == 16 && RoundToFloor(GetVectorLength(velocity)) > 979 && RoundToFloor(GetVectorLength(velocity)) <= 999)
		r = 0, g = 255, b = 0;
	else if (g_iJump[target] == 16 && RoundToFloor(GetVectorLength(velocity)) > 999)
		r = 0, g = 191, b = 255;
	else if (g_iJump[target] > 6 && coeffsum < 60)
		r = 255, g = 0, b = 0;
	else if (g_iJump[target] > 6 && coeffsum >= 60 && coeffsum < 70)
		r = 255, g = 165, b = 0;
	else if (g_iJump[target] > 6 && coeffsum >= 70 && coeffsum < 80)
		r = 0, g = 255, b = 0;
	else if (g_iJump[target] > 6 && coeffsum >= 80)
		r = 0, g = 191, b = 255;
 
	char sMessage[256];
	if (g_iJump[target] <= 6 || g_iJump[target] == 16)
		Format(sMessage, sizeof(sMessage), "%i: %i", g_iJump[target], RoundToFloor(GetVectorLength(velocity)));
	else
		Format(sMessage, sizeof(sMessage), "%.02f%%", coeffsum);
 
	SetHudTextParams(-1.0, 0.4, 1.0, r, g, b, 255, 0, 0.0, 0.0, 0.2);
	ShowHudText(client, 3, sMessage);
}

stock bool GetClientCookieBool(int client, Handle cookie)
{
	char sValue[8];
	GetClientCookie(client, gH_JHUDCookie, sValue, sizeof(sValue));
	return (sValue[0] != '\0' && StringToInt(sValue));
}

stock void SetClientCookieBool(int client, Handle cookie, bool value)
{
	char sValue[8];
	IntToString(value, sValue, sizeof(sValue));
	SetClientCookie(client, cookie, sValue);
}