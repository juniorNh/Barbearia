<?php
declare(strict_types=1);

final class Servico
{
    public static function listarAtivos(): array
    {
        return BaseDados::ligar()->query(
            'SELECT id, nome, descricao, preco, duracao_minutos
             FROM servicos
             WHERE ativo = 1
             ORDER BY nome'
        )->fetchAll();
    }

    public static function listarTodos(): array
    {
        return BaseDados::ligar()->query(
            'SELECT id, nome, descricao, preco, duracao_minutos, ativo
             FROM servicos
             ORDER BY ativo DESC, nome'
        )->fetchAll();
    }

    public static function porId(int $id): ?array
    {
        $s = BaseDados::ligar()->prepare(
            'SELECT id, nome, descricao, preco, duracao_minutos, ativo
             FROM servicos WHERE id = ?'
        );

        $s->execute([$id]);

        return $s->fetch() ?: null;
    }

    public static function nomeEmUso(string $nome, int $ignorarId = 0): bool
    {
        $s = BaseDados::ligar()->prepare(
            'SELECT 1 FROM servicos WHERE nome = ? AND id <> ?'
        );

        $s->execute([trim($nome), $ignorarId]);

        return (bool)$s->fetch();
    }

    public static function criar(
        string $nome,
        string $descricao,
        string $preco,
        int $duracao
    ): int {
        $bd = BaseDados::ligar();

        $s = $bd->prepare(
            'INSERT INTO servicos
             (nome, descricao, preco, duracao_minutos)
             VALUES (?, ?, ?, ?)'
        );

        $s->execute([
            trim($nome),
            $descricao !== '' ? $descricao : null,
            Validacao::normalizarPreco($preco),
            $duracao
        ]);

        return (int)$bd->lastInsertId();
    }

    public static function atualizar(
        int $id,
        string $nome,
        string $descricao,
        string $preco,
        int $duracao
    ): void {
        $s = BaseDados::ligar()->prepare(
            'UPDATE servicos
             SET nome = ?, descricao = ?, preco = ?, duracao_minutos = ?
             WHERE id = ?'
        );

        $s->execute([
            trim($nome),
            $descricao !== '' ? $descricao : null,
            Validacao::normalizarPreco($preco),
            $duracao,
            $id
        ]);
    }

    public static function alternarAtivo(int $id): void
    {
        BaseDados::ligar()->prepare(
            'UPDATE servicos SET ativo = 1 - ativo WHERE id = ?'
        )->execute([$id]);
    }
}
