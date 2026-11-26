<?php
declare(strict_types=1);

// Atendimentos e fila: parte do pessoal (Administrador e Funcionário).
final class ControladorAtendimento
{
    /** Barbeiros disponíveis. Qualquer pessoa com sessão (o cliente escolhe o barbeiro). */
    public static function barbeiros(): never
    {
        Autenticacao::exigir(['administrador', 'funcionario', 'cliente']);
        Resposta::json(['barbeiros' => Atendimento::barbeiros()]);
    }

    public static function listar(): never
    {
        $u = Autenticacao::exigir(Autenticacao::PESSOAL);
        $estado = is_string($_GET['estado'] ?? null) && in_array($_GET['estado'], Atendimento::ESTADOS, true) ? $_GET['estado'] : '';
        $pagina = max(1, (int)($_GET['pagina'] ?? 1));
        $r = Atendimento::historico(self::soDele($u), $estado, $pagina);
        Resposta::json($r + ['pagina' => $pagina, 'por_pagina' => Atendimento::POR_PAGINA]);
    }

    public static function fila(): never
    {
        $u = Autenticacao::exigir(Autenticacao::PESSOAL);
        Resposta::json(['fila' => Atendimento::fila(self::soDele($u))]);
    }

    /** Regista um atendimento (entrada na fila). O Funcionário regista sempre na sua fila; o Administrador escolhe o barbeiro. */
    public static function criar(): never
    {
        $u = Autenticacao::exigir(Autenticacao::PESSOAL);
        $c = Pedido::exigirEscrita();
        $barbeiro = $u['perfil'] === 'funcionario' ? $u['id'] : (int)($c['funcionario_id'] ?? 0);
        $r = Atendimento::entrarNaFila((int)($c['cliente_id'] ?? 0), (int)($c['servico_id'] ?? 0), $barbeiro);
        if (isset($r['erro'])) {
            Resposta::erro($r['erro'] === Atendimento::JA_NA_FILA ? 'Este cliente já está na fila.' : $r['erro'], $r['codigo']);
        }
        Resposta::json(['id' => $r['id']], 201);
    }

    public static function mudarEstado(): never
    {
        $u = Autenticacao::exigir(Autenticacao::PESSOAL);
        $c = Pedido::exigirEscrita();
        $acao = Pedido::texto($c, 'acao');
        if (!Atendimento::acaoValida($acao)) Resposta::erro('Ação inválida.');
        $r = Atendimento::mudarEstado((int)($c['id'] ?? 0), $acao, self::soDele($u));
        if (isset($r['erro'])) Resposta::erro($r['erro'], $r['codigo']);
        Resposta::json(['ok' => true]);
    }

    /** O Funcionário só vê e gere os seus; o Administrador vê tudo. */
    private static function soDele(array $u): ?int
    {
        return $u['perfil'] === 'funcionario' ? $u['id'] : null;
    }
}
