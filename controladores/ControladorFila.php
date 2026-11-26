<?php
declare(strict_types=1);

// Área do cliente: escolher o serviço e o barbeiro, entrar na fila e acompanhar a vez.
final class ControladorFila
{
    public static function minhaArea(): never
    {
        $cliente = self::cliente(Autenticacao::exigir(Autenticacao::CLIENTE));
        Resposta::json(Atendimento::minhaArea((int)$cliente['id']));
    }

    public static function entrar(): never
    {
        $cliente = self::cliente(Autenticacao::exigir(Autenticacao::CLIENTE));
        $c = Pedido::exigirEscrita();
        // O cliente vem sempre da sessão e o preço vem sempre do serviço: nada disso é lido do pedido.
        $r = Atendimento::entrarNaFila((int)$cliente['id'], (int)($c['servico_id'] ?? 0), (int)($c['funcionario_id'] ?? 0));
        if (isset($r['erro'])) {
            Resposta::erro($r['erro'] === Atendimento::JA_NA_FILA ? 'Já está na fila. Aguarde pela sua vez.' : $r['erro'], $r['codigo']);
        }
        Resposta::json(['id' => $r['id']], 201);
    }

    private static function cliente(array $utilizador): array
    {
        $cliente = Cliente::porUtilizador($utilizador['id']);
        if (!$cliente) Resposta::erro('Conta de cliente não encontrada.', 404);
        return $cliente;
    }
}
