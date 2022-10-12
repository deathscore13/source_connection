<?php

use xPaw\SourceQuery\SourceQuery;

if ($m->cmd('sc') && $CFG_SOURCE_CONNECTION)
{
    $send = '';
    if ($m->param(1, ['rcon', LANG_SOURCE_CONNECTION[30]]))
    {
        if (!$m->moduleExists('rights_and_blocks'))
            $m->error(LANG_ENGINE[16], 'rights_and_blocks');
        
        if (!$rights->isRight($vk->obj['from_id'], 'sc_rcon'))
            $m->error(LANG_RIGHTS_AND_BLOCKS[10], 'sc_rcon');
        
        if (!($buffer = substr($m->getParamString(0), strlen($m->param(0)) + strlen($m->param(1)) + 2)))
            $m->error(LANG_ENGINE[11], 2);

        foreach($CFG_SOURCE_CONNECTION as $key => $res)
        {
            if ($key === 'settings')
                continue;

            $send .= $res['description'].PHP_EOL.(($res = SourceConnection::exec($res, $buffer)) ? $res :
                LANG_SOURCE_CONNECTION[1]).PHP_EOL.PHP_EOL;
        }
        
        $vk->replyPM($send, $CFG_SOURCE_CONNECTION['settings']['response']);
    }
    else if ($m->param(1))
    {
        if ($blocks->isBlock($vk->obj['from_id'], 'sc_messages'))
        {
            $m->error(LANG_RIGHTS_AND_BLOCKS[37], 'sc_messages');
        }
        else
        {
            $msg = substr($m->getParamString(0), strlen($m->param(0)) + 1);
            
            if ($buffer = SourceConnection::clearMsg($msg, $CFG_SOURCE_CONNECTION['settings']['replace']))
                $send .= sprintf(LANG_SOURCE_CONNECTION[3], implode(', ', $buffer), $CFG_SOURCE_CONNECTION['settings']['replace']).
                    PHP_EOL.PHP_EOL;
            
            if (!($len = mb_strlen($msg)) || SourceConnection::MSG_SIZE <= $len)
            {
                $send .= sprintf(LANG_SOURCE_CONNECTION[2], SourceConnection::MSG_SIZE);
            }
            else
            {
                $sc = new SourceConnection($db);
                $member = $vk->getMembers()['profiles'][$vk->obj['from_id']];
                foreach ($CFG_SOURCE_CONNECTION as $key => $res)
                {
                    if ($key === 'settings')
                        continue;
                    
                    $send .= $res['description'].PHP_EOL;
                    switch ($res = $sc->send($res, $vk->obj['peer_id'], $member['first_name'].' '.$member['last_name'], $msg))
                    {
                        case SourceConnection::SUCCESS:
                        {
                            $send .= LANG_SOURCE_CONNECTION[4].PHP_EOL.PHP_EOL;
                            break;
                        }
                        case SourceConnection::FAILED:
                        case '':
                        {
                            $send .= LANG_SOURCE_CONNECTION[5].PHP_EOL.PHP_EOL;
                            break;
                        }
                        default:
                        {
                            $send .= $res.PHP_EOL.PHP_EOL;
                        }
                    }
                }
            }
            $vk->replyPM($send, $CFG_SOURCE_CONNECTION['settings']['response']);
        }
    }
    else if ($blocks->isBlock($vk->obj['from_id'], 'sc_online'))
    {
        $m->error(LANG_RIGHTS_AND_BLOCKS[37], 'sc_online');
    }
    else
    {
        $players = $maxPlayers = $bots = 0;
        $q = new SourceQuery();
        foreach ($CFG_SOURCE_CONNECTION as $key => $res)
        {
            if ($key === 'settings')
                continue;

            try
            {
                $q->Connect($res['ip'], $res['port'], $res['timeout'], SourceQuery::SOURCE);
                $buffer = $q->GetInfo();
            }
            catch(Exception $e)
            {
                $buffer = $e->getMessage();
            }
            finally
            {
                $q->Disconnect();
            }

            if (is_array($buffer))
            {
                $send .= sprintf(LANG_SOURCE_CONNECTION[37],
                /* 01 */    $buffer['HostName'],
                /* 02 */    $res['ip'],
                /* 03 */    $res['port'],
                /* 04 */    $buffer['Players'] - $buffer['Bots'],
                /* 05 */    $buffer['MaxPlayers'],
                /* 06 */    $buffer['Bots'],
                /* 07 */    $buffer['Map'],
                /* 08 */    strtr($key, [',' => ', '])
                ).PHP_EOL.PHP_EOL;
                $players += $buffer['Players'] - $buffer['Bots'];
                $maxPlayers += $buffer['MaxPlayers'];
                $bots += $buffer['Bots'];
            }
            else
            {
                $send .= $buffer.PHP_EOL.PHP_EOL;
            }
        }
        $vk->replyPM($send.sprintf(LANG_SOURCE_CONNECTION[36], $players, $maxPlayers, $bots), $CFG_SOURCE_CONNECTION['settings']['response']);
    }

    exit();
}
else if ($CFG_SOURCE_CONNECTION &&
    ($res = $m->param(0)) &&
    $res = Utils::findKey($res, $CFG_SOURCE_CONNECTION))
{
    if ($m->param(1, ['rcon', LANG_SOURCE_CONNECTION[30]]))
    {
        if (!$m->moduleExists('rights_and_blocks'))
            $m->error(LANG_ENGINE[16], 'rights_and_blocks');
        
        if (!$rights->isRight($vk->obj['from_id'], 'sc_rcon'))
            $m->error(LANG_RIGHTS_AND_BLOCKS[10], 'sc_rcon');
        
        if (!($buffer = substr($m->getParamString(0), strlen($m->param(0)) + strlen($m->param(1)) + 2)))
            $m->error(LANG_ENGINE[11], 2);
        
        $vk->replyPM(LANG_SOURCE_CONNECTION[0].PHP_EOL.PHP_EOL.(($res = SourceConnection::exec($res, $buffer)) ? $res :
            LANG_SOURCE_CONNECTION[1]), $CFG_SOURCE_CONNECTION['settings']['response']);
    }
    else if (($buffer = $m->param(1)) &&
        $buffer !== 'info' && $buffer !== LANG_SOURCE_CONNECTION[31] &&
        (!$CFG_SOURCE_CONNECTION['settings']['steamid'] || $buffer !== 'steamid' && $buffer !== LANG_SOURCE_CONNECTION[32]))
    {
        if ($blocks->isBlock($vk->obj['from_id'], 'sc_messages'))
        {
            $m->error(LANG_RIGHTS_AND_BLOCKS[37], 'sc_messages');
        }
        else
        {
            $msg = substr($m->getParamString(0), strlen($m->param(0)) + 1);
            $send = '';
            
            if ($buffer = SourceConnection::clearMsg($msg, $CFG_SOURCE_CONNECTION['settings']['replace']))
                $send .= sprintf(LANG_SOURCE_CONNECTION[3], implode(', ', $buffer), $CFG_SOURCE_CONNECTION['settings']['replace']).
                    PHP_EOL.PHP_EOL;
            
            if (!($len = mb_strlen($msg)) || SourceConnection::MSG_SIZE <= $len)
            {
                $send .= sprintf(LANG_SOURCE_CONNECTION[2], SourceConnection::MSG_SIZE);
            }
            else
            {
                $sc = new SourceConnection($db);
                $member = $vk->getMembers()['profiles'][$vk->obj['from_id']];
                switch ($res = $sc->send($res, $vk->obj['peer_id'], $member['first_name'].' '.$member['last_name'], $msg))
                {
                    case SourceConnection::SUCCESS:
                    {
                        $send .= LANG_SOURCE_CONNECTION[4];
                        break;
                    }
                    case SourceConnection::FAILED:
                    case '':
                    {
                        $send .= LANG_SOURCE_CONNECTION[5];
                        break;
                    }
                    default:
                    {
                        $send .= $res;
                    }
                }
            }
            $vk->replyPM($send, $CFG_SOURCE_CONNECTION['settings']['response']);
        }
    }
    else if ($blocks->isBlock($vk->obj['from_id'], 'sc_online'))
    {
        $m->error(LANG_RIGHTS_AND_BLOCKS[37], 'sc_online');
    }
    else
    {
        $subcmd = $buffer;
        if (($subcmd === 'steamid' || $subcmd === LANG_SOURCE_CONNECTION[32]) && $CFG_SOURCE_CONNECTION['settings']['steamid'] &&
            !$rights->isRight($vk->obj['from_id'], 'sc_steamid'))
        {
            $m->error(LANG_RIGHTS_AND_BLOCKS[10], 'sc_steamid');
        }

        if ($subcmd === 'info' || $subcmd === LANG_SOURCE_CONNECTION[31])
        {
            $q = new SourceQuery();
            try
            {
                $q->Connect($res['ip'], $res['port'], $res['timeout'], SourceQuery::SOURCE);
                $buffer = $q->GetInfo();
            }
            catch(Exception $e)
            {
                $buffer = $e->getMessage();
            }
            finally
            {
                $q->Disconnect();
            }
    
            if (is_array($buffer))
            {
                $send = sprintf(LANG_SOURCE_CONNECTION[20],
                /* 01 */    $buffer['HostName'],
                /* 02 */    $res['ip'],
                /* 03 */    $res['port'],
                /* 04 */    $buffer['Players'] - $buffer['Bots'],
                /* 05 */    $buffer['MaxPlayers'],
                /* 06 */    $buffer['Bots'],
                /* 07 */    $buffer['Map']
                ).PHP_EOL.PHP_EOL;
            }
            else
            {
                $send = $buffer.PHP_EOL.PHP_EOL;
            }
        }
        else
        {
            $sc = new SourceConnection($db);
            if (is_array($buffer = $sc->info($res)))
            {
                $send = sprintf(LANG_SOURCE_CONNECTION[20],
                /* 01 */    $buffer['HostName'],
                /* 02 */    $res['ip'],
                /* 03 */    $res['port'],
                /* 04 */    isset($buffer['PlayersList']) && is_array($buffer['PlayersList']) ? count($buffer['PlayersList']) :
                            $buffer['Players'] - $buffer['Bots'],
                /* 05 */    $buffer['MaxPlayers'],
                /* 06 */    $buffer['Bots'],
                /* 07 */    $buffer['Map']
                );
            
                if (is_array($buffer['PlayersList']))
                {
                    Utils::$sortKey = 'deaths';
                    usort($buffer['PlayersList'], 'Utils::usort_asc_callback');
                
                    Utils::$sortKey = 'frags';
                    usort($buffer['PlayersList'], 'Utils::usort_desc_callback');

                    Utils::$sortKey = 'team';
                    usort($buffer['PlayersList'], 'Utils::usort_asc_callback');

                    $send .= PHP_EOL.PHP_EOL.($subcmd ? LANG_SOURCE_CONNECTION[18] : LANG_SOURCE_CONNECTION[17]);
                    foreach ($buffer['PlayersList'] as $player)
                    {
                        $d = floor($player['time'] / 86400);
                        $h = floor(($player['time'] - ($d * 86400)) / 3600);
                        $m = floor(($player['time'] - ($d * 86400) - ($h * 3600)) / 60);
                        $s = floor(($player['time'] - ($d * 86400) - ($h * 3600) - ($m * 60)));

                        $send .= PHP_EOL.sprintf(($subcmd ? LANG_SOURCE_CONNECTION[19] : LANG_SOURCE_CONNECTION[11]), 
                        /* 01 */    LANG_SOURCE_CONNECTION[7 + $player['team']],
                        /* 02 */    $player['frags'],
                        /* 03 */    $player['deaths'],
                        /* 04 */    ($d ? $d.LANG_SOURCE_CONNECTION[12].' ' : '').($h ? $h.LANG_SOURCE_CONNECTION[13].' ' : '').
                                        ($m ? $m.LANG_SOURCE_CONNECTION[14].' ' : '').$s.LANG_SOURCE_CONNECTION[15],
                        /* 05 */    $player['muted'] ? LANG_SOURCE_CONNECTION[16] : '',
                        /* 06 */    $player['ip'],
                        /* 07 */    $player['steamid'],
                        /* 08 */    $player['name']
                        );
                    }
                }
                else
                {
                    $send .= PHP_EOL.PHP_EOL.$buffer['PlayersList'];
                }
            }
            else
            {
                $send = $buffer;
            }
        }
        
        $vk->replyPM($send, $CFG_SOURCE_CONNECTION['settings']['players'], [
            'dont_parse_links' => true,
            'disable_mentions' => true
        ]);
    }

    exit();
}