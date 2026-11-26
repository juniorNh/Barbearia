<?php
declare(strict_types=1);

// Atendimentos e fila. Cada entrada na fila é um atendimento com estado:
// em_espera -> em_atendimento -> concluido  (ou cancelado). Só os concluídos contam como receita.
final class Atendimento
{
    public const POR_PAGINA = 20;
    public const JA_NA_FILA = 'JA_NA_FILA';
    public const ESTADOS = ['em_espera', 'em_atendimento', 'concluido', 'cancelado'];
    private const ACOES = [
        'iniciar'  => ['de' => ['em_espera'],                    'para' => 'em_atendimento'],
        'concluir' => ['de' => ['em_atendimento'],               'para' => 'concluido'],
        'cancelar' => ['de' => ['em_espera', 'em_atendimento'], 'para' => 'cancelado'],
    ];
    // Contagem de pessoas à frente (RN02): mesmo barbeiro, hoje, ainda ativas e registadas antes.
    private const A_FRENTE = "(SELECT COUNT(*) FROM atendimentos x WHERE x.funcionario_id = a.funcionario_id
        AND x.estado IN ('em_espera','em_atendimento') AND x.data_hora >= CURDATE() AND x.id < a.id)";

    public static function acaoValida(string $acao): bool
    {
        return isset(self::ACOES[$acao]);
    }

    /** Pedidos em espera de dias anteriores nunca chegaram a ser atendidos: passam a cancelados. */
    public static function expirarAntigos(): void
    {
        BaseDados::ligar()->exec(
            "UPDATE atendimentos SET estado = 'cancelado' WHERE estado = 'em_espera' AND data_hora < CURDATE()");
    }

    /** Barbeiros disponíveis (contas ativas do pessoal) com o número de pessoas na fila de hoje. */
    public static function barbeiros(): array
    {
        self::expirarAntigos();
        return BaseDados::ligar()->query(
            "SELECT u.id, u.nome,
                    (SELECT COUNT(*) FROM atendimentos a WHERE a.funcionario_id = u.id
                       AND a.estado IN ('em_espera','em_atendimento') AND a.data_hora >= CURDATE()) AS na_fila
             FROM utilizadores u WHERE u.ativo = 1 AND u.perfil IN ('administrador','funcionario') ORDER BY u.nome")->fetchAll();
    }

    private static function barbeiroValido(int $id): bool
    {
        $s = BaseDados::ligar()->prepare(
            "SELECT 1 FROM utilizadores WHERE id = ? AND ativo = 1 AND perfil IN ('administrador','funcionario')");
        $s->execute([$id]);
        return (bool)$s->fetch();
    }

    /**
     * Regista uma entrada na fila. O preço vem sempre da tabela de serviços (RN01).
     * Devolve ['id' => int] ou ['erro' => mensagem, 'codigo' => http].
     */
    public static function entrarNaFila(int $clienteId, int $servicoId, int $funcionarioId): array
    {
        self::expirarAntigos();
        $bd = BaseDados::ligar();
        $bd->beginTransaction();
        try {
            $s = $bd->prepare('SELECT id FROM clientes WHERE id = ? FOR UPDATE'); // serializa pedidos do mesmo cliente
            $s->execute([$clienteId]);
            if (!$s->fetch()) { $bd->rollBack(); return ['erro' => 'Cliente não encontrado.', 'codigo' => 404]; }

            $s = $bd->prepare("SELECT 1 FROM atendimentos WHERE cliente_id = ? AND estado IN ('em_espera','em_atendimento') AND data_hora >= CURDATE()");
            $s->execute([$clienteId]);
            if ($s->fetch()) { $bd->rollBack(); return ['erro' => self::JA_NA_FILA, 'codigo' => 409]; } // RN03

            $s = $bd->prepare('SELECT preco FROM servicos WHERE id = ? AND ativo = 1');
            $s->execute([$servicoId]);
            $servico = $s->fetch();
            if (!$servico) { $bd->rollBack(); return ['erro' => 'Serviço indisponível.', 'codigo' => 400]; } // RN05
            if (!self::barbeiroValido($funcionarioId)) { $bd->rollBack(); return ['erro' => 'Barbeiro indisponível.', 'codigo' => 400]; }

            $bd->prepare('INSERT INTO atendimentos (cliente_id, servico_id, funcionario_id, preco_cobrado) VALUES (?, ?, ?, ?)')
               ->execute([$clienteId, $servicoId, $funcionarioId, $servico['preco']]);
            $id = (int)$bd->lastInsertId();
            $bd->commit();
            return ['id' => $id];
        } catch (Throwable $e) {
            $bd->rollBack();
            throw $e;
        }
    }

    /** Fila ativa de hoje (e atendimentos em curso). Se $funcionarioId vier preenchido, só a desse barbeiro. */
    public static function fila(?int $funcionarioId): array
    {
        self::expirarAntigos();
        $onde = "((a.estado = 'em_espera' AND a.data_hora >= CURDATE()) OR a.estado = 'em_atendimento')";
        $params = [];
        if ($funcionarioId !== null) { $onde .= ' AND a.funcionario_id = ?'; $params[] = $funcionarioId; }
        $s = BaseDados::ligar()->prepare(
            'SELECT a.id, a.data_hora, a.estado, a.preco_cobrado, a.funcionario_id, c.nome_completo AS cliente,
                    s.nome AS servico, u.nome AS funcionario, ' . self::A_FRENTE . " AS a_frente
             FROM atendimentos a JOIN clientes c ON c.id = a.cliente_id JOIN servicos s ON s.id = a.servico_id
             JOIN utilizadores u ON u.id = a.funcionario_id WHERE $onde ORDER BY u.nome, a.id");
        $s->execute($params);
        return $s->fetchAll();
    }

    /** Histórico paginado. $funcionarioId limita ao barbeiro; $estado '' = todos. */
    public static function historico(?int $funcionarioId, string $estado, int $pagina): array
    {
        $onde = []; $params = [];
        if ($funcionarioId !== null) { $onde[] = 'a.funcionario_id = ?'; $params[] = $funcionarioId; }
        if ($estado !== '') { $onde[] = 'a.estado = ?'; $params[] = $estado; }
        $filtro = $onde ? 'WHERE ' . implode(' AND ', $onde) : '';
        $bd = BaseDados::ligar();
        $s = $bd->prepare("SELECT COUNT(*) FROM atendimentos a $filtro");
        $s->execute($params);
        $total = (int)$s->fetchColumn();
        $limite = self::POR_PAGINA;
        $desloc = (max(1, $pagina) - 1) * $limite;
        $s = $bd->prepare(
            "SELECT a.id, a.data_hora, a.estado, a.preco_cobrado, c.nome_completo AS cliente, s.nome AS servico, u.nome AS funcionario
             FROM atendimentos a JOIN clientes c ON c.id = a.cliente_id JOIN servicos s ON s.id = a.servico_id
             JOIN utilizadores u ON u.id = a.funcionario_id $filtro ORDER BY a.id DESC LIMIT $limite OFFSET $desloc");
        $s->execute($params);
        return ['atendimentos' => $s->fetchAll(), 'total' => $total];
    }

    /** Área do cliente: o pedido ativo (com a posição na fila) e os últimos atendimentos. */
    public static function minhaArea(int $clienteId): array
    {
        self::expirarAntigos();
        $bd = BaseDados::ligar();
        $base = 'SELECT a.id, a.data_hora, a.estado, a.preco_cobrado, s.nome AS servico, u.nome AS funcionario, '
              . self::A_FRENTE . ' AS a_frente FROM atendimentos a JOIN servicos s ON s.id = a.servico_id
                JOIN utilizadores u ON u.id = a.funcionario_id WHERE a.cliente_id = ?';
        $s = $bd->prepare($base . " AND a.estado IN ('em_espera','em_atendimento') AND a.data_hora >= CURDATE() ORDER BY a.id DESC LIMIT 1");
        $s->execute([$clienteId]);
        $ativo = $s->fetch() ?: null;
        $s = $bd->prepare($base . ' ORDER BY a.id DESC LIMIT 20');
        $s->execute([$clienteId]);
        return ['ativo' => $ativo, 'historico' => $s->fetchAll()];
    }

    /**
     * Muda o estado (iniciar, concluir, cancelar). $soFuncionario limita ao barbeiro dono do atendimento.
     * Devolve ['ok' => true] ou ['erro' => mensagem, 'codigo' => http].
     */
    public static function mudarEstado(int $id, string $acao, ?int $soFuncionario): array
    {
        $regra = self::ACOES[$acao];
        $bd = BaseDados::ligar();
        $bd->beginTransaction();
        try {
            $s = $bd->prepare('SELECT id, estado, funcionario_id FROM atendimentos WHERE id = ? FOR UPDATE');
            $s->execute([$id]);
            $a = $s->fetch();
            if (!$a) { $bd->rollBack(); return ['erro' => 'Atendimento não encontrado.', 'codigo' => 404]; }
            if ($soFuncionario !== null && (int)$a['funcionario_id'] !== $soFuncionario) {
                $bd->rollBack(); return ['erro' => 'Só pode gerir os seus atendimentos.', 'codigo' => 403];
            }
            if (!in_array($a['estado'], $regra['de'], true)) {
                $bd->rollBack(); return ['erro' => 'O estado atual do atendimento não permite esta ação.', 'codigo' => 409];
            }
            if ($acao === 'iniciar') { // um barbeiro atende uma pessoa de cada vez
                $bd->prepare('SELECT id FROM utilizadores WHERE id = ? FOR UPDATE')->execute([$a['funcionario_id']]);
                $s = $bd->prepare("SELECT 1 FROM atendimentos WHERE funcionario_id = ? AND estado = 'em_atendimento' AND id <> ?");
                $s->execute([$a['funcionario_id'], $id]);
                if ($s->fetch()) { $bd->rollBack(); return ['erro' => 'Conclua primeiro o atendimento em curso.', 'codigo' => 409]; }
            }
            $concluido = $acao === 'concluir' ? ', concluido_em = NOW()' : '';
            $bd->prepare("UPDATE atendimentos SET estado = ?$concluido WHERE id = ?")->execute([$regra['para'], $id]);
            $bd->commit();
            return ['ok' => true];
        } catch (Throwable $e) {
            $bd->rollBack();
            throw $e;
        }
    }
}
