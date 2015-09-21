/*
	Thank you bro for downloading my plugin, it is a honor help you with your server.
	Plugin by AbNeR_CSS @2015
	
	Plugin Features:
	- CSS/CS:GO support.
	- Sounds load automatically.
	- Stops standard CSGO round start sound.
	- Type !rss to choose if you want or not listen the sounds.

	Se você é brasileiro acesse o forum do meu clan:
	www.tecnohardclan.com/forum e receba suporte em português.

*/


#include <sourcemod>
#include <sdktools>
#include <colors>
#include <clientprefs>

#pragma semicolon 1

#define ABNER_ADMINFLAG ADMFLAG_SLAY
#define PLUGIN_VERSION "1.0"

#define MAX_EDICTS		2048
#define MAX_SOUNDS		1024

new Handle:g_hPath;
new Handle:g_hPlayType;
new Handle:g_AbNeRCookie;

new bool:g_bClientPreference[MAXPLAYERS+1];
new bool:SoundsSucess = false;
new bool:CSGO;

new g_Sounds = 0;

new String:sounds[MAX_SOUNDS][PLATFORM_MAX_PATH];

new String:sCookieValue[11];


public Plugin:myinfo =
{
	name = "[ANY] AbNeR Round Start Sounds",
	author = "AbNeR_CSS",
	description = "Play cool musics when round starts!",
	version = PLUGIN_VERSION,
	url = "http://www.tecnohardclan.com/forum/"
}

public OnPluginStart()
{  
	//Cvars
	CreateConVar("abner_rss_version", PLUGIN_VERSION, "Plugin version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED);
	g_hPath = CreateConVar("rss_path", "round_start", "Path off sounds in /YOURGAMEFOLDER/sound");
	g_hPlayType = CreateConVar("rss_play_type", "1", "1 - Random, 2- Play in queue");
	
	//ClientPrefs
	g_AbNeRCookie = RegClientCookie("AbNeR Round Start Sounds", "", CookieAccess_Private);
	new info;
	SetCookieMenuItem(SoundCookieHandler, any:info, "AbNeR Round Start Sounds");
	
	for (new i = MaxClients; i > 0; --i)
    {
        if (!AreClientCookiesCached(i))
        {
            continue;
        }
        OnClientCookiesCached(i);
    }
	
	LoadTranslations("common.phrases");
	LoadTranslations("abner_rss.phrases");
		
	AutoExecConfig(true, "abner_rss");

	RegAdminCmd("rss_refresh", CommandLoad, ABNER_ADMINFLAG);
	RegConsoleCmd("rss", abnermenu);
	
	HookConVarChange(g_hPath, PathChange);
	HookConVarChange(g_hPlayType, PathChange);
	
	decl String:theFolder[40];
	GetGameFolderName(theFolder, sizeof(theFolder));
	CSGO = StrEqual(theFolder, "csgo");
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}


stock bool:IsValidClient(client)
{
	if(client <= 0 ) return false;
	if(client > MaxClients) return false;
	if(!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}


public SoundCookieHandler(client, CookieMenuAction:action, any:info, String:buffer[], maxlen)
{
	OnClientCookiesCached(client);
	abnermenu(client, 0);
} 

public OnClientPutInServer(client)
{
	CreateTimer(3.0, msg, client);
}

public Action:msg(Handle:timer, any:client)
{
	if(IsValidClient(client))
	{
		CPrintToChat(client, "{default}{green}[AbNeR RSS]{default}%t", "JoinMsg");
	}
}


public Action:abnermenu(client, args)
{
	GetClientCookie(client, g_AbNeRCookie, sCookieValue, sizeof(sCookieValue));
	new cookievalue = StringToInt(sCookieValue);
	new Handle:g_AbNeRMenu = CreateMenu(AbNeRMenuHandler);
	SetMenuTitle(g_AbNeRMenu, "Round Start Sounds by AbNeR_CSS");
	decl String:Item[128];
	if(cookievalue == 0)
	{
		Format(Item, sizeof(Item), "%t %t", "RSS_ON", "Selected"); 
		AddMenuItem(g_AbNeRMenu, "ON", Item);
		Format(Item, sizeof(Item), "%t", "RSS_OFF"); 
		AddMenuItem(g_AbNeRMenu, "OFF", Item);
	}
	else
	{
		Format(Item, sizeof(Item), "%t", "RSS_ON");
		AddMenuItem(g_AbNeRMenu, "ON", Item);
		Format(Item, sizeof(Item), "%t %t", "RSS_OFF", "Selected"); 
		AddMenuItem(g_AbNeRMenu, "OFF", Item);
	}
	SetMenuExitBackButton(g_AbNeRMenu, true);
	SetMenuExitButton(g_AbNeRMenu, true);
	DisplayMenu(g_AbNeRMenu, client, 30);
}

public AbNeRMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	new Handle:g_AbNeRMenu = CreateMenu(AbNeRMenuHandler);
	if (action == MenuAction_DrawItem)
	{
		return ITEMDRAW_DEFAULT;
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		ShowCookieMenu(param1);
	}
	else if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0:
			{
				SetClientCookie(param1, g_AbNeRCookie, "0");
				abnermenu(param1, 0);
			}
			case 1:
			{
				SetClientCookie(param1, g_AbNeRCookie, "1");
				abnermenu(param1, 0);
			}
		}
		CloseHandle(g_AbNeRMenu);
	}
	return 0;
}



