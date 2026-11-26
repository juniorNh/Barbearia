<?php
declare(strict_types=1);

final class ControladorAgendamento
{
    // Criar agendamento: apenas clientes.
    public static function criar(): never
    {
        $utilizador = Autenticacao::exigir(Autenticacao::CLIENTE);

        $cliente = Cliente::porUtilizador((int)$utilizador['id']);

        if (!$cliente) {
            Resposta::erro('Conta de cliente não encontrada.', 404);
        }

        $c = Pedido::exigirEscrita();

        $r = Agendamento::criar(
            (int)$cliente['id'],
            (int)($c['servico_id'] ?? 0),
            (int)($c['funcionario_id'] ?? 0),
            Pedido::texto($c, 'data_hora')
        );

        if (isset($r['erro'])) {
            Resposta::erro($r['erro'], $r['codigo'] ?? 400);
        }

        Resposta::json(['id' => $r['id']], 201);
    }

    // Consultar agendamentos do cliente.
    public static function meus(): never
    {
        $utilizador = Autenticacao::exigir(Autenticacao::CLIENTE);

        $cliente = Cliente::porUtilizador((int)$utilizador['id']);

        if (!$cliente) {
            Resposta::erro('Conta de cliente não encontrada.', 404);
        }

        Resposta::json([
            'agendamentos' => Agendamento::listarCliente(
                (int)$cliente['id']
            )
        ]);
    }

    // Consultar todos os agendamentos: pessoal.
    public static function listar(): never
    {
        Autenticacao::exigir(Autenticacao::PESSOAL);

        Resposta::json([
            'agendamentos' => Agendamento::listarPessoal()
        ]);
    }

    // Cancelar agendamento do próprio cliente.
    public static function cancelar(): never
    {
        $utilizador = Autenticacao::exigir(Autenticacao::CLIENTE);

        $cliente = Cliente::porUtilizador((int)$utilizador['id']);

        if (!$cliente) {
            Resposta::erro('Conta de cliente não encontrada.', 404);
        }

        $c = Pedido::exigirEscrita();

        $id = (int)($c['id'] ?? 0);

        if ($id <= 0) {
            Resposta::erro('Agendamento inválido.');
        }

        $cancelado = Agendamento::cancelarCliente(
            $id,
            (int)$cliente['id']
        );

        if (!$cancelado) {
            Resposta::erro(
                'Não foi possível cancelar o agendamento.',
                409
            );
        }

        Resposta::json(['ok' => true]);
    }
}