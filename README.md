# Source Connection
### Связь чата в VK с игровым сервером

Позволяет связать чат VK с игровым сервером.

<br><br>
## Возможности
1. Информация о сервере;
2. Онлайн сервера;
3. Отправка RCON команд;
4. Отправка сообщений.

<br><br>
## Команды
1. **Команда_вызова_сервера** <подкоманда> - Операции с указанным сервером
* **info**, **инфо** - Информация о сервере
* **rcon**, **ркон** <команда> - Отправка команды
* **steamid**, **стимид** - Список игроков с SteamId и IP
* <сообщение> - Отправка сообщения
* Без параметров - Список игроков
2. **sc** <подкоманда> - Операции со всеми серверами
* **rcon**, **ркон** <команда> - Отправка команды
* <сообщение> - Отправка сообщения
* Без параметров - Список серверов

<br><br>
## Требования для работы серверной части
1. SourceMod 1.10+;
2. Basic Comm Control;
3. Client Preferences;
4. ChatModern;
5. REST in Pawn.

<br><br>
## Требования для работы серверной части
1. BotEngineVK;
2. Rights & Blocks.

<br><br>
## Установка
Файлы для серверной части находятся в директории **Server**, для веб - в **Web**
1. Настроить серверную часть в **addons/sourcemod/configs/source_connection.ini** и **addons/sourcemod/translations/source_connection.txt**;
2. Распределить файлы для серверной части по файлам сервера;
3. Настроить веб часть в **configs/source_sonnection.php**;
4. Распределить файлы для веб части по директории **BotEngineVK**.
