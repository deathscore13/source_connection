<?php

const SOURCE_CONNECTION_V_MAJOR = 1;
const SOURCE_CONNECTION_V_MINOR = 0;
const SOURCE_CONNECTION_V_RELEASE = 0;
const SOURCE_CONNECTION_VERSION = SOURCE_CONNECTION_V_MAJOR.'.'.SOURCE_CONNECTION_V_MINOR.'.'.SOURCE_CONNECTION_V_RELEASE;

$m->lang('source_connection');

const SOURCE_CONNECTION_INFO = [
    'name' => 'Source Connection',
    'description' => LANG_SOURCE_CONNECTION[33],
    'version' => SOURCE_CONNECTION_VERSION,
    'author' => 'DeathScore13',
    'url' => 'https://github.com/deathscore13/source_connection'
];

if ($m->moduleExists('rights_and_blocks'))
{
    require_once($m->pathPreload('rights_and_blocks'));

    if (!$rights->regRight('sc_rcon', LANG_SOURCE_CONNECTION[23]))
        $m->error(LANG_RIGHTS_AND_BLOCKS[11], 'sc_rcon');
    
    if (!$rights->regRight('sc_steamid', LANG_SOURCE_CONNECTION[27]))
        $m->error(LANG_RIGHTS_AND_BLOCKS[11], 'sc_steamid');
    
    if (!$blocks->regBlock('sc_messages', LANG_SOURCE_CONNECTION[38]))
        $m->error(LANG_RIGHTS_AND_BLOCKS[36], 'sc_messages');
    
    if (!$blocks->regBlock('sc_online', LANG_SOURCE_CONNECTION[26]))
        $m->error(LANG_RIGHTS_AND_BLOCKS[36], 'sc_online');
}
else
{
    $m->error(LANG_ENGINE[16], 'rights_and_blocks');
}

if ($cfg_source_connection = Config::parseByPeerId($vk->obj['peer_id'], Config::load('source_connection')))
{
    $m->regCmd(['sc', LANG_SOURCE_CONNECTION[34]], LANG_SOURCE_CONNECTION[35], [
        [
            'names' => [
                'rcon',
                LANG_SOURCE_CONNECTION[30]
            ],
            'params' => LANG_SOURCE_CONNECTION[22],
            'description' => LANG_SOURCE_CONNECTION[23]
        ],
        [
            'names' => [
                LANG_SOURCE_CONNECTION[24]
            ],
            'description' => LANG_SOURCE_CONNECTION[25]
        ],
        [
            'names' => [
                LANG_ENGINE[29]
            ],
            'description' => LANG_SOURCE_CONNECTION[29]
        ]
    ]);

    foreach ($cfg_source_connection as $cmd => $info)
        if ($cmd !== 'settings')
            $m->regCmd(explode(',', $cmd), $info['description'] ?? '', [
                [
                    'names' => [
                        'info',
                        LANG_SOURCE_CONNECTION[31]
                    ],
                    'description' => LANG_SOURCE_CONNECTION[28]
                ],
                [
                    'names' => [
                        'rcon',
                        LANG_SOURCE_CONNECTION[30]
                    ],
                    'params' => LANG_SOURCE_CONNECTION[22],
                    'description' => LANG_SOURCE_CONNECTION[23]
                ],
                [
                    'names' => [
                        'steamid',
                        LANG_SOURCE_CONNECTION[32]
                    ],
                    'description' => LANG_SOURCE_CONNECTION[27]
                ],
                [
                    'names' => [
                        LANG_SOURCE_CONNECTION[24]
                    ],
                    'description' => LANG_SOURCE_CONNECTION[25]
                ],
                [
                    'names' => [
                        LANG_ENGINE[29]
                    ],
                    'description' => LANG_SOURCE_CONNECTION[29]
                ]
            ]);
}

require('sourceconnection.php');