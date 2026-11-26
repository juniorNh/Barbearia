<?php
declare(strict_types=1);

// Pagamentos: o pessoal regista o dinheiro recebido. O Funcionário só mexe nos seus atendimentos.
final class ControladorPagamento
{
    public static function porReceber(): never
    {
        $u = Autenticacao::exigir(Autenticacao::PESSOAL);
        Resposta::json(['atendimentos' => Pagamento::porReceber(self::soDele($u))]);
    }

    public static function listar(): never
    {
        $u = Autenticacao::exigir(Autenticacao::PESSOAL);
        $pagina = max(1, (int)($_GET['pagina'] ?? 1));
        Resposta::json(Pagamento::listar(self::soDele($u), $pagina) + ['pagina' => $pagina, 'por_pagina' => Pagamento::POR_PAGINA]);
    }

    public static function registar(): never
    {
        $u = Autenticacao::exigir(Autenticacao::PESSOAL);
        $c = Pedido::exigirEscrita();
        // O valor nunca vem do pedido: é o preço do atendimento.
        $r = Pagamento::registar((int)($c['atendimento_id'] ?? 0), Pedido::texto($c, 'metodo'), $u['id'], self::soDele($u));
        if (isset($r['erro'])) Resposta::erro($r['erro'], $r['codigo']);
        Resposta::json(['id' => $r['id']], 201);
    }

    private static function soDele(array $u): ?int
    {
        return $u['perfil'] === 'funcionario' ? $u['id'] : null;
    }
}
