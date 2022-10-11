#define PUBVAR_MAXCLIENTS
#define PUBVAR_NULL_STRING

#include <sourcemod>
#include <sdktools>
#include <macros>
#include <basecomm>
#include <clientprefs>
#include <chatmodern>
#include <ripext>

static const char sCommand[] = "!vk";   /**< Команда для открытия настроек и отправки сообщений */

#define DB_TABLE "source_connection"    /**< Имя таблицы */

#define HOSTNAME "hostname"     /**< Значение server для взятия имени сервера из hostname */

/**
 * Размер сообщения
 */
#define PEER_ID_SIZE    12
#define MEMBER_SIZE     32 * 3
#define SEND_SIZE       PEER_ID_SIZE + MEMBER_SIZE + CHAT_MODERN_NEW_SIZE

/**
 * Размер отправляемых данных о игроках
 */
#define TEAM_MUTE_SIZE  1
#define FRAGS_SIZE      11
#define DEATHS_SIZE     11
#define TIME_SIZE       29
#define IP_SIZE         15
#define STEAMID_SIZE    MAX_AUTHID_LENGTH - 1
#define NAME_SIZE       MAX_NAME_LENGTH - 1
#define DATA_SIZE       (TEAM_MUTE_SIZE + FRAGS_SIZE + DEATHS_SIZE + TIME_SIZE + IP_SIZE + STEAMID_SIZE + NAME_SIZE + 7) * (MAXPLAYERS - 1)

/**
 * Разделитель
 */
#define DELIMETER 0x01
#define DELIMETER_CON "\x01"

#define FAILED "source_connection_failed"   /**< Ошибка обработки команды */
#define SUCCESS "source_connection_success" /**< Успех обработки команды */

#define VOLUME_MAX          100     /**< Максимальная громкость (до 127) */
#define VOLUME_MIN          10      /**< Минимальная громкость (до 0) */
#define VOLUME_ACCURACY     10      /**< Сколько убавлять/прибавлять за раз */
#define VOLUME_ACCURACY_CON "10"    /**< Сколько убавлять/прибавлять за раз (строка) */

#if SEND_SIZE < DATA_SIZE
char sBuffer[DATA_SIZE];
#else
char sBuffer[SEND_SIZE];
#endif
Database hDB;
DBStatement hPlayersQuery;

enum RequestType
{
    RType_Message = 0,
    RType_Players
}

#define SOUND_MSG   0   /**< Звук входящего сообщения */
#define SOUND_ERROR 1   /**< Звук ошибки отправки сообщения */

#define SOUND_SIZE_1 2
#define SOUND_SIZE_2 PLATFORM_MAX_PATH

#define PHRASE_SIZE 32      /**< Макс. размер фразы */
#define PHRASE_SUFFIX "_Send"   /**< Суффикс для формата отправляемого сообщения */
static const char sPhraseSuffix[] = PHRASE_SUFFIX;    /**< Суффикс для формата отправляемого сообщения (sizeof) */

/**
 * Является ли чат ЛС
 * 
 * @param %1        peer_id чата
 * 
 * @return          true если является, false если нет
 */
#define IS_PM(%1) (%1 < 2000000000)

/**
 * Является ли чат ЛС (строка)
 * 
 * @param %1        peer_id чата
 * 
 * @return          true ели является, false если нет
 */
#define IS_PM_STR(%1) (StringToInt(%1) < 2000000000)

char sDBPrefix[16], sAccessToken[256], sVersion[6], sServer[128],
    ARR2_CREATE(sSounds, SOUND_SIZE);
int iAntiFlood[MAXPLAYERS + 1], iSettings[MAXPLAYERS + 1], iOtherLength, iOtherPagination, iOtherMax;
Handle hAntiFloodAllow[MAXPLAYERS + 1];
ChatModern chatm;
DataPack hPack[MAXPLAYERS + 1];
KeyValues hChats;

#define COOKIE view_as<Cookie>(hAntiFloodAllow[0])

#define ANTIFLOOD iAntiFlood[0]
#define CHATS_COUNT iSettings[0]

#define OTHER_NAME_SIZE 64      /**< Размер отправителя в меню */
#define OTHER view_as<ArrayList>(hPack[0])

