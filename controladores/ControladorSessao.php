<?php
declare(strict_types=1);

// Sessão: estado atual, entrada e saída (usado pelas duas áreas).
final class ControladorSessao
{
    public static function sessao(): never
    {
        Resposta::json(['utilizador' => Sessao::utilizador(), 'csrf' => Seguranca::tokenCsrf()]);
    }

    public static function entrar(): never
    {
        $c = Pedido::exigirEscrita();
        $perfis = Pedido::texto($c, 'area') === 'admin' ? Autenticacao::PESSOAL : Autenticacao::CLIENTE;
        if (TentativaAcesso::excedeu('entrada')) {
            Resposta::erro('Demasiadas tentativas. Aguarde alguns minutos e tente novamente.', 429);
        }
        if (!Autenticacao::entrar(Pedido::texto($c, 'email'), (string)($c['senha'] ?? ''), $perfis)) {
            Resposta::erro('Email ou senha incorretos.', 401);
        }
        Resposta::json(['utilizador' => Sessao::utilizador(), 'csrf' => Seguranca::tokenCsrf()]);
    }

    public static function sair(): never
    {
        Pedido::exigirEscrita();
        Autenticacao::sair();
        Sessao::iniciar();
        Resposta::json(['csrf' => Seguranca::tokenCsrf()]);
    }
}
