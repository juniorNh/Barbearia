<?php
declare(strict_types=1);

// Pagamentos: o dinheiro recebido por cada atendimento concluído.
// O valor vem sempre do atendimento (preço do serviço); nunca é escrito à mão.
final class Pagamento
{
    public const POR_PAGINA = 20;
    public const METODOS = ['numerario', 'mpesa', 'emola', 'mkesh', 'cartao', 'transferencia'];

    /** Atendimentos concluídos que ainda não foram pagos. $funcionarioId limita a um barbeiro. */
    public static function porReceber(?int $funcionarioId): array
    {
        $onde = "a.estado = 'concluido' AND p.id IS NULL";
        $params = [];
        if ($funcionarioId !== null) { $onde .= ' AND a.funcionario_id = ?'; $params[] = $funcionarioId; }
        $s = BaseDados::ligar()->prepare(
            "SELECT a.id, a.concluido_em, a.preco_cobrado AS valor, c.nome_completo AS cliente,
                    s.nome AS servico, u.nome AS funcionario
             FROM atendimentos a
             LEFT JOIN pagamentos p ON p.atendimento_id = a.id
             JOIN clientes c ON c.id = a.cliente_id JOIN servicos s ON s.id = a.servico_id
             JOIN utilizadores u ON u.id = a.funcionario_id
             WHERE $onde ORDER BY a.concluido_em, a.id");
        $s->execute($params);
        return $s->fetchAll();
    }

    public static function listar(?int $funcionarioId, int $pagina): array
    {
        $onde = ''; $params = [];
        if ($funcionarioId !== null) { $onde = 'WHERE a.funcionario_id = ?'; $params[] = $funcionarioId; }
        $bd = BaseDados::ligar();
        $s = $bd->prepare("SELECT COUNT(*), COALESCE(SUM(p.valor), 0) FROM pagamentos p JOIN atendimentos a ON a.id = p.atendimento_id $onde");
        $s->execute($params);
        [$total, $soma] = $s->fetch(PDO::FETCH_NUM);
        $limite = self::POR_PAGINA;
        $desloc = (max(1, $pagina) - 1) * $limite;
        $s = $bd->prepare(
            "SELECT p.id, p.data_pagamento, p.valor, p.metodo, c.nome_completo AS cliente, s.nome AS servico, u.nome AS funcionario
             FROM pagamentos p JOIN atendimentos a ON a.id = p.atendimento_id
             JOIN clientes c ON c.id = a.cliente_id JOIN servicos s ON s.id = a.servico_id
             JOIN utilizadores u ON u.id = a.funcionario_id $onde
             ORDER BY p.data_pagamento DESC, p.id DESC LIMIT $limite OFFSET $desloc");
        $s->execute($params);
        return ['pagamentos' => $s->fetchAll(), 'total' => (int)$total, 'soma' => round((float)$soma, 2)];
    }

    /**
     * Regista o pagamento de um atendimento concluído. Devolve ['id' => int] ou ['erro' => ..., 'codigo' => http].
     * $soFuncionario limita ao barbeiro dono do atendimento.
     */
    public static function registar(int $atendimentoId, string $metodo, int $registadoPor, ?int $soFuncionario): array
    {
        if (!in_array($metodo, self::METODOS, true)) return ['erro' => 'Escolha o método de pagamento.', 'codigo' => 400];
        $bd = BaseDados::ligar();
        $bd->beginTransaction();
        try {
            $s = $bd->prepare('SELECT id, estado, funcionario_id, preco_cobrado FROM atendimentos WHERE id = ? FOR UPDATE');
            $s->execute([$atendimentoId]);
            $a = $s->fetch();
            if (!$a) { $bd->rollBack(); return ['erro' => 'Atendimento não encontrado.', 'codigo' => 404]; }
            if ($soFuncionario !== null && (int)$a['funcionario_id'] !== $soFuncionario) {
                $bd->rollBack(); return ['erro' => 'Só pode registar pagamentos dos seus atendimentos.', 'codigo' => 403];
            }
            if ($a['estado'] !== 'concluido') {
                $bd->rollBack(); return ['erro' => 'Só é possível registar o pagamento de atendimentos concluídos.', 'codigo' => 409];
            }
            $s = $bd->prepare('SELECT 1 FROM pagamentos WHERE atendimento_id = ?');
            $s->execute([$atendimentoId]);
            if ($s->fetch()) { $bd->rollBack(); return ['erro' => 'Este atendimento já tem o pagamento registado.', 'codigo' => 409]; }

            $bd->prepare('INSERT INTO pagamentos (atendimento_id, valor, metodo, registado_por) VALUES (?, ?, ?, ?)')
               ->execute([$atendimentoId, $a['preco_cobrado'], $metodo, $registadoPor]); // valor = preço do atendimento
            $id = (int)$bd->lastInsertId();
            $bd->commit();
            return ['id' => $id];
        } catch (Throwable $e) {
            if ($bd->inTransaction()) $bd->rollBack();
            throw $e;
        }
    }
}