#define GET_MSG(%1)             (iSettings[%1] & 1)
#define GET_ERROR(%1)           (iSettings[%1] & (1 << 1))
#define GET_SHOW(%1)            (iSettings[%1] & (1 << 2))
#define GET_MSG_VOLUME(%1)      (iSettings[%1] >> 3 & 127)
#define GET_ERROR_VOLUME(%1)    (iSettings[%1] >> 10)

#define SET_MSG(%1,%2)          iSettings[%1] = %2 ? iSettings[%1] | 1 : iSettings[%1] ^ 1
#define SET_ERROR(%1,%2)        iSettings[%1] = %2 ? iSettings[%1] | (1 << 1) : iSettings[%1] ^ (1 << 1)
#define SET_SHOW(%1,%2)         iSettings[%1] = %2 ? iSettings[%1] | (1 << 2) : iSettings[%1] ^ (1 << 2)
#define SET_MSG_VOLUME(%1,%2)   iSettings[%1] = iSettings[%1] & (127 << 10) | %2 << 3 | iSettings[%1] & 7
#define SET_ERROR_VOLUME(%1,%2) iSettings[%1] = %2 << 10 | iSettings[%1] & (127 << 3) | iSettings[%1] & 7

#define SETTINGS_DEFAULT VOLUME_MAX << 10 | VOLUME_MAX << 3 | 1 << 2 | 1 << 1 | 1   /**< Настройки по умолчанию */

#define API_METHOD_URL "https://api.vk.com/method/messages.send"    /**< URL метода для отправки сообщения */
#define CODE_BLOCK_PERMISSION 901       /**< Код запрета отправки сообщения в чат */

public Plugin myinfo =
{
    name = "Source Connection",
    author = "DeathScore13",
    description = "Серверная часть модуля Source Connection для BotEngineVK",
    version = "1.0.0",
    url = "https://github.com/deathscore13/source_connection"
};

public void OnPluginStart()
{
    char error[128];
    hDB = SQL_Connect("source_connection", true, sz(error));
    if (error[0])
        SetFailState("SQL_Connect error: %s", error);
    
    KeyValues kv = new KeyValues("source_connection");
    BuildPath(Path_SM, sz(sBuffer), "configs/source_connection.ini");
    if (!FileExists(sBuffer, false))
    {
        kv.JumpToKey("settings", true);
        {
            kv.SetString("db_prefix", "botvk_");
            kv.SetString("db_charset", "utf8bm4");

            kv.SetString("access_token", "ключ");
            kv.SetString("v", "5.131");
            kv.SetNum("antiflood", 3);
            kv.SetString("server", "hostname");
            kv.SetString("sound_msg", "source_connection/msg.mp3");
            kv.SetString("sound_error", "source_connection/error.mp3");

            kv.SetNum("other_chats", 1);
            kv.SetNum("other_pagination", 5);
            kv.SetNum("other_max", 10);
        }
        kv.Rewind();

        kv.JumpToKey("chats", true);
        {
            kv.SetString("2000000001", "GeneralChat");
            kv.SetString("2000000002", "AdminChat");
        }
        kv.Rewind();

        kv.ExportToFile(sBuffer);
        SetFailState("A new configuration has been generated. Please set up the config file before using");
    }
    
    if (kv.ImportFromFile(sBuffer))
    {
        kv.JumpToKey("settings");
        {
            kv.GetString("db_prefix", sz(sDBPrefix));
            kv.GetString("db_charset", sz(sBuffer));
            hDB.SetCharset(sBuffer);

            kv.GetString("access_token", sz(sAccessToken));
            kv.GetString("v", sz(sVersion));
            ANTIFLOOD = kv.GetNum("antiflood");
            kv.GetString("server", sz(sServer));
            kv.GetString("sound_msg", ARR2_WRITE(sSounds, SOUND_SIZE, SOUND_MSG, 0));
            kv.GetString("sound_error", ARR2_WRITE(sSounds, SOUND_SIZE, SOUND_ERROR, 0));

            if (kv.GetNum("other_chats"))
            {
                iOtherPagination = kv.GetNum("other_pagination");
                iOtherMax = kv.GetNum("other_max");
                BuildPath(Path_SM, sz(sBuffer), "data/source_connection.ini");
                if (FileExists(sBuffer))
                {
                    OTHER = new ArrayList(PHRASE_SIZE);

                    KeyValues other = new KeyValues("other_chats");
                    other.ImportFromFile(sBuffer);
                    if (other.GotoFirstSubKey(false))
                    {
                        do
                        {
                            other.GetSectionName(sz(sBuffer));
                            OTHER.PushString(sBuffer);

                            other.GetString("member", sz(sBuffer));
                            OTHER.PushString(sBuffer);

                            other.GetString("date", sz(sBuffer));
                            OTHER.PushString(sBuffer);
                        }
                        while ((iOtherLength += 3) / 3 < iOtherMax && other.GotoNextKey(false));
                    }
                    other.Close();
                }
                else
                {
                    OTHER = new ArrayList(PHRASE_SIZE);
                }
            }
        }
        kv.Rewind();
        
        kv.JumpToKey("chats");
        {
            (hChats = new KeyValues("chats")).Import(kv);
            kv.GotoFirstSubKey(false);
            do
            {
                CHATS_COUNT++;
            }
            while (kv.GotoNextKey(false));
        }
    }
    else
    {
        SetFailState("Configuration load error");
    }
    kv.Close();

    FormatEx(sz(sBuffer), "CREATE TABLE IF NOT EXISTS %s"...DB_TABLE..." (id INT NOT NULL AUTO_INCREMENT, \
        buffer VARCHAR(%d) NOT NULL, PRIMARY KEY (id))", sDBPrefix, sizeof(sBuffer));
    SQL_FastQuery(hDB, sBuffer);

    FormatEx(sz(sBuffer), "UPDATE %s"...DB_TABLE..." SET buffer = ? WHERE id = ?", sDBPrefix);
    hPlayersQuery = SQL_PrepareQuery(hDB, sBuffer, sz(error));
    if (error[0])
        SetFailState("SQL_PrepareQuery error: %s", sBuffer);

    COOKIE = new Cookie("source_connection_settings", "Players settings", CookieAccess_Private);
    int i;
    while (++i <= MaxClients)
        if (AreClientCookiesCached(i))
            OnClientCookiesCached(i);

    chatm = new ChatModern(GetEngineVersion());
    LoadTranslations("source_connection");
    RegServerCmd("source_connection", SrvCmd_source_connection);
}

