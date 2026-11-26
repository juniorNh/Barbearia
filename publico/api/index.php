<?php
declare(strict_types=1);

// Ponto de entrada único da API.
require __DIR__ . '/../../nucleo/arranque.php';

try {

    $leitura = Pedido::ehLeitura();

    match ($_GET['r'] ?? '') {

        // Sessão.
        'sessao' => ControladorSessao::sessao(),
        'entrar' => ControladorSessao::entrar(),
        'sair' => ControladorSessao::sair(),

        // Contas.
        'registar' => ControladorConta::registar(),

        // Utilizadores.
        'utilizadores' =>
            $leitura
                ? ControladorAdmin::listar()
                : ControladorAdmin::criar(),

        'utilizadores_alternar' =>
            ControladorAdmin::alternar(),

        // Clientes.
        'clientes' =>
            $leitura
                ? ControladorCliente::listar()
                : ControladorCliente::criar(),

        'clientes_editar' =>
            ControladorCliente::editar(),

        // Barbeiros.
        'barbeiros' =>
            ControladorAtendimento::barbeiros(),

        // Atendimentos.
        'atendimentos' =>
            $leitura
                ? ControladorAtendimento::listar()
                : ControladorAtendimento::criar(),

        'atendimentos_estado' =>
            ControladorAtendimento::mudarEstado(),

        // Fila.
        'fila' =>
            ControladorAtendimento::fila(),

        'minha_area' =>
            ControladorFila::minhaArea(),

        'entrar_na_fila' =>
            ControladorFila::entrar(),

        // Serviços.
        'servicos_publicos' =>
            ControladorServico::publicos(),

        'servicos' =>
            $leitura
                ? ControladorServico::listar()
                : ControladorServico::criar(),

        'servicos_editar' =>
            ControladorServico::editar(),

        'servicos_alternar' =>
            ControladorServico::alternar(),

        // AGENDAMENTOS.
        'agendamentos_criar' =>
            ControladorAgendamento::criar(),

        'agendamentos_meus' =>
            ControladorAgendamento::meus(),

        'agendamentos_pessoal' =>
            ControladorAgendamento::listar(),

        'agendamentos_cancelar' =>
            ControladorAgendamento::cancelar(),

        // Perfil pessoal.
        'perfil' =>
            $leitura
                ? ControladorPerfil::obter()
                : ControladorPerfil::atualizar(),

        // FINANÇAS.
        'por_receber' =>
            ControladorPagamento::porReceber(),

        'pagamentos' =>
            $leitura
                ? ControladorPagamento::listar()
                : ControladorPagamento::registar(),

        'despesas' =>
            $leitura
                ? ControladorFinanca::despesasListar()
                : ControladorFinanca::despesasCriar(),

        'financas_resumo' =>
            ControladorFinanca::resumo(),

        'financas_serie' =>
            ControladorFinanca::serie(),

        'financas_historico' =>
            ControladorFinanca::historico(),

        default =>
            Resposta::erro('Rota não encontrada.', 404),
    };

} catch (Throwable $e) {

    error_log((string)$e);

    Resposta::erro(
        'Erro interno. Tente novamente mais tarde.',
        500
    );
}
