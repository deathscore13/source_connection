<?php

$m->lib('SourceQuery/bootstrap');
use xPaw\SourceQuery\SourceQuery;

class SourceConnection
{
    public const TABLE = CFG_ENGINE['db']['prefix'].'source_connection';

    /**
     * Регулярное выражение, по которому удаляется конец rcon ответа
     */
    public const REGEX_RCON_END = '\n?L[^\n]+rcon from "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d{4,5}": command ".+';
    
    /**
     * Максимальное количество байт, поддерживаемое игрой
     */
    public const MSG_BYTES = 3;

    /**
     * Размер буфера для отправки сообщения
     */
    public const PEER_ID_SIZE = 12;
    public const MEMBER_SIZE = 32;
    public const MSG_SIZE = 512;
    public const SEND_SIZE = self::MEMBER_SIZE + self::MSG_SIZE;

    /**
     * Размер буфера для получения информации о игроках
     */
    public const TEAM_MUTE_SIZE = 1;
    public const FRAGS_SIZE = 11;
    public const DEATHS_SIZE = 11;
    public const TIME_SIZE = 29;
    public const IP_SIZE = 15;
    public const STEAMID_SIZE = 63;
    public const NAME_SIZE = 127;
    public const DATA_SIZE = (self::TEAM_MUTE_SIZE + self::FRAGS_SIZE + self::DEATHS_SIZE + self::TIME_SIZE + self::IP_SIZE +
        self::STEAMID_SIZE + self::NAME_SIZE + 7) * 64;

    private const DELIMETER = "\x01";
    private const RT_MESSAGE = 0;
    private const RT_PLAYERS = 1;

    /**
     * Ответы от плагина при неудаче или успехе обработки команды
     */
    public const FAILED = 'source_connection_failed';
    public const SUCCESS = 'source_connection_success';

    private PDO $db;
    private array $ids = [];

    /**
     * Конструктор
     * 
     * @param PDO $db               PDO объект для работы с MySQL
     */
    public function __construct(PDO $db)
    {
        $db->exec('CREATE TABLE IF NOT EXISTS '.self::TABLE.' (id INT NOT NULL AUTO_INCREMENT, buffer VARCHAR('.
            (self::SEND_SIZE < self::DATA_SIZE ? self::DATA_SIZE : self::SEND_SIZE).') NOT NULL, PRIMARY KEY (id))');
        $this->db = $db;
    }

    /**
     * Очистка отправленных и полученных данных
     */
    public function __destruct()
    {
        $sql = '';
        if ($this->ids)
        {
            $sql = 'DELETE FROM '.self::TABLE.' WHERE';
            foreach ($this->ids as $id)
                $sql .= ' id = '.$id.' OR';
            $sql = substr($sql, 0, -3).';';
        }
        $this->db->exec($sql.'ALTER TABLE '.self::TABLE.' AUTO_INCREMENT 0');
    }

    /**
     * Отправка команды на сервер
     * 
     * @param array $srv            Массив с ip, port и rcon паролем
     *                              Пример:
     *                                  [
     *                                      'ip' => '1.1.1.1',
     *                                      'port' => '1111',
     *                                      'rcon' => '123456'
     *                                  ]
     * @param string $cmd           Команда
     * @param ?SourceQuery $q       Опционально. SourceQuery объект для использования уже созданного соединения
     * 
     * @return string               Ответ от сервера
     */
    public static function exec(array $srv, string $cmd, ?SourceQuery $q = null): string
    {
        $auth = true;
        if (!$q)
        {
            $auth = false;
            $q = new SourceQuery();
        }

        try
        {
            if (!$auth)
            {
                $q->Connect($srv['ip'], $srv['port'], $srv['timeout'], SourceQuery::SOURCE);
                $q->SetRconPassword($srv['rcon']);
            }
            $res = preg_replace('/'.self::REGEX_RCON_END.'/s', '', $q->Rcon($cmd));
        }
        catch(Exception $e)
        {
            $res = $e->getMessage();
        }
        finally
        {
            if (!$auth)
                $q->Disconnect();
        }
        return $res;
    }