public void OnPluginEnd()
{
    if (OTHER)
    {
        KeyValues kv = new KeyValues("other_chats");
        int i;
        while (i < iOtherLength)
        {
            OTHER.GetString(i++, sz(sBuffer));
            kv.JumpToKey(sBuffer, true);
            {
                OTHER.GetString(i++, sz(sBuffer));
                kv.SetString("member", sBuffer);

                OTHER.GetString(i++, sz(sBuffer));
                kv.SetString("date", sBuffer);
            }
            kv.Rewind();
        }
        BuildPath(Path_SM, sz(sBuffer), "data/source_connection.ini");
        kv.ExportToFile(sBuffer);
        kv.Close();
    }
}

public void OnMapStart()
{
    if (ARR2_POS(sSounds, SOUND_SIZE, SOUND_MSG, 0))
    {
        FormatEx(sz(sBuffer), "sound/%s", ARR2_POS(sSounds, SOUND_SIZE, SOUND_MSG, 0));
        AddFileToDownloadsTable(sBuffer);
        PrecacheSound(ARR2_POS(sSounds, SOUND_SIZE, SOUND_MSG, 0), true);
    }
    
    if (ARR2_POS(sSounds, SOUND_SIZE, SOUND_ERROR, 0))
    {
        FormatEx(sz(sBuffer), "sound/%s", ARR2_POS(sSounds, SOUND_SIZE, SOUND_ERROR, 0));
        AddFileToDownloadsTable(sBuffer);
        PrecacheSound(ARR2_POS(sSounds, SOUND_SIZE, SOUND_ERROR, 0), true);
    }

    int i;
    if (++i <= MaxClients)
        iAntiFlood[i] = 0;
}

public void OnConfigsExecuted()
{
    if (!strcmp(HOSTNAME, sServer))
    {
        ConVar cvar = FindConVar("hostname");
        cvar.AddChangeHook(ConVarChangedCB);
        cvar.GetString(sz(sServer));
    }
}

void ConVarChangedCB(ConVar convar, const char[] oldValue, const char[] newValue)
{
    strcopy(sz(sServer), newValue);
}

