# Source Connection
### Связь чата в VK с игровым сервером<br><br>

Позволяет связать чат VK с игровым сервером.<br><br>
Описания настроек находятся в файлах настроек.

<br><br>
## Возможности
1. Информация о сервере;
2. Онлайн сервера;
3. Отправка RCON команд;
4. Отправка сообщений.

<br><br>
## Команды
1. **Команда_вызова_сервера** <подкоманда> - Операции с указанным сервером
* **info** - Информация о сервере
* **rcon** <команда> - Отправка команды
* **steamid** - Список игроков с SteamId и IP
* <сообщение> - Отправка сообщения
* Без параметров - Список игроков
2. **sc** <подкоманда> - Операции со всеми серверами
* **rcon** <команда> - Отправка команды
* <сообщение> - Отправка сообщения
* Без параметров - Список серверов

<br><br>
## Требования для серверной части
1. SourceMod 1.10+;
2. SDKTools;
3. Basic Comm Control;
4. Client Preferences;
5. [ChatModern](https://github.com/deathscore13/ChatModern);
6. REST in Pawn.

<br><br>
## Требования для веб части
1. [BotEngineVK](https://github.com/deathscore13/BotEngineVK);
2. [Rights & Blocks](https://github.com/deathscore13/rights_and_blocks).

<br><br>
## Установка
Файлы для серверной части находятся в директории **Server**, для веб - в **Web**
1. Настроить серверную часть в **`addons/sourcemod/configs/source_connection.ini`** и **`addons/sourcemod/translations/source_connection.txt`**;
2. В **`addons/sourcemod/configs/databases.cfg`** указать соединение к бд **BotEngineVK**:
```keyvalues
    "source_connection"
    {
        "driver"    "mysql"
        "host"      "хост"
        "database"  "имя_бд"
        "user"      "пользователь"
        "pass"      "пароль"
        "port"      "порт"
    }
```
3. Распределить файлы для серверной части по файлам сервера;
4. Настроить веб часть в **`configs/source_sonnection.php`**;
5. Распределить файлы для веб части по директории **BotEngineVK**.
