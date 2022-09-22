#define PUBVAR_MAXCLIENTS

#include <sourcemod>
#include <basecomm>

#define DB_PREFIX "botvk_"              /**< Префикс таблиц */
#define DB_CHARSET "utf8mb4"            /**< Кодировка */
#define DB_TABLE DB_PREFIX..."source_connection"

#define FROM_SIZE 128 * 3               /**< Размер первого сообщения (кем и откуда) */
#define MSG_SIZE 512 * 3                /**< Размер сообщения */
#define SEND_SIZE FROM_SIZE + MSG_SIZE  /**< Общий размер сообщения */

/**
 * Размер отправляемых данных о игроках
 */
#define TEAM_MUTE_SIZE 1
#define FRAGS_SIZE 11
#define DEATHS_SIZE 11
#define TIME_SIZE 29
#define IP_SIZE 15
#define STEAMID_SIZE MAX_AUTHID_LENGTH - 1
#define NAME_SIZE MAX_NAME_LENGTH - 1
#define DATA_SIZE (TEAM_MUTE_SIZE + FRAGS_SIZE + DEATHS_SIZE + TIME_SIZE + IP_SIZE + STEAMID_SIZE + NAME_SIZE + \
        7) * 64

#define CHAT_MODERN_NEW_SIZE MSG_SIZE
#include <chatmodern>

/**
 * Разделитель
 */
#define DELIMETER "\x01"
#define DELIMETER_HEX 0x01

#define FAILED "source_connection_failed"   /**< Ошибка обработки команды */
#define SUCCESS "source_connection_success" /**< Успех обработки команды */

#if !defined SPCOMP_MOD
#define sz(%1) %1, sizeof(%1)
#define sz2(%1,%2,%3) %1[%2 * %3], %3
#endif

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
#define toRequestType(%1) view_as<RequestType>(%1)

#define SOUND_MSG 0
#define SOUND_SEND 1
#define SOUND_ERROR 2
#define SOUND_MAX 3
#define SOUND_SIZE PLATFORM_MAX_PATH

char sAccessToken[256], sVersion[6], sServer[128],
    sSounds[SOUND_MAX * SOUND_SIZE];
float fAntiFlood;

public void OnPluginStart()
{
    char error[128];
    hDB = SQL_Connect("source_connection", true, sz(error));
    if (error[0])
        SetFailState(error);
    hDB.SetCharset(DB_CHARSET);

    hPlayersQuery = SQL_PrepareQuery(hDB, "UPDATE "...DB_TABLE..." SET buffer = ? WHERE id = ?", sz(error));
    if (error[0])
        SetFailState(error);
    
    BuildPath(Path_SM, sz(sBuffer), "configs/source_connection.ini");
    KeyValues kv = new KeyValues("source_connection");
    if (!FileExists(sBuffer, false))
    {
        kv.JumpToKey("settings", true);
        kv.SetString("access_token", "ключ");
        kv.SetString("v", "5.131");
        kv.SetString("antiflood", "5.0");
        kv.SetNum("server", 1);
        kv.SetString("sound_msg", "vkchat/message.mp3");
        kv.SetString("sound_send", "vkchat/send.mp3");
        kv.SetString("sound_error", "vkchat/error.mp3");
        kv.Rewind();

        kv.JumpToKey("chats", true);
        {
            kv.JumpToKey("Отправить в беседу", true);
            kv.SetString("peer_id", "2000000001");
            kv.SetString("format", "SayFormat");
            kv.Rewind();

            kv.JumpToKey("Отправить админам", true);
            kv.SetString("peer_id", "2000000002");
            kv.SetString("format", "SayFormatAdmins");
        }
        kv.ExportToFile(sBuffer);

        SetFailState("A new configuration has been generated. Please set up the config file before using");
    }
    
    if (kv.ImportFromFile(sBuffer))
    {
        kv.JumpToKey("settings")
        kv.GetString("access_token", sz(sAccessToken));
        kv.GetString("v", sz(sVersion));
        fAntiFlood = kv.GetFloat("antiflood");
        kv.GetString("server", sz(sServer));
        kv.GetString("sound_msg", sz2(sSounds, SOUND_MSG, SOUND_SIZE));
        kv.GetString("sound_send", sz2(sSounds, SOUND_SEND, SOUND_SIZE));
        kv.GetString("sound_error", sz2(sSounds, SOUND_ERROR, SOUND_SIZE));
        kv.Rewind();
        /*
        kv.JumpToKey("chats");
        {
            hChats = new KeyValues("chats");
            hChats.Import(kv);
            if (kv.GotoFirstSubKey(false))
            {
                char buffer[64], section[64];
                hMenuChats = new Menu(MenuChats_Handler);
                FormatEx(buffer, sizeof(buffer), "%t", "SelectRecipient");
                hMenuChats.SetTitle(buffer);
                do
                {
                    kv.GetSectionName(section, sizeof(section));
                    hMenuChats.AddItem(section, section);
                    iChats++;
                }
                while (kv.GotoNextKey(false));
            }
        }
        */
    }
    else
        SetFailState("Configuration load error");
    kv.Close();

    chatm.Init(GetEngineVersion());
    LoadTranslations("source_connection");
    RegServerCmd("source_connection", SrvCmd_source_connection);

    RegConsoleCmd("sm_vk1", ConCmd_vk);
}

Action SrvCmd_source_connection(int args)
{
    if (args != 2)
    {
        PrintToServer("Invalid response (args != 2)");
        return Plugin_Handled;
    }

    GetCmdArg(1, sz(sBuffer));
    RequestType type = toRequestType(StringToInt(sBuffer));

    GetCmdArg(2, sz(sBuffer));
    int id = StringToInt(sBuffer);
    FormatEx(sz(sBuffer), "SELECT buffer FROM "...DB_TABLE..." WHERE id = %d", id);
    DBResultSet res = SQL_Query(hDB, sBuffer);
    if (!res.FetchRow())
    {
        res.Close();
        PrintToServer(FAILED);
        return Plugin_Handled;
    }

    switch (type)
    {
        case RType_Message:
        {
            res.FetchString(0, sz(sBuffer));

            int from = FindCharInString(sBuffer, DELIMETER_HEX) + 1;
            sBuffer[from - 1] = '\0';

            int msg = FindCharInString(sBuffer[from], DELIMETER_HEX) + from + 1;
            sBuffer[msg - 1] = '\0';
            
            chatm.CPrintToChatAll("%t%t", "Prefix", "Sender", sBuffer, sBuffer[from]);
            chatm.CPrintToChatAll(sBuffer[msg]);

            PrintToServer(SUCCESS);
        }
        case RType_Players:
        {
            int i, pos;
            char ip[16], steamid[MAX_AUTHID_LENGTH], name[MAX_NAME_LENGTH];
            while (++i <= MaxClients)
            {
                if (IsClientInGame(i) && !IsFakeClient(i))
                {
                    GetClientIP(i, sz(ip));
                    GetClientAuthId(i, AuthId_Steam2, sz(steamid));
                    GetClientName(i, sz(name));

                    pos += FormatEx(sBuffer[pos], sizeof(sBuffer) - pos,
                    /* 00 */    "%d"...DELIMETER...
                    /* 01 */    "%d"...DELIMETER...
                    /* 02 */    "%d"...DELIMETER...
                    /* 03 */    "%f"...DELIMETER...
                    /* 04 */    "%s"...DELIMETER...
                    /* 05 */    "%s"...DELIMETER...
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
            sBuffer[strlen(sBuffer) - 1] = '\0';
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

Action ConCmd_vk(int client, int args)
{

}