public void OnClientCookiesCached(int client)
{
    if (IsFakeClient(client))
        return;
    
    COOKIE.Get(client, sz(sBuffer));
    iSettings[client] = sBuffer[0] ? StringToInt(sBuffer) : SETTINGS_DEFAULT;
}

public void OnClientDisconnect(int client)
{
    IntToString(iSettings[client], sz(sBuffer));
    COOKIE.Set(client, sBuffer);
    iSettings[client] = 0;

    if (hAntiFloodAllow[client])
        delete hAntiFloodAllow[client];
}

Action SrvCmd_source_connection(int args)
{
    if (args != 2)
    {
        PrintToServer("Invalid response (args != 2)");
        return Plugin_Handled;
    }

    GetCmdArg(2, sz(sBuffer));
    int id = StringToInt(sBuffer);
    FormatEx(sz(sBuffer), "SELECT buffer FROM %s"...DB_TABLE..." WHERE id = %d", sDBPrefix, id);
    DBResultSet res = SQL_Query(hDB, sBuffer);
    if (!res.FetchRow())
    {
        res.Close();
        PrintToServer(FAILED);
        return Plugin_Handled;
    }

    GetCmdArg(1, sz(sBuffer));
    switch (StringToInt(sBuffer))
    {
        case RType_Message:
        {
            res.FetchString(0, sz(sBuffer));

            int member = FindCharInString(sBuffer, DELIMETER) + 1;
            sBuffer[member - 1] = '\0';

            int msg = FindCharInString(sBuffer[member], DELIMETER) + member + 1;
            sBuffer[msg - 1] = '\0';
            
            char buffer[PHRASE_SIZE];
            hChats.GetString(sBuffer, sz(buffer));
            if (!buffer[0])
            {
                if (OTHER)
                {
                    AddOtherChat(sBuffer, sBuffer[member]);
                }
                else
                {
                    PrintToServer(FAILED);

                    // SourcePawn уебан, который не умеет break в switch
                    res.Close();
                    return Plugin_Handled;
                }
            }
            GetPhrase(sBuffer, sz(buffer));

            int i;
            while (++i <= MaxClients)
            {
                if (IsClientInGame(i) && !IsFakeClient(i) && GET_SHOW(i))
                {
                    chatm.CPrintToChat(i, "%T%T", "Prefix", i, "Sender", i, sBuffer[member], buffer, sBuffer);
                    chatm.ReplaceOld(sBuffer[msg], sizeof(sBuffer) - msg);
                    chatm.CTextMsg(i, "%s", sBuffer[msg]);

                    if (ARR2_POS(sSounds, SOUND_SIZE, SOUND_MSG, 0) && GET_MSG(i))
                        EmitSoundToClient(i, ARR2_POS(sSounds, SOUND_SIZE, SOUND_MSG, 0), _, _, _, _, float(GET_MSG_VOLUME(i)) / VOLUME_MAX);
                }
            }

            PrintToServer(SUCCESS);
        }
        case RType_Players:
        {
            int i, pos;
            char ip[16], steamid[MAX_AUTHID_LENGTH], name[MAX_NAME_LENGTH];
            sBuffer[0] = '\0';
            while (++i <= MaxClients)
            {
                if (IsClientInGame(i) && !IsFakeClient(i))
                {
                    GetClientIP(i, sz(ip));
                    GetClientAuthId(i, AuthId_Steam2, sz(steamid));
                    GetClientName(i, sz(name));

                    pos += FormatEx(sBuffer[pos], sizeof(sBuffer) - pos,
                    /* 00 */    "%d"...DELIMETER_CON...
                    /* 01 */    "%d"...DELIMETER_CON...
                    /* 02 */    "%d"...DELIMETER_CON...
                    /* 03 */    "%f"...DELIMETER_CON...
                    /* 04 */    "%s"...DELIMETER_CON...
                    /* 05 */    "%s"...DELIMETER_CON...
                    /* 06 */    "%s\n",

                    /* 00 */    GetClientTeam(i) << 1 | view_as<int>(BaseComm_IsClientGagged(i)),
                    /* 01 */    GetClientFrags(i),
                    /* 02 */    GetClientDeaths(i),
                    /* 03 */    GetClientTime(i),
                    /* 04 */    ip,
                    /* 05 */    steamid,
                    /* 06 */    name
                    );
                }
            }
            
            if (pos && sBuffer[--pos] == '\n')
                sBuffer[pos] = '\0';
            
            hPlayersQuery.BindString(0, sBuffer, false);
            hPlayersQuery.BindInt(1, id);
            SQL_Execute(hPlayersQuery);

            PrintToServer(SUCCESS);
        }
        
        default:
            PrintToServer(FAILED);
    }

    res.Close();
    return Plugin_Handled;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
    if (!client || strncmp(sArgs, sz(sCommand) - 1) || sArgs[sizeof(sCommand) - 1] && sArgs[sizeof(sCommand) - 1] != ' ')
        return;
    
    strcopy(sz(sBuffer), sArgs[sizeof(sCommand) - 1]);
    TrimString(sBuffer);

    if (sBuffer[0])
    {
        if (BaseComm_IsClientGagged(client))
        {
            chatm.CPrintToChat(client, "%T", "Muted", client);
            if (ARR2_POS(sSounds, SOUND_SIZE, SOUND_ERROR, 0) && GET_ERROR(client))
                EmitSoundToClient(client, ARR2_POS(sSounds, SOUND_SIZE, SOUND_ERROR, 0), _, _, _, _,
                    float(GET_ERROR_VOLUME(client)) / VOLUME_MAX);
            return;
        }

        int res = GetTime();
        if (res < iAntiFlood[client] + ANTIFLOOD)
        {
            iAntiFlood[client] += ANTIFLOOD;
            res = iAntiFlood[client] - res;
            chatm.CPrintToChat(client, "%T%T", "Prefix", client, "AntiFlood", client, res);

            if (hAntiFloodAllow[client])
                hAntiFloodAllow[client].Close();
            
            hAntiFloodAllow[client] = CreateTimer(float(res), TimerCB, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
            return;
        }
        iAntiFlood[client] = res;
        
        if (hPack[client])
            hPack[client].Close();
        
        hPack[client] = new DataPack();
        hPack[client].WriteString(sBuffer);

        if (CHATS_COUNT || OTHER)
        {
            MenuChats(client);
        }
        else
        {
            char peerId[PEER_ID_SIZE];
            hChats.GotoFirstSubKey(false);
            hChats.GetSectionName(sz(peerId));
            Send(client, peerId);
        }
    }
    else
    {
        Panel hPanel = new Panel();
        FormatEx(sz(sBuffer), "%T", "MenuTitle", client);
        hPanel.SetTitle(sBuffer);

        FormatEx(sz(sBuffer), "%T", "Show", client, GET_SHOW(client) ? "On" : "Off");
        hPanel.DrawItem(sBuffer);

        if (ARR2_POS(sSounds, SOUND_SIZE, SOUND_MSG, 0) || ARR2_POS(sSounds, SOUND_SIZE, SOUND_ERROR, 0))
        {
            FormatEx(sz(sBuffer), "%T", "Volume", client);
            hPanel.DrawItem(sBuffer);

            FormatEx(sz(sBuffer), "%T", "Sounds", client);
            hPanel.DrawItem(sBuffer);
        }

        hPanel.DrawText(" ");
        FormatEx(sz(sBuffer), "%T", "Use", client);
        hPanel.DrawText(sBuffer);

        hPanel.DrawText(" ");
        FormatEx(sz(sBuffer), "%T", "Exit", client);
        hPanel.DrawItem(sBuffer);

        hPanel.Send(client, MenuHandler_Menu, MENU_TIME_FOREVER);
        hPanel.Close();
    }
}

Action TimerCB(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid)
    if (client)
    {
        hAntiFloodAllow[client] = null;
        chatm.CPrintToChat(client, "%T%T", "Prefix", client, "AntiFloodAllow", client);
    }
}

