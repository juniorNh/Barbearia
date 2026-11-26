<?php
declare(strict_types=1);

// Serviços e preços. A lista pública é aberta; a gestão é só do Administrador.
final class ControladorServico
{
    public static function publicos(): never
    {
        Resposta::json(['servicos' => Servico::listarAtivos()]);
    }

    public static function listar(): never
    {
        Autenticacao::exigir(['administrador']);
        Resposta::json(['servicos' => Servico::listarTodos()]);
    }

    public static function criar(): never
    {
        Autenticacao::exigir(['administrador']);

        [$nome, $descricao, $preco, $duracao] =
            self::dadosValidados(Pedido::exigirEscrita());

        if (Servico::nomeEmUso($nome)) {
            Resposta::erro('Já existe um serviço com este nome.', 409);
        }

        try {
            $id = Servico::criar($nome, $descricao, $preco, $duracao);
        } catch (PDOException $e) {
            if ($e->getCode() === '23000') Resposta::erro('Já existe um serviço com este nome.', 409);
            throw $e;
        }

        Resposta::json(['id' => $id], 201);
    }

    public static function editar(): never
    {
        Autenticacao::exigir(['administrador']);

        $c = Pedido::exigirEscrita();

        $id = (int)($c['id'] ?? 0);

        if (!Servico::porId($id)) {
            Resposta::erro('Serviço não encontrado.', 404);
        }

        [$nome, $descricao, $preco, $duracao] =
            self::dadosValidados($c);

        if (Servico::nomeEmUso($nome, $id)) {
            Resposta::erro('Já existe um serviço com este nome.', 409);
        }

        try {
            Servico::atualizar($id, $nome, $descricao, $preco, $duracao);
        } catch (PDOException $e) {
            if ($e->getCode() === '23000') Resposta::erro('Já existe um serviço com este nome.', 409);
            throw $e;
        }

        Resposta::json(['ok' => true]);
    }

    public static function alternar(): never
    {
        Autenticacao::exigir(['administrador']);
        $c = Pedido::exigirEscrita();
        $id = (int)($c['id'] ?? 0);
        if (!Servico::porId($id)) Resposta::erro('Serviço não encontrado.', 404);
        Servico::alternarAtivo($id);
        Resposta::json(['ok' => true]);
    }

    /** Valida o corpo do pedido e devolve [nome, descrição, preço, duração em minutos]. */
    private static function dadosValidados(array $c): array
    {
        $nome = Pedido::texto($c, 'nome');
        $descricao = Pedido::texto($c, 'descricao');
        $preco = Pedido::texto($c, 'preco');

        $duracao = filter_var(
            $c['duracao_minutos'] ?? null,
            FILTER_VALIDATE_INT
        );

        $erro = Validacao::primeiroErro(
            Validacao::nomeServico($nome),
            Validacao::descricaoServico($descricao),
            Validacao::preco($preco)
        );

        if ($erro !== null) {
            Resposta::erro($erro);
        }

        if ($duracao === false || $duracao < 5 || $duracao > 240) {
            Resposta::erro(
                'A duração deve estar entre 5 e 240 minutos.'
            );
        }

        return [$nome, $descricao, $preco, $duracao];
    }
}
