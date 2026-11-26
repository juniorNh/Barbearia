<?php
declare(strict_types=1);

// Arranque da API.

// Classes do núcleo.
foreach ([
    'Configuracao',
    'Sessao',
    'Seguranca',
    'Validacao',
    'Resposta',
    'Pedido',
    'Autenticacao'
] as $f) {
    require __DIR__ . "/$f.php";
}

require __DIR__ . '/../config/base_dados.php';

// Modelos.
foreach ([
    'Utilizador',
    'Cliente',
    'Perfil',
    'Servico',
    'Atendimento',
    'Agendamento',
    'Pagamento',
    'Despesa',
    'Financas',
    'TentativaAcesso'
] as $f) {
    require __DIR__ . "/../modelos/$f.php";
}

// Controladores.
foreach ([
    'ControladorSessao',
    'ControladorPerfil',
    'ControladorConta',
    'ControladorAdmin',
    'ControladorServico',
    'ControladorCliente',
    'ControladorAtendimento',
    'ControladorFila',
    'ControladorAgendamento',
    'ControladorPagamento',
    'ControladorFinanca'
] as $f) {
    require __DIR__ . "/../controladores/$f.php";
}

ini_set('display_errors', '0');
error_reporting(E_ALL);

date_default_timezone_set('Africa/Maputo');

header('X-Content-Type-Options: nosniff');

Sessao::iniciar();