void MenuChats(int client)
{
    Menu menu = new Menu(MenuHandler_Chats);
    menu.SetTitle("%T", "Select", client);

    if (OTHER)
    {
        FormatEx(sz(sBuffer), "%T", "OtherChats", client);
        menu.AddItem(NULL_STRING, sBuffer);
    }

    char peerId[PEER_ID_SIZE], phrase[PHRASE_SIZE];
    hChats.GotoFirstSubKey(false);
    do
    {
        hChats.GetSectionName(sz(peerId));
        hChats.GetString(NULL_STRING, sz(phrase));
        FormatEx(sz(sBuffer), "%T", phrase, client, peerId);
        menu.AddItem(peerId, sBuffer);
    }
    while (hChats.GotoNextKey(false));
    hChats.Rewind();
    menu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_Chats(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        if (item || !OTHER)
        {
            char peerId[PEER_ID_SIZE];
            menu.GetItem(item, sz(peerId));
            Send(client, peerId);
        }
        else
        {
            Menu pm = new Menu(MenuHandler_Other);
            pm.SetTitle("%T", "Select", client);
            char peerId[PEER_ID_SIZE], sender[OTHER_NAME_SIZE], phrase[PHRASE_SIZE];
            if (iOtherLength)
            {
                int i;
                while (i < iOtherLength)
                {
                    OTHER.GetString(i++, sz(peerId));
                    GetPhrase(peerId, sz(phrase));
                    OTHER.GetString(i++, sz(sender));
                    OTHER.GetString(i++, sz(sBuffer));
                    Format(sz(sBuffer), "%T", "OtherSender", client, sender, phrase, peerId, sBuffer);
                    pm.AddItem(peerId, sBuffer);
                }
                pm.Pagination = iOtherPagination;
            }
            else
            {
                FormatEx(sz(sBuffer), "%T", "OtherNull", client);
                pm.AddItem(NULL_STRING, sBuffer, ITEMDRAW_DISABLED);
            }
            pm.ExitBackButton = true;
            pm.Display(client, MENU_TIME_FOREVER);
        }
    }
    else if (action == MenuAction_End)
    {
        menu.Close();
    }
}

