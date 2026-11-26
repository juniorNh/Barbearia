<?php
declare(strict_types=1);

// Acesso à tabela clientes.
final class Cliente
{
    public const POR_PAGINA = 20;

    /** Cria a conta (utilizador com perfil cliente) e o registo do cliente numa única transação. */
    public static function criarComConta(string $nome, string $contacto, string $email, string $senha): int
    {
        $bd = BaseDados::ligar();
        $bd->beginTransaction();
        try {
            $utilizadorId = Utilizador::criar($nome, $email, $senha, 'cliente'); // perfil fixado aqui, nunca vem do formulário
            $s = $bd->prepare('INSERT INTO clientes (nome_completo, contacto, utilizador_id) VALUES (?, ?, ?)');
            $s->execute([trim($nome), trim($contacto), $utilizadorId]);
            $id = (int)$bd->lastInsertId();
            $bd->commit();
            return $id;
        } catch (Throwable $e) {
            $bd->rollBack();
            throw $e;
        }
    }

    /** Cliente registado pelo pessoal (sem conta de acesso). */
    public static function criar(string $nome, string $contacto): int
    {
        $bd = BaseDados::ligar();
        $bd->prepare('INSERT INTO clientes (nome_completo, contacto) VALUES (?, ?)')->execute([trim($nome), trim($contacto)]);
        return (int)$bd->lastInsertId();
    }

    public static function porId(int $id): ?array
    {
        $s = BaseDados::ligar()->prepare('SELECT id, nome_completo, contacto, utilizador_id, data_registo FROM clientes WHERE id = ?');
        $s->execute([$id]);
        return $s->fetch() ?: null;
    }

    /** O registo de cliente que pertence a uma conta (perfil cliente). */
    public static function porUtilizador(int $utilizadorId): ?array
    {
        $s = BaseDados::ligar()->prepare('SELECT id, nome_completo FROM clientes WHERE utilizador_id = ?');
        $s->execute([$utilizadorId]);
        return $s->fetch() ?: null;
    }

    /** Pesquisa por nome ou contacto (ignora maiúsculas, acentos e espaços no contacto), com paginação. */
    public static function pesquisar(string $termo, int $pagina): array
    {
        [$onde, $parametros] = self::filtro($termo);
        $bd = BaseDados::ligar();
        $s = $bd->prepare("SELECT COUNT(*) FROM clientes $onde");
        $s->execute($parametros);
        $total = (int)$s->fetchColumn();

        $limite = self::POR_PAGINA;
        $deslocamento = (max(1, $pagina) - 1) * $limite;
        $s = $bd->prepare(
            "SELECT id, nome_completo, contacto, (utilizador_id IS NOT NULL) AS tem_conta, data_registo
             FROM clientes $onde ORDER BY nome_completo, id LIMIT $limite OFFSET $deslocamento");
        $s->execute($parametros);
        return ['clientes' => $s->fetchAll(), 'total' => $total];
    }

    /** Atualiza o cliente. Se tiver conta, o nome da conta acompanha, para não haver dois nomes diferentes. */
    public static function atualizar(int $id, string $nome, string $contacto): void
    {
        $bd = BaseDados::ligar();
        $atual = self::porId($id);
        $bd->beginTransaction();
        try {
            $bd->prepare('UPDATE clientes SET nome_completo = ?, contacto = ? WHERE id = ?')->execute([trim($nome), trim($contacto), $id]);
            if ($atual && $atual['utilizador_id'] !== null) {
                $bd->prepare('UPDATE utilizadores SET nome = ? WHERE id = ?')->execute([trim($nome), $atual['utilizador_id']]);
            }
            $bd->commit();
        } catch (Throwable $e) {
            $bd->rollBack();
            throw $e;
        }
    }

    private static function filtro(string $termo): array
    {
        $termo = trim($termo);
        if ($termo === '') return ['', []];
        $escapar = fn(string $t) => '%' . addcslashes($t, '\\%_') . '%'; // % e _ do utilizador valem como texto
        $comEspacos = $escapar($termo);
        $semEspacos = $escapar(str_replace(' ', '', $termo));
        return ["WHERE nome_completo LIKE ? OR contacto LIKE ? OR REPLACE(contacto, ' ', '') LIKE ?",
                [$comEspacos, $comEspacos, $semEspacos]];
    }
}
