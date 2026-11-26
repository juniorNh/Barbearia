<?php
declare(strict_types=1);

// Despesas (gastos) da barbearia.
final class Despesa
{
    public const POR_PAGINA = 20;

    public static function criar(string $descricao, string $valor, string $data, int $registadoPor): int
    {
        $bd = BaseDados::ligar();
        $bd->prepare('INSERT INTO despesas (descricao, valor, data_despesa, registado_por) VALUES (?, ?, ?, ?)')
           ->execute([trim($descricao), Validacao::normalizarPreco($valor), $data, $registadoPor]);
        return (int)$bd->lastInsertId();
    }

    /** Lista paginada, com filtro opcional por período (datas AAAA-MM-DD, inclusivas). */
    public static function listar(?string $de, ?string $ate, int $pagina): array
    {
        $onde = []; $params = [];
        if ($de !== null)  { $onde[] = 'd.data_despesa >= ?'; $params[] = $de; }
        if ($ate !== null) { $onde[] = 'd.data_despesa <= ?'; $params[] = $ate; }
        $filtro = $onde ? 'WHERE ' . implode(' AND ', $onde) : '';
        $bd = BaseDados::ligar();
        $s = $bd->prepare("SELECT COUNT(*), COALESCE(SUM(d.valor), 0) FROM despesas d $filtro");
        $s->execute($params);
        [$total, $soma] = $s->fetch(PDO::FETCH_NUM);
        $limite = self::POR_PAGINA;
        $desloc = (max(1, $pagina) - 1) * $limite;
        $s = $bd->prepare(
            "SELECT d.id, d.data_despesa, d.descricao, d.valor, u.nome AS registado_por
             FROM despesas d JOIN utilizadores u ON u.id = d.registado_por $filtro
             ORDER BY d.data_despesa DESC, d.id DESC LIMIT $limite OFFSET $desloc");
        $s->execute($params);
        return ['despesas' => $s->fetchAll(), 'total' => (int)$total, 'soma' => round((float)$soma, 2)];
    }
}