int MenuHandler_Other(Menu menu, MenuAction action, int client, int item)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            hPack[client].Reset();
            hPack[client].ReadString(sz(sBuffer));

            char peerId[PEER_ID_SIZE];
            menu.GetItem(item, sz(peerId));
            char steamid[MAX_AUTHID_LENGTH];
            GetClientAuthId(client, AuthId_Steam2, sz(steamid));
            Format(sz(sBuffer), "%t", "OtherChats"...PHRASE_SUFFIX, client, steamid, sBuffer, sServer);
            SendEx(client, peerId, sBuffer);

            delete hPack[client];
        }
        case MenuAction_Cancel:
        {
            if (item == MenuCancel_ExitBack)
                MenuChats(client);
        }
        case MenuAction_End:
        {
            menu.Close();
        }
    }
}

int MenuHandler_Menu(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        if (item == 1)
        {
            SET_SHOW(client, !GET_SHOW(client));
            OnClientSayCommand_Post(client, NULL_STRING, sCommand);
        }
        else if (ARR2_POS(sSounds, SOUND_SIZE, SOUND_MSG, 0) || ARR2_POS(sSounds, SOUND_SIZE, SOUND_ERROR, 0))
        {
            if (item == 2)
                MenuVolume(client);
            else if (item == 3)
                MenuSounds(client);
        }
    }
}

void MenuVolume(int client)
{
    Panel hPanel = new Panel();
    FormatEx(sz(sBuffer), "%T", "Volume", client);
    hPanel.SetTitle(sBuffer);

    if (ARR2_POS(sSounds, SOUND_SIZE, SOUND_MSG, 0))
    {
        FormatEx(sz(sBuffer), "%T", "VolumeMsg", client, GET_MSG_VOLUME(client));
        hPanel.DrawText(sBuffer);
        hPanel.DrawItem("+"...VOLUME_ACCURACY_CON..."%");
        hPanel.DrawItem("-"...VOLUME_ACCURACY_CON..."%");
        hPanel.DrawText(" ");
    }
    
    if (ARR2_POS(sSounds, SOUND_SIZE, SOUND_ERROR, 0))
    {
        FormatEx(sz(sBuffer), "%T", "VolumeError", client, GET_ERROR_VOLUME(client));
        hPanel.DrawText(sBuffer);
        hPanel.DrawItem("+"...VOLUME_ACCURACY_CON..."%");
        hPanel.DrawItem("-"...VOLUME_ACCURACY_CON..."%");
        hPanel.DrawText(" ");
    }
    
    FormatEx(sz(sBuffer), "%T", "Back", client);
    hPanel.DrawItem(sBuffer);

    hPanel.Send(client, MenuHandler_Volume, MENU_TIME_FOREVER);
    hPanel.Close();
}