    /**
     * Замена символов больше SourceConnection::MSG_BYTES байт на $replace
     * 
     * @param string &$msg          Буфер для обработки
     * @param string $replace       Строка для замены
     * 
     * @return array                Массив с заменёнными символами
     */
    public static function clearMsg(string &$msg, string $replace): array
    {
        $buffer = [];
        foreach (mb_str_split($msg) as $sym)
            if (self::MSG_BYTES < strlen($sym))
                $buffer[$sym] = $replace;
        
        $msg = strtr($msg, $buffer);
        return array_keys($buffer);
    }

    /**
     * Отправка сообщения на сервер
     * 
     * @param array $srv            Идентично SourceConnection::exec
     * @param string $peerId        Откуда
     * @param string $member        Имя пользователя
     * @param string $msg           Сообщение
     * @param ?SourceQuery $q       Опционально. SourceQuery объект для использования уже созданного соединения
     * 
     * @return string               Ответ от сервера
     *                              При удачном соединении и ответе плагина - SourceConnection::FAILED или SourceConnection::SUCCESS
     */
    public function send(array $srv, int $peerId, string $member, string $msg, ?SourceQuery $q = null): string
    {
        $buffer = $this->db->prepare('INSERT INTO '.self::TABLE.' (buffer) VALUES (?)');
        $buffer->execute([$peerId.self::DELIMETER.$member.self::DELIMETER.$msg]);
        
        $buffer = $this->db->lastInsertId();
        $this->ids[] = $buffer;
        
        return self::exec($srv, 'source_connection '.self::RT_MESSAGE.' '.$buffer, $q);
    }

    /**
     * Получение информации о сервере и игроках
     * 
     * @param array $srv            Идентично SourceConnection::exec
     * @param ?SourceQuery $q       Опционально. SourceQuery объект для использования уже созданного соединения
     * 
     * @return string|array         Строка если возникла ошибка, или массив с данными
     */
    public function info(array $srv, ?SourceQuery $q = null): string|array
    {
        $auth = true;
        if (!$q)
        {
            $auth = false;
            $q = new SourceQuery();
        }

        try
        {
            if (!$auth)
            {
                $q->Connect($srv['ip'], $srv['port'], $srv['timeout'], SourceQuery::SOURCE);
                $q->SetRconPassword($srv['rcon']);
            }
        }
        catch(Exception $e)
        {
            $q->Disconnect();
            return $e->getMessage();
        }

        $info = $q->GetInfo();

        $this->db->exec('INSERT INTO '.self::TABLE.' (buffer) VALUES ("")');
        
        $buffer = $this->db->lastInsertId();
        $this->ids[] = $buffer;
        
        $res = self::exec($srv, 'source_connection '.self::RT_PLAYERS.' '.$buffer, $q);
        if (!$auth)
            $q->Disconnect();
        
        if ($res === self::SUCCESS)
        {
            if ($buffer = $this->db->query('SELECT buffer FROM '.self::TABLE.' WHERE id = '.$buffer)->fetch(PDO::FETCH_ASSOC)['buffer'])
            {
                $info['PlayersList'] = [];
                $buffer = explode(PHP_EOL, $buffer);
                $i = -1;
                while (isset($buffer[++$i]))
                {
                    $player = explode(self::DELIMETER, $buffer[$i]);

                    $info['PlayersList'][$i]['team'] = (int)$player[0] >> 1;
                    $info['PlayersList'][$i]['muted'] = (int)$player[0] & 1;
                    $info['PlayersList'][$i]['frags'] = $player[1];
                    $info['PlayersList'][$i]['deaths'] = $player[2];
                    $info['PlayersList'][$i]['time'] = $player[3];
                    $info['PlayersList'][$i]['ip'] = $player[4];
                    $info['PlayersList'][$i]['steamid'] = $player[5];
                    $info['PlayersList'][$i]['name'] = $player[6];
                }
            }
            else
                $info['PlayersList'] = LANG_SOURCE_CONNECTION[21];

            return $info;
        }
        return $info + ['PlayersList' => sprintf(LANG_SOURCE_CONNECTION[6], $res)];
    }
}