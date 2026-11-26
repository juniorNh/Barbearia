<?php
declare(strict_types=1);

// Despesas e consultas financeiras: só o Administrador.
final class ControladorFinanca
{
    public static function despesasListar(): never
    {
        Autenticacao::exigir(['administrador']);
        [$de, $ate] = self::periodoOpcional();
        $pagina = max(1, (int)($_GET['pagina'] ?? 1));
        Resposta::json(Despesa::listar($de, $ate, $pagina) + ['pagina' => $pagina, 'por_pagina' => Despesa::POR_PAGINA]);
    }

    public static function despesasCriar(): never
    {
        $u = Autenticacao::exigir(['administrador']);
        $c = Pedido::exigirEscrita();
        $descricao = Pedido::texto($c, 'descricao');
        $valor = Pedido::texto($c, 'valor');
        $data = Pedido::texto($c, 'data_despesa');
        $erro = Validacao::primeiroErro(Validacao::descricaoDespesa($descricao), Validacao::valor($valor), Validacao::data($data));
        if ($erro !== null) Resposta::erro($erro);
        if ($data > (new DateTimeImmutable('today'))->format('Y-m-d')) Resposta::erro('A data da despesa não pode ser no futuro.');
        Resposta::json(['id' => Despesa::criar($descricao, $valor, $data, $u['id'])], 201);
    }

    public static function resumo(): never
    {
        Autenticacao::exigir(['administrador']);
        Resposta::json(Financas::resumo());
    }

    public static function serie(): never
    {
        Autenticacao::exigir(['administrador']);
        $agrupar = self::texto('agrupar') ?: 'dia';
        if (!in_array($agrupar, Financas::AGRUPAMENTOS, true)) Resposta::erro('Agrupamento inválido (dia, semana ou mes).');
        [$de, $ate] = self::periodoOpcional();
        if ($de === null || $ate === null) {
            [$deDefeito, $ateDefeito] = Financas::intervaloPorDefeito($agrupar);
            $de ??= $deDefeito;
            $ate ??= $ateDefeito;
        }
        if ($de > $ate) Resposta::erro('A data inicial não pode ser depois da data final.');
        $r = Financas::serie($agrupar, $de, $ate);
        if ($r === null) Resposta::erro('Intervalo demasiado grande para este agrupamento. Escolha um período mais curto.');
        Resposta::json($r);
    }

    public static function historico(): never
    {
        Autenticacao::exigir(['administrador']);
        [$de, $ate] = self::periodoOpcional();
        if ($de !== null && $ate !== null && $de > $ate) Resposta::erro('A data inicial não pode ser depois da data final.');
        $pagina = max(1, (int)($_GET['pagina'] ?? 1));
        Resposta::json(Financas::historico(self::texto('tipo'), $de, $ate, $pagina) + ['pagina' => $pagina, 'por_pagina' => Financas::POR_PAGINA]);
    }

    private static function texto(string $chave): string
    {
        return is_string($_GET[$chave] ?? null) ? trim($_GET[$chave]) : '';
    }

    /** Datas "de" e "ate" opcionais, já validadas. */
    private static function periodoOpcional(): array
    {
        $datas = [];
        foreach (['de', 'ate'] as $chave) {
            $v = self::texto($chave);
            if ($v !== '' && Validacao::data($v) !== null) Resposta::erro('Indique datas válidas (AAAA-MM-DD).');
            $datas[] = $v !== '' ? $v : null;
        }
        return $datas;
    }
}