int MenuHandler_Volume(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        if (item == 1 || item == 2)
        {
            SetVolume(client, ARR2_POS(sSounds, SOUND_SIZE, SOUND_MSG, 0), item == 1 ? VOLUME_ACCURACY : -VOLUME_ACCURACY);
        }
        else if ((item == 3 || item == 4) &&
            ARR2_POS(sSounds, SOUND_SIZE, SOUND_MSG, 0) &&
            ARR2_POS(sSounds, SOUND_SIZE, SOUND_ERROR, 0))
        {
            SetVolume(client, 0, item == 3 ? VOLUME_ACCURACY : -VOLUME_ACCURACY);
        }
        else
        {
            OnClientSayCommand_Post(client, NULL_STRING, sCommand);
            return;
        }
        MenuVolume(client);
    }
}

void SetVolume(int client, int sound, int change)
{
    if (sound)
    {
        if (0 < change && VOLUME_MAX < GET_MSG_VOLUME(client) + change)
        {
            chatm.CPrintToChat(client, "%T%T", "Prefix", client, "VolumeMax", client);
        }
        else if (change < 0 && GET_MSG_VOLUME(client) + change < VOLUME_MIN)
        {
            chatm.CPrintToChat(client, "%T%T", "Prefix", client, "VolumeMin", client);
        }
        else
        {
            SET_MSG_VOLUME(client, GET_MSG_VOLUME(client) + change); 
        }
    }
    else
    {
        if (0 < change && VOLUME_MAX < GET_ERROR_VOLUME(client) + change)
        {
            chatm.CPrintToChat(client, "%T%T", "Prefix", client, "VolumeMax", client);
        }
        else if (change < 0 && GET_ERROR_VOLUME(client) + change < VOLUME_MIN)
        {
            chatm.CPrintToChat(client, "%T%T", "Prefix", client, "VolumeMin", client);
        }
        else
        {
            SET_ERROR_VOLUME(client, GET_ERROR_VOLUME(client) + change); 
        }
    }
}

void MenuSounds(int client)
{
    Panel hPanel = new Panel();
    FormatEx(sz(sBuffer), "%T", "Sounds", client);
    hPanel.SetTitle(sBuffer);
    
    if (ARR2_POS(sSounds, SOUND_SIZE, SOUND_MSG, 0))
    {
        FormatEx(sz(sBuffer), "%T", "SoundMsg", client, GET_MSG(client) ? "On" : "Off");
        hPanel.DrawItem(sBuffer);
    }

    if (ARR2_POS(sSounds, SOUND_SIZE, SOUND_ERROR, 0))
    {
        FormatEx(sz(sBuffer), "%T", "SoundError", client, GET_ERROR(client) ? "On" : "Off");
        hPanel.DrawItem(sBuffer);
    }
    
    hPanel.DrawText(" ");
    FormatEx(sBuffer, sizeof(sBuffer), "%T", "Back", client);
    hPanel.DrawItem(sBuffer);

    hPanel.Send(client, MenuHandler_Sounds, MENU_TIME_FOREVER);
    hPanel.Close();
}

int MenuHandler_Sounds(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        if (item == 1)
        {
            if (ARR2_POS(sSounds, SOUND_SIZE, SOUND_MSG, 0))
                SET_MSG(client, !GET_MSG(client));
            else
                SET_ERROR(client, !GET_ERROR(client));
        }
        else if (item == 2 && ARR2_POS(sSounds, SOUND_SIZE, SOUND_ERROR, 0))
        {
            SET_ERROR(client, !GET_ERROR(client));
        }
        else
        {
            OnClientSayCommand_Post(client, NULL_STRING, sCommand);
            return;
        }
        MenuSounds(client);
    }
}

void Send(int client, const char[] peerId)
{
    hPack[client].Reset();
    hPack[client].ReadString(sz(sBuffer));
    
    char phrase[PHRASE_SIZE + sizeof(sPhraseSuffix) - 1];
    hChats.GetString(peerId, sz(phrase));

    int len = strlen(phrase);
    char steamid[MAX_AUTHID_LENGTH];
    strcopy(phrase[len], sizeof(phrase) - len, sPhraseSuffix);
    GetClientAuthId(client, AuthId_Steam2, sz(steamid));
    Format(sz(sBuffer), "%t", phrase, client, steamid, sBuffer, sServer);
    SendEx(client, peerId, sBuffer);

    delete hPack[client];
}

