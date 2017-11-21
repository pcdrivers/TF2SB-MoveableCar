#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Battlefield Duck"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <build>
#include <vphysics>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] SandBox - Moveable Car",
	author = PLUGIN_AUTHOR,
	description = "Moveable Car System for TF2SB",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/battlefieldduck/"
};

Handle g_hHud; //sync
Handle g_hHud2; //sync2
Handle g_iSpeedlimit;

bool bEnabled = true;
bool g_bSpawnCar[MAXPLAYERS + 1] = false;
int g_iSpawnCar[MAXPLAYERS + 1] = -1;
float g_fCarSpeed[MAXPLAYERS + 1] = 0.0;


public void OnPluginStart()
{
	RegAdminCmd("sm_sbcar", Command_SandboxCar, 0);
	
	CreateConVar("sm_tf2sb_car_version", PLUGIN_VERSION, "", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_iSpeedlimit = CreateConVar("sm_tf2sb_car_speedlimit", "500", "Speed limit of car (100 - 1000)", 0, true, 100.0, true, 1000.0);
	g_hHud = CreateHudSynchronizer();
	g_hHud2 = CreateHudSynchronizer();
}

public void OnClientPutInServer(int client)
{
	g_bSpawnCar[client] = false;
	g_iSpawnCar[client] = -1;
}

/*******************************************************************************************
	Main Menu
*******************************************************************************************/
public Action Command_SandboxCar(int client, int args) 
{
	if(!IsValidClient(client))
		return Plugin_Continue;
		
	if (bEnabled)
	{	
		char menuinfo[255];
		Menu menu = new Menu(Handler_MainMenu);
			
		Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Car Main Menu v%s \n ", PLUGIN_VERSION);
		menu.SetTitle(menuinfo);

		if(g_bSpawnCar[client])	
		{
			Format(menuinfo, sizeof(menuinfo), " Delete the car ", client);
			menu.AddItem("DELETECAR", menuinfo);
		}
		else
		{
			Format(menuinfo, sizeof(menuinfo), " Spawn a car ", client);
			menu.AddItem("BUILDCAR", menuinfo);
		}
		
		menu.ExitBackButton = true;
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public int Handler_MainMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		if (StrEqual(info, "DELETECAR"))
		{
			DeleteCar(client, g_iSpawnCar[client]);
			g_bSpawnCar[client] = false;
			g_iSpawnCar[client] = -1;
			Command_SandboxCar(client, -1);
		}	
		else if (StrEqual(info, "BUILDCAR"))
		{
			Command_SelectCar(client, -1);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack) 
		{
			FakeClientCommand(client, "sm_build");
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

/*******************************************************************************************
	Main Menu
*******************************************************************************************/
public Action Command_SelectCar(int client, int args) 
{
	if(!IsValidClient(client))
		return Plugin_Continue;
		
	if (bEnabled)
	{	
		char menuinfo[255];
		Menu menu = new Menu(Handler_SelectMenu);
			
		Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Car Main Menu v%s \nPlease select:\n ", PLUGIN_VERSION);
		menu.SetTitle(menuinfo);

		Format(menuinfo, sizeof(menuinfo), " Simple Car", client);
		menu.AddItem("1", menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " White Car", client);
		menu.AddItem("2", menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " Green Car", client);
		menu.AddItem("3", menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " Truck", client);
		menu.AddItem("4", menuinfo);
		
		
		menu.ExitBackButton = true;
		menu.ExitButton = false;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public int Handler_SelectMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		g_bSpawnCar[client] = true;
		g_iSpawnCar[client] = BuildCar(client, StringToInt(info));
				
		Build_RegisterEntityOwner(g_iSpawnCar[client], client);

		if(Phys_IsPhysicsObject(g_iSpawnCar[client]))
		{
			Phys_EnableGravity(g_iSpawnCar[client], true);
			Phys_EnableMotion(g_iSpawnCar[client], true);
			Phys_EnableCollisions(g_iSpawnCar[client], true);
			Phys_EnableDrag(g_iSpawnCar[client], false);			
		}
		Command_SandboxCar(client, -1);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack) 
		{
			Command_SandboxCar(client, -1);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

/*******************************************************************************************
	Main Function
*******************************************************************************************/
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{	
	if(!IsValidClient(client))
		return Plugin_Continue;
		
	if(IsValidEntity(g_iSpawnCar[client]) && g_bSpawnCar[client] && Phys_IsPhysicsObject(g_iSpawnCar[client]) && Phys_IsGravityEnabled(g_iSpawnCar[client]))
	{
		int iSpeedlimit = GetConVarInt(g_iSpeedlimit);
		float clientEye[3], fcarPosition[3], fcarAngle[3], fCarVel[3];
		
		GetClientEyePosition(client, clientEye);
		GetEntPropVector(g_iSpawnCar[client], Prop_Send, "m_vecOrigin", fcarPosition);
		GetEntPropVector(g_iSpawnCar[client], Prop_Send, "m_angRotation", fcarAngle); 
		
		char szModel[128];
		GetEntPropString(g_iSpawnCar[client], Prop_Data, "m_ModelName", szModel, sizeof(szModel));
		
		//PrintCenterText(client, "Distance %f \n Angle %f %f %f", GetVectorDistance(clientEye, fcarPosition), fcarAngle[0], fcarAngle[1], fcarAngle[2]);
		
		if(GetVectorDistance(clientEye, fcarPosition) < 150.0)
		{
			if(buttons & IN_DUCK)
			{
				TeleportEntity(client, fcarPosition, NULL_VECTOR, NULL_VECTOR);
				
				if(StrEqual(szModel, "models/airboat.mdl"))
				{
					fcarAngle[1] += 90.0;
				}
				AnglesNormalize(fcarAngle);
				
				//if(fcarAngle[2] > -10 && fcarAngle[2] < 10)
				{	
					if(fcarAngle[0] > 0)
					{
						fcarAngle[0] -= fcarAngle[0]/50;
					}
					else if(fcarAngle[0] < 0)
					{
						fcarAngle[0] += fcarAngle[0]/-50;
					}
					
					if(fcarAngle[2] > 0)
					{
						fcarAngle[2] -= fcarAngle[2]/50;
					}
					else if(fcarAngle[2] < 0)
					{
						fcarAngle[2] += fcarAngle[2]/-50;
					}
	
					if(g_fCarSpeed[client] != 0.0 && buttons & IN_MOVELEFT && !(buttons & IN_MOVERIGHT))
					{	//Left
						if(buttons & IN_FORWARD && g_fCarSpeed[client] < iSpeedlimit)
						{
							g_fCarSpeed[client] += 1.0;
						}
						else if(buttons & IN_BACK && g_fCarSpeed[client] > iSpeedlimit*-1)
						{
							g_fCarSpeed[client] -= 1.0;
						}
						else if(g_fCarSpeed[client] > 0)
						{	//Reduce speed due to ground + air friction
							g_fCarSpeed[client] -= 1.0;
						}
						else if(g_fCarSpeed[client] < 0)
						{	//Reduce speed due to ground + air friction
							g_fCarSpeed[client] += 1.0;
						}
							
						if(g_fCarSpeed[client] > 0)
							fcarAngle[1] += g_fCarSpeed[client]/500;
						else
							fcarAngle[1] += g_fCarSpeed[client]/500;
							
						TeleportEntity(g_iSpawnCar[client], NULL_VECTOR, fcarAngle, NULL_VECTOR);
					
						GetVecCar(fcarAngle, g_fCarSpeed[client], fCarVel);
						Phys_SetVelocity(g_iSpawnCar[client], fCarVel, NULL_VECTOR, true);
					}			
					else if(g_fCarSpeed[client] != 0.0 && !(buttons & IN_MOVELEFT) && buttons & IN_MOVERIGHT)
					{	//Right
						if(buttons & IN_FORWARD && g_fCarSpeed[client] < iSpeedlimit)
						{
							g_fCarSpeed[client] += 1.0;
						}
						else if(buttons & IN_BACK && g_fCarSpeed[client] > iSpeedlimit*-1)
						{
							g_fCarSpeed[client] -= 1.0;
						}
						else if(g_fCarSpeed[client] > 0)
						{	//Reduce speed due to ground + air friction
							g_fCarSpeed[client] -= 1.0;
						}
						else if(g_fCarSpeed[client] < 0)
						{	//Reduce speed due to ground + air friction
							g_fCarSpeed[client] += 1.0;
						}
							
						if(g_fCarSpeed[client] > 0)
							fcarAngle[1] -= g_fCarSpeed[client]/500;
						else
							fcarAngle[1] -= g_fCarSpeed[client]/500;
							
						TeleportEntity(g_iSpawnCar[client], NULL_VECTOR, fcarAngle, NULL_VECTOR);
					
						GetVecCar(fcarAngle, g_fCarSpeed[client], fCarVel);
						Phys_SetVelocity(g_iSpawnCar[client], fCarVel, NULL_VECTOR, true);
					}	
					else if(buttons & IN_FORWARD && !(buttons & IN_BACK) && g_fCarSpeed[client] < iSpeedlimit)
					{	//Forward
						g_fCarSpeed[client] += 2.0;

						GetVecCar(fcarAngle, g_fCarSpeed[client], fCarVel);
						Phys_SetVelocity(g_iSpawnCar[client], fCarVel, NULL_VECTOR, true);
					}
					else if(buttons & IN_BACK && !(buttons & IN_FORWARD) && g_fCarSpeed[client] > iSpeedlimit*-1)
					{	//Back
						g_fCarSpeed[client] -= 2.0;
						GetVecCar(fcarAngle, g_fCarSpeed[client], fCarVel);
						Phys_SetVelocity(g_iSpawnCar[client], fCarVel, NULL_VECTOR, true);
					}
					else if(g_fCarSpeed[client] > 0)
					{	//Reduce speed due to ground + air friction
						g_fCarSpeed[client] -= 1.0;
						GetVecCar(fcarAngle, g_fCarSpeed[client], fCarVel);
						Phys_SetVelocity(g_iSpawnCar[client], fCarVel, NULL_VECTOR, true);
					}
					else if(g_fCarSpeed[client] < 0)
					{	//Reduce speed due to ground + air friction
						g_fCarSpeed[client] += 1.0;
						GetVecCar(fcarAngle, g_fCarSpeed[client], fCarVel);
						Phys_SetVelocity(g_iSpawnCar[client], fCarVel, NULL_VECTOR, true);
					}
					
				
				}
				//else
				{
					if(buttons & IN_RELOAD)
					{
						//if(fcarAngle[2] > 10)
						//	fcarAngle[2] -= 1.0;
						//else
						//	fcarAngle[2] += 1.0;
						//TeleportEntity(g_iSpawnCar[client], NULL_VECTOR, fcarAngle, NULL_VECTOR);
					}
					else
					{
						////SetHudTextParams(-1.0, 0.6, 0.01, 255, 215, 0, 255, 1, 6.0, 0.5, 0.5);
						//ShowSyncHudText(client, g_hHud, "Press R(Reload) to reposition");
					}
				}
				

				if(StrEqual(szModel, "models/airboat.mdl"))
					fcarPosition[2] += 13.0;
				else	
					fcarPosition[2] -= 25.5;
					
				TeleportEntity(client, fcarPosition, NULL_VECTOR, NULL_VECTOR);
				//GetVecCar(fcarAngle, fCarVel);
				//Phys_SetVelocity(g_iSpawnCar[client], fCarVel, fcarAngle, false);
				
				
				SetHudTextParams(-1.0, 0.8, 0.01, 255, 215, 0, 255, 1, 6.0, 0.5, 0.5);
				ShowSyncHudText(client, g_hHud2, "Speed ⁅%i⁆", RoundFloat(g_fCarSpeed[client]));
				
				PrintCenterText(client, "Distance %f \n Angle %f %f %f \n Vel %f %f %f"
				, GetVectorDistance(clientEye, fcarPosition), fcarAngle[0], fcarAngle[1], fcarAngle[2], fCarVel[0], fCarVel[1], fCarVel[2]);
			}
			else if(!(buttons & IN_SCORE))
			{
				g_fCarSpeed[client] = 0.0;
				SetHudTextParams(-1.0, 0.6, 0.01, 255, 215, 0, 255, 1, 6.0, 0.5, 0.5);
				ShowSyncHudText(client, g_hHud, "Hold Ctrl(DUCK) to drive the car");
			}
		}
	}
	return Plugin_Continue;
}


int BuildCar(int client, int model)
{
	char strModel[100];	
	
	if(model == 1)
		strcopy(strModel, sizeof(strModel), "models/props_vehicles/car002a.mdl");
	else if(model == 2)
		strcopy(strModel, sizeof(strModel), "models/props_vehicles/car004a.mdl");
	else if(model == 3)
		strcopy(strModel, sizeof(strModel), "models/props_vehicles/car005a.mdl");
	else if(model == 4)
		strcopy(strModel, sizeof(strModel), "models/airboat.mdl");
		//strcopy(strModel, sizeof(strModel), "models/props_vehicles/truck001a.mdl");

	int car = CreateEntityByName("prop_physics_override"); 
	
	if(car > MaxClients && IsValidEntity(car))
	{	
		SetEntProp(car, Prop_Send, "m_nSolidType", 6);
		SetEntProp(car, Prop_Data, "m_nSolidType", 6);
		
		PrecacheModel(strModel);
		DispatchKeyValue(car, "model", strModel);
		float fOrigin[3];
		GetClientEyePosition(client, fOrigin);
		TeleportEntity(car, fOrigin, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(car);
			
		return car;
	}
	return -1;
}

void DeleteCar(int client, int carIndex)
{
	if(IsValidEntity(carIndex) && Build_ReturnEntityOwner(carIndex) == client)
	{
		AcceptEntityInput(carIndex, "Kill");
	}
}

stock bool IsValidClient(int client) 
{ 
    if(client <= 0 ) return false; 
    if(client > MaxClients) return false; 
    if(!IsClientConnected(client)) return false; 
    return IsClientInGame(client); 
}

void GetVecCar(float angle[3], float speed, float outVel[3])
{	
	float local_angle[3];
	local_angle[0] *= -1.0; 
	local_angle[0] = DegToRad(angle[0]); 
	local_angle[1] = DegToRad(angle[1]); 
	local_angle[2] *= -1.0; 
	local_angle[2] = DegToRad(angle[2]); 
	
	outVel[0] = speed*Cosine(local_angle[0])*Cosine(local_angle[1]); 
	outVel[1] = speed*Cosine(local_angle[0])*Sine(local_angle[1]); 
	outVel[2] = speed*Sine(local_angle[0])*Cosine(local_angle[1])*Sine(local_angle[2]); //speed*Sine(local_angle[0]); 
}

public void AnglesNormalize(float vAngles[3])
{
	while(vAngles[0] >  89.0) vAngles[0]-=360.0;
	while(vAngles[0] < -89.0) vAngles[0]+=360.0;
	while(vAngles[1] > 180.0) vAngles[1]-=360.0;
	while(vAngles[1] <-180.0) vAngles[1]+=360.0;
}