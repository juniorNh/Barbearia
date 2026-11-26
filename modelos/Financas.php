<?php
declare(strict_types=1);

// Consultas financeiras: indicadores, séries por período e histórico de movimentos.
// Receitas = soma dos pagamentos. Despesas = soma das despesas. Lucro (saldo) = receitas - despesas.
final class Financas
{
    public const AGRUPAMENTOS = ['dia', 'semana', 'mes'];
    public const MAX_PERIODOS = 400;
    public const POR_PAGINA = 25;

    private static function numero(string $sql, array $params = []): float
    {
        $s = BaseDados::ligar()->prepare($sql);
        $s->execute($params);
        return round((float)$s->fetchColumn(), 2);
    }

    /** Indicadores do dashboard. "Hoje" e "mês" seguem o fuso de Maputo (definido na ligação). */
    public static function resumo(): array
    {
        $semana = 'DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY)';
        $mes = "DATE_FORMAT(CURDATE(), '%Y-%m-01')";
        $receitas = fn(string $desde) => self::numero("SELECT COALESCE(SUM(valor),0) FROM pagamentos WHERE data_pagamento >= $desde");
        $recTotal = self::numero('SELECT COALESCE(SUM(valor),0) FROM pagamentos');
        $despTotal = self::numero('SELECT COALESCE(SUM(valor),0) FROM despesas');
        $recMes = $receitas($mes);
        $despMes = self::numero("SELECT COALESCE(SUM(valor),0) FROM despesas WHERE data_despesa >= $mes");
        $s = BaseDados::ligar()->query(
            "SELECT COUNT(*), COALESCE(SUM(a.preco_cobrado),0) FROM atendimentos a
             LEFT JOIN pagamentos p ON p.atendimento_id = a.id WHERE a.estado = 'concluido' AND p.id IS NULL");
        [$nPorReceber, $porReceber] = $s->fetch(PDO::FETCH_NUM);
        return [
            'receitas_hoje' => $receitas('CURDATE()'), 'receitas_semana' => $receitas($semana), 'receitas_mes' => $recMes,
            'despesas_mes' => $despMes, 'lucro_mes' => round($recMes - $despMes, 2),
            'receitas_total' => $recTotal, 'despesas_total' => $despTotal, 'saldo' => round($recTotal - $despTotal, 2),
            'por_receber' => round((float)$porReceber, 2), 'n_por_receber' => (int)$nPorReceber,
        ];
    }

    /** Intervalo por defeito de cada agrupamento: 30 dias, 12 semanas ou 12 meses até hoje. */
    public static function intervaloPorDefeito(string $agrupar): array
    {
        $hoje = new DateTimeImmutable('today');
        $de = match ($agrupar) {
            'semana' => $hoje->modify('-' . ((int)$hoje->format('N') - 1) . ' days')->modify('-11 weeks'),
            'mes'    => $hoje->modify('first day of this month')->modify('-11 months'),
            default  => $hoje->modify('-29 days'),
        };
        return [$de->format('Y-m-d'), $hoje->format('Y-m-d')];
    }

    /** Chaves de todos os períodos entre as datas (inclui os períodos sem movimentos). null se forem demasiados. */
    private static function periodos(string $agrupar, string $de, string $ate): ?array
    {
        $cursor = new DateTimeImmutable($de);
        $fim = new DateTimeImmutable($ate);
        if ($agrupar === 'semana') $cursor = $cursor->modify('-' . ((int)$cursor->format('N') - 1) . ' days');
        if ($agrupar === 'mes') $cursor = $cursor->modify('first day of this month');
        $passo = ['dia' => '+1 day', 'semana' => '+7 days', 'mes' => '+1 month'][$agrupar];
        $formato = $agrupar === 'mes' ? 'Y-m' : 'Y-m-d';
        $chaves = [];
        while ($cursor <= $fim) {
            $chaves[] = $cursor->format($formato);
            if (count($chaves) > self::MAX_PERIODOS) return null;
            $cursor = $cursor->modify($passo);
        }
        return $chaves;
    }

    /** Receitas, despesas e lucro por dia, semana (começa à segunda) ou mês. Devolve null se o intervalo for grande demais. */
    public static function serie(string $agrupar, string $de, string $ate): ?array
    {
        $chaves = self::periodos($agrupar, $de, $ate);
        if ($chaves === null) return null;
        [$expPag, $expDesp] = match ($agrupar) {
            'semana' => ['DATE_SUB(DATE(data_pagamento), INTERVAL WEEKDAY(data_pagamento) DAY)', 'DATE_SUB(data_despesa, INTERVAL WEEKDAY(data_despesa) DAY)'],
            'mes'    => ["DATE_FORMAT(data_pagamento, '%Y-%m')", "DATE_FORMAT(data_despesa, '%Y-%m')"],
            default  => ['DATE(data_pagamento)', 'data_despesa'],
        };
        $bd = BaseDados::ligar();
        $s = $bd->prepare("SELECT $expPag AS periodo, SUM(valor) AS valor, COUNT(*) AS n FROM pagamentos
                           WHERE data_pagamento >= ? AND data_pagamento < DATE_ADD(?, INTERVAL 1 DAY) GROUP BY periodo");
        $s->execute([$de, $ate]);
        $rec = [];
        foreach ($s->fetchAll() as $r) $rec[$r['periodo']] = $r;
        $s = $bd->prepare("SELECT $expDesp AS periodo, SUM(valor) AS valor FROM despesas WHERE data_despesa BETWEEN ? AND ? GROUP BY periodo");
        $s->execute([$de, $ate]);
        $desp = [];
        foreach ($s->fetchAll() as $r) $desp[$r['periodo']] = (float)$r['valor'];

        $linhas = []; $totR = 0.0; $totD = 0.0; $totN = 0;
        foreach ($chaves as $k) {
            $r = round((float)($rec[$k]['valor'] ?? 0), 2);
            $d = round($desp[$k] ?? 0, 2);
            $n = (int)($rec[$k]['n'] ?? 0);
            $linhas[] = ['periodo' => $k, 'receitas' => $r, 'despesas' => $d, 'lucro' => round($r - $d, 2), 'pagamentos' => $n];
            $totR += $r; $totD += $d; $totN += $n;
        }
        $s = $bd->prepare("SELECT metodo, SUM(valor) AS valor, COUNT(*) AS n FROM pagamentos
                           WHERE data_pagamento >= ? AND data_pagamento < DATE_ADD(?, INTERVAL 1 DAY) GROUP BY metodo ORDER BY valor DESC");
        $s->execute([$de, $ate]);
        $metodos = array_map(fn($m) => ['metodo' => $m['metodo'], 'valor' => round((float)$m['valor'], 2), 'n' => (int)$m['n']], $s->fetchAll());
        return [
            'agrupar' => $agrupar, 'de' => $de, 'ate' => $ate, 'periodos' => $linhas,
            'totais' => ['receitas' => round($totR, 2), 'despesas' => round($totD, 2), 'lucro' => round($totR - $totD, 2), 'pagamentos' => $totN],
            'por_metodo' => $metodos,
        ];
    }

    /** Todos os movimentos (entradas = pagamentos, saídas = despesas), do mais recente para o mais antigo. */
    public static function historico(string $tipo, ?string $de, ?string $ate, int $pagina): array
    {
        $uniao = "SELECT 'entrada' AS tipo, p.data_pagamento AS data, CONCAT(s.nome, ' - ', c.nome_completo) AS descricao, p.valor AS valor, p.metodo AS metodo
                  FROM pagamentos p JOIN atendimentos a ON a.id = p.atendimento_id JOIN servicos s ON s.id = a.servico_id JOIN clientes c ON c.id = a.cliente_id
                  UNION ALL
                  SELECT 'saida', CAST(d.data_despesa AS DATETIME), d.descricao, d.valor, NULL FROM despesas d";
        $onde = []; $params = [];
        if (in_array($tipo, ['entrada', 'saida'], true)) { $onde[] = 'm.tipo = ?'; $params[] = $tipo; }
        if ($de !== null)  { $onde[] = 'm.data >= ?'; $params[] = $de; }
        if ($ate !== null) { $onde[] = 'm.data < DATE_ADD(?, INTERVAL 1 DAY)'; $params[] = $ate; }
        $filtro = $onde ? 'WHERE ' . implode(' AND ', $onde) : '';
        $bd = BaseDados::ligar();
        $s = $bd->prepare("SELECT COUNT(*), COALESCE(SUM(CASE WHEN m.tipo='entrada' THEN m.valor END),0),
                                  COALESCE(SUM(CASE WHEN m.tipo='saida' THEN m.valor END),0) FROM ($uniao) m $filtro");
        $s->execute($params);
        [$total, $entradas, $saidas] = $s->fetch(PDO::FETCH_NUM);
        $limite = self::POR_PAGINA;
        $desloc = (max(1, $pagina) - 1) * $limite;
        $s = $bd->prepare("SELECT m.tipo, m.data, m.descricao, m.valor, m.metodo FROM ($uniao) m $filtro ORDER BY m.data DESC LIMIT $limite OFFSET $desloc");
        $s->execute($params);
        return ['movimentos' => $s->fetchAll(), 'total' => (int)$total,
                'entradas' => round((float)$entradas, 2), 'saidas' => round((float)$saidas, 2)];
    }
}
