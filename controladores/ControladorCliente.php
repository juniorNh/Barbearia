<?php
declare(strict_types=1);

// Gestão de clientes pelo pessoal (Administrador e Funcionário).
final class ControladorCliente
{
    public static function listar(): never
    {
        Autenticacao::exigir(Autenticacao::PESSOAL);
        $termo = is_string($_GET['q'] ?? null) ? mb_substr(trim($_GET['q']), 0, 60) : '';
        $pagina = max(1, (int)($_GET['pagina'] ?? 1));
        $r = Cliente::pesquisar($termo, $pagina);
        Resposta::json($r + ['pagina' => $pagina, 'por_pagina' => Cliente::POR_PAGINA]);
    }

    public static function criar(): never
    {
        Autenticacao::exigir(Autenticacao::PESSOAL);
        [$nome, $contacto] = self::dadosValidados(Pedido::exigirEscrita());
        Resposta::json(['id' => Cliente::criar($nome, $contacto)], 201);
    }

    public static function editar(): never
    {
        Autenticacao::exigir(Autenticacao::PESSOAL);
        $c = Pedido::exigirEscrita();
        $id = (int)($c['id'] ?? 0);
        if (!Cliente::porId($id)) Resposta::erro('Cliente não encontrado.', 404);
        [$nome, $contacto] = self::dadosValidados($c);
        Cliente::atualizar($id, $nome, $contacto);
        Resposta::json(['ok' => true]);
    }

    private static function dadosValidados(array $c): array
    {
        $nome = Pedido::texto($c, 'nome');
        $contacto = Pedido::texto($c, 'contacto');
        $erro = Validacao::primeiroErro(Validacao::nome($nome), Validacao::contacto($contacto));
        if ($erro !== null) Resposta::erro($erro);
        return [$nome, $contacto];
    }
}