void SendEx(int client, const char[] peerId, const char[] message)
{
    HTTPRequest request = new HTTPRequest(API_METHOD_URL);
    request.AppendFormParam("access_token", sAccessToken);
    request.AppendFormParam("v", sVersion);
    request.AppendFormParam("random_id", "%d", GetRandomInt(0, 2147483647));
    request.AppendFormParam("peer_id", peerId);
    request.AppendFormParam("dont_parse_links", "1");
    request.AppendFormParam("disable_mentions", "1");
    request.AppendFormParam("message", "%s", message);
    request.PostForm(HTTPRequestCB, GetClientUserId(client));
}

void HTTPRequestCB(HTTPResponse response, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!client)
        return;
    
    if (response.Status == HTTPStatus_OK)
    {
        if (response.Data.ToString(sz(sBuffer), JSON_COMPACT))
        {
            JSONObject json = JSONObject.FromString(sBuffer, JSON_COMPACT);
            if (json.HasKey("error"))
            {
                JSONObject error = view_as<JSONObject>(json.Get("error"));
                view_as<JSON>(error).ToString(sz(sBuffer), JSON_COMPACT);
                error.Close();

                error = JSONObject.FromString(sBuffer, JSON_COMPACT);
                int code = error.GetInt("error_code");
                if (code == CODE_BLOCK_PERMISSION)
                {
                    chatm.CPrintToChat(client, "%T%T", "Prefix", client, "FailedErrorPermission", client, code, sBuffer);
                }
                else
                {
                    error.GetString("error_msg", sz(sBuffer));
                    chatm.CPrintToChat(client, "%T%T", "Prefix", client, "FailedError", client, code, sBuffer);
                }
                error.Close();
            }
            else
            {
                chatm.CPrintToChat(client, "%T%T", "Prefix", client, "Successful", client);
                json.Close();
                return;
            }
            json.Close();
        }
        else
        {
            chatm.CPrintToChat(client, "%T%T", "Prefix", client, "Failed", client);
        }
    }
    else
    {
        chatm.CPrintToChat(client, "%T%T", "Prefix", client, "Failed", client);
    }

    if (ARR2_POS(sSounds, SOUND_SIZE, SOUND_ERROR, 0) && GET_ERROR(client))
        EmitSoundToClient(client, ARR2_POS(sSounds, SOUND_SIZE, SOUND_ERROR, 0), _, _, _, _, float(GET_ERROR_VOLUME(client)) / VOLUME_MAX);
}

void GetPhrase(const char[] peerId, char[] phrase, int maxlen)
{
    hChats.GetString(peerId, phrase, maxlen);

    if (!phrase[0])
        strcopy(phrase, maxlen, IS_PM_STR(peerId) ? "PM" : "UnknownChat");
}

void AddOtherChat(const char[] peerId, const char[] member)
{
    int i;
    char buffer[PHRASE_SIZE];
    while (i < iOtherLength)
    {
        OTHER.GetString(i, sz(buffer));
        if (!strcmp(buffer, peerId))
            break;
        
        i += 3;
    }

    if (i < iOtherLength)
    {
        while (i)
        {
            OTHER.SwapAt(i, i - 3);
            OTHER.SwapAt(i + 1, i - 2);
            OTHER.SwapAt(i + 2, i - 1);

            i -= 3;
        }
        OTHER.SetString(0, peerId);
        OTHER.SetString(1, member);
        FormatTime(sz(buffer), NULL_STRING);
        OTHER.SetString(2, buffer);
    }
    else
    {
        OTHER.PushString(peerId);
        OTHER.PushString(member);
        FormatTime(sz(buffer), NULL_STRING);
        OTHER.PushString(buffer);

        int res = i;
        while (i)
        {
            OTHER.SwapAt(i, i - 3);
            OTHER.SwapAt(i + 1, i - 2);
            OTHER.SwapAt(i + 2, i - 1);

            i -= 3;
        }

        if (iOtherMax <= res / 3)
        {
            OTHER.Erase(res);
            OTHER.Erase(res - 1);
            OTHER.Erase(res - 2);
        }
        else
        {
            iOtherLength += 3;
        }
    }
}