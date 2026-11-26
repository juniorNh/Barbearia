<?php
declare(strict_types=1);

// Acesso à tabela utilizadores (pessoal e contas de clientes).
final class Utilizador
{
    public static function porEmail(string $email): ?array
    {
        $s = BaseDados::ligar()->prepare('SELECT * FROM utilizadores WHERE email = ?');
        $s->execute([$email]);
        return $s->fetch() ?: null;
    }

    public static function porId(int $id): ?array
    {
        $s = BaseDados::ligar()->prepare('SELECT * FROM utilizadores WHERE id = ?');
        $s->execute([$id]);
        return $s->fetch() ?: null;
    }

    public static function criar(string $nome, string $email, string $senha, string $perfil): int
    {
        $bd = BaseDados::ligar();
        $s = $bd->prepare('INSERT INTO utilizadores (nome, email, senha_hash, perfil) VALUES (?, ?, ?, ?)');
        $s->execute([trim($nome), mb_strtolower(trim($email)), password_hash($senha, PASSWORD_DEFAULT), $perfil]);
        return (int)$bd->lastInsertId();
    }

    public static function listarPessoal(): array
    {
        return BaseDados::ligar()->query(
            "SELECT id, nome, email, perfil, ativo, data_registo FROM utilizadores
             WHERE perfil IN ('administrador','funcionario') ORDER BY ativo DESC, nome"
        )->fetchAll();
    }

    public static function alternarAtivo(int $id): void
    {
        $s = BaseDados::ligar()->prepare(
            "UPDATE utilizadores SET ativo = 1 - ativo WHERE id = ? AND perfil IN ('administrador','funcionario')");
        $s->execute([$id]);
    }

    public static function existeAdministrador(): bool
    {
        return (bool)BaseDados::ligar()->query("SELECT 1 FROM utilizadores WHERE perfil='administrador' LIMIT 1")->fetch();
    }
}
