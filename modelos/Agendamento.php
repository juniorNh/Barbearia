<?php
declare(strict_types=1);

final class Agendamento
{
    /**
     * Criar um agendamento.
     */
    public static function criar(
        int $clienteId,
        int $servicoId,
        int $funcionarioId,
        string $dataHora
    ): array {

        $data = DateTime::createFromFormat('Y-m-d\TH:i', $dataHora);
        $agora = new DateTime();

        if (
            !$data ||
            $data->format('Y-m-d\TH:i') !== $dataHora ||
            $data <= $agora
        ) {
            return [
                'erro' => 'Escolha uma data e hora futuras válidas.',
                'codigo' => 400
            ];
        }

        if ($data > (clone $agora)->modify('+90 days')) {
            return [
                'erro' => 'Só é possível marcar até 90 dias de antecedência.',
                'codigo' => 400
            ];
        }

        $bd = BaseDados::ligar();
        $bd->beginTransaction();

        try {
            // Verificar cliente.
            $s = $bd->prepare(
                'SELECT id FROM clientes WHERE id = ? FOR UPDATE'
            );

            $s->execute([$clienteId]);

            if (!$s->fetch()) {
                $bd->rollBack();

                return [
                    'erro' => 'Cliente não encontrado.',
                    'codigo' => 404
                ];
            }

            // Obter preço e duração do serviço.
            $s = $bd->prepare(
                'SELECT preco, duracao_minutos
                 FROM servicos
                 WHERE id = ? AND ativo = 1'
            );

            $s->execute([$servicoId]);
            $servico = $s->fetch();

            if (!$servico) {
                $bd->rollBack();

                return [
                    'erro' => 'Serviço indisponível.',
                    'codigo' => 400
                ];
            }

            $duracao = (int)$servico['duracao_minutos'];

            if ($duracao < 5 || $duracao > 240) {
                $bd->rollBack();

                return [
                    'erro' => 'Duração do serviço inválida.',
                    'codigo' => 400
                ];
            }

            // Verificar funcionário.
            $s = $bd->prepare(
                "SELECT id
                 FROM utilizadores
                 WHERE id = ?
                 AND ativo = 1
                 AND perfil IN ('administrador', 'funcionario')
                 FOR UPDATE"
            );

            $s->execute([$funcionarioId]);

            if (!$s->fetch()) {
                $bd->rollBack();

                return [
                    'erro' => 'Barbeiro indisponível.',
                    'codigo' => 400
                ];
            }

            // Calcular o fim do agendamento.
            $inicio = $data->format('Y-m-d H:i:s');

            $fim = clone $data;
            $fim->modify("+{$duracao} minutes");

            $fimNovo = $fim->format('Y-m-d H:i:s');

            // Verificar conflitos de horário.
            $s = $bd->prepare(
                "SELECT id
                 FROM agendamentos
                 WHERE funcionario_id = ?
                 AND estado IN ('pendente', 'confirmado')
                 AND data_hora < ?
                 AND DATE_ADD(
                     data_hora,
                     INTERVAL duracao_minutos MINUTE
                 ) > ?
                 LIMIT 1"
            );

            $s->execute([
                $funcionarioId,
                $fimNovo,
                $inicio
            ]);

            if ($s->fetch()) {
                $bd->rollBack();

                return [
                    'erro' => 'O barbeiro já tem um agendamento nesse horário.',
                    'codigo' => 409
                ];
            }

            // Inserir agendamento.
            $s = $bd->prepare(
                'INSERT INTO agendamentos
                (
                    cliente_id,
                    servico_id,
                    funcionario_id,
                    preco_cobrado,
                    duracao_minutos,
                    data_hora
                )
                VALUES (?, ?, ?, ?, ?, ?)'
            );

            $s->execute([
                $clienteId,
                $servicoId,
                $funcionarioId,
                $servico['preco'],
                $duracao,
                $inicio
            ]);

            $id = (int)$bd->lastInsertId();

            $bd->commit();

            return ['id' => $id];

        } catch (Throwable $e) {
            if ($bd->inTransaction()) {
                $bd->rollBack();
            }

            throw $e;
        }
    }

    /**
     * Listar agendamentos de um cliente.
     */
    public static function listarCliente(int $clienteId): array
    {
        $s = BaseDados::ligar()->prepare(
            "SELECT
                a.id,
                a.data_hora,
                a.duracao_minutos,
                a.preco_cobrado,
                a.estado,
                s.nome AS servico,
                u.nome AS funcionario
             FROM agendamentos a
             JOIN servicos s ON s.id = a.servico_id
             JOIN utilizadores u ON u.id = a.funcionario_id
             WHERE a.cliente_id = ?
             ORDER BY a.data_hora DESC"
        );

        $s->execute([$clienteId]);

        return $s->fetchAll();
    }

    /**
     * Listar todos os agendamentos para o pessoal.
     */
    public static function listarPessoal(): array
    {
        return BaseDados::ligar()->query(
            "SELECT
                a.id,
                a.data_hora,
                a.duracao_minutos,
                a.preco_cobrado,
                a.estado,
                c.nome_completo AS cliente,
                s.nome AS servico,
                u.nome AS funcionario
             FROM agendamentos a
             JOIN clientes c ON c.id = a.cliente_id
             JOIN servicos s ON s.id = a.servico_id
             JOIN utilizadores u ON u.id = a.funcionario_id
             ORDER BY a.data_hora DESC"
        )->fetchAll();
    }

    /**
     * Cancelar agendamento do próprio cliente.
     */
    public static function cancelarCliente(
        int $agendamentoId,
        int $clienteId
    ): bool {

        $s = BaseDados::ligar()->prepare(
            "UPDATE agendamentos
             SET estado = 'cancelado'
             WHERE id = ?
             AND cliente_id = ?
             AND estado IN ('pendente', 'confirmado')
             AND data_hora > NOW()"
        );

        $s->execute([$agendamentoId, $clienteId]);

        return $s->rowCount() > 0;
    }
}