public OnClientCookiesCached(client)
{
    decl String:sValue[8];
    GetClientCookie(client, g_AbNeRCookie, sValue, sizeof(sValue));
    
    g_bClientPreference[client] = (sValue[0] != '\0' && StringToInt(sValue));
} 


public PathChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{       
	OnMapStart();
}

public OnMapStart()
{
	LoadSounds(0);
}
 
LoadSounds(client)
{
	new namelen;
	new FileType:type;
	new String:name[64];
	new String:soundname[64];
	new String:soundname2[64];
	decl String:soundpath[PLATFORM_MAX_PATH];
	decl String:soundpath2[PLATFORM_MAX_PATH];
	GetConVarString(g_hPath, soundpath, sizeof(soundpath));
	Format(soundpath2, sizeof(soundpath2), "sound/%s/", soundpath);
	new Handle:pluginsdir = OpenDirectory(soundpath2);
	g_Sounds = 0;
	SoundsSucess = (pluginsdir != INVALID_HANDLE);
	if(SoundsSucess)
	{
		while(ReadDirEntry(pluginsdir,name,sizeof(name),type))
		{
			namelen = strlen(name) - 4;
			if(StrContains(name,".mp3",false) == namelen)
			{
				Format(soundname, sizeof(soundname), "sound/%s/%s", soundpath, name);
				AddFileToDownloadsTable(soundname);
				Format(soundname2, sizeof(soundname2), "%s/%s", soundpath, name);
				if(g_Sounds < MAX_SOUNDS-1)
					sounds[g_Sounds++] = soundname2;
			}
		}
		SoundsSucess = g_Sounds > 0;
		if(IsValidClient(client))
			ReplyToCommand(client, "[AbNeR RSS] SOUNDS: %d sounds loaded.", g_Sounds);
		PrintToServer("[AbNeR RSS] SOUNDS: %d sounds loaded.", g_Sounds);
	}
	else
	{
		if(IsValidClient(client))
			ReplyToCommand(client, "[AbNeR RSS] ERROR: Invalid \"rss_path\".");
		PrintToServer("[AbNeR RSS] ERROR: Invalid \"rss_path\".");
	}
}


DeleteSound(rnd_sound)
{
	for (new i = 0; i < g_Sounds; i++)
	{
		if(i >= rnd_sound)
			sounds[i] = sounds[i+1];
	}
	if(--g_Sounds == 0)
		LoadSounds(0);
}

PlaySoundCSGO()
{
	new soundToPlay;
	if(GetConVarInt(g_hPlayType) == 1)
	{
		soundToPlay = GetRandomInt(0, g_Sounds-1);
	}
	else
	{
		soundToPlay = 0;
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		GetClientCookie(i, g_AbNeRCookie, sCookieValue, sizeof(sCookieValue));
		new cookievalue = StringToInt(sCookieValue);
		if(IsValidClient(i) && cookievalue == 0)
		{
			ClientCommand(i, "playgamesound Music.StopAllMusic");
			ClientCommand(i, "play *%s", sounds[soundToPlay]);
		}
	}
	DeleteSound(soundToPlay);
}

PlaySound()
{
	new soundToPlay;
	if(GetConVarInt(g_hPlayType) == 1)
	{
		soundToPlay = GetRandomInt(0, g_Sounds-1);
	}
	else
	{
		soundToPlay = 0;
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		GetClientCookie(i, g_AbNeRCookie, sCookieValue, sizeof(sCookieValue));
		new cookievalue = StringToInt(sCookieValue);
		if(IsValidClient(i) && cookievalue == 0)
		{
			ClientCommand(i, "play %s", sounds[soundToPlay]);
		}
	}
	DeleteSound(soundToPlay);
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
		if(SoundsSucess)
			CSGO ? PlaySoundCSGO() : PlaySound();  //PRETTY COOL IF-ELSE METHOD
		else
			PrintToServer("[AbNeR RSS] SOUNDS ERROR: Sounds not loaded.");
}


public Action:CommandLoad(client, args)
{   
	LoadSounds(client);
	return Plugin_Handled;
}








