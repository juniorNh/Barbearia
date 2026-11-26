<?php
declare(strict_types=1);

return [
    'bd' => [
        'servidor'   => getenv('BARBEARIA_BD_SERVIDOR') ?: '127.0.0.1',
        'nome'       => getenv('BARBEARIA_BD_NOME') ?: 'barbearia',
        'utilizador' => getenv('BARBEARIA_BD_USER') ?: 'root',
        'senha'      => getenv('BARBEARIA_BD_SENHA') ?: 'root',
        'porta'      => getenv('BARBEARIA_BD_PORT') ?: '3306',
        'ssl'        => getenv('BD_SSL') ?: 'false',      

    ],

    'nome_barbearia' => 'Djuzzy Barber',
    'mostrar_erros'  => true,
    'max_tentativas' => 5,
    'janela_minutos' => 15,
    'senha_min'      => 8,
    'sessao_horas'   => 8,
];