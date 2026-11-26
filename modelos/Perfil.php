<?php
declare(strict_types=1);

// Gestão dos dados do perfil do utilizador.
final class Perfil
{
    // Consultar os dados do perfil.
    public static function obter(int $utilizadorId): ?array
    {
        $sql = "
            SELECT
                u.id,
                u.nome,
                u.email,
                u.perfil,
                c.contacto
            FROM utilizadores u
            LEFT JOIN clientes c ON c.utilizador_id = u.id
            WHERE u.id = ?
        ";

        $s = BaseDados::ligar()->prepare($sql);
        $s->execute([$utilizadorId]);

        return $s->fetch() ?: null;
    }

    // Atualizar os dados pessoais.
    public static function atualizar(
        int $utilizadorId,
        string $nome,
        string $email,
        string $contacto
    ): bool {

        $bd = BaseDados::ligar();

        $utilizador = Utilizador::porId($utilizadorId);

        if (!$utilizador) {
            return false;
        }

        // Verificar se o email já pertence a outra conta.
        $s = $bd->prepare(
            'SELECT id FROM utilizadores WHERE email = ? AND id <> ?'
        );

        $s->execute([
            mb_strtolower(trim($email)),
            $utilizadorId
        ]);

        if ($s->fetch()) {
            return false;
        }

        $bd->beginTransaction();

        try {

            // Atualizar nome e email.
            $s = $bd->prepare(
                'UPDATE utilizadores SET nome = ?, email = ? WHERE id = ?'
            );

            $s->execute([
                trim($nome),
                mb_strtolower(trim($email)),
                $utilizadorId
            ]);

            // Se for cliente, atualizar também o seu registo.
            if ($utilizador['perfil'] === 'cliente') {

                $s = $bd->prepare(
                    'UPDATE clientes
                     SET nome_completo = ?, contacto = ?
                     WHERE utilizador_id = ?'
                );

                $s->execute([
                    trim($nome),
                    trim($contacto),
                    $utilizadorId
                ]);

                if ($s->rowCount() === 0) {
                    $verificar = $bd->prepare(
                        'SELECT id FROM clientes WHERE utilizador_id = ?'
                    );

                    $verificar->execute([$utilizadorId]);

                    if (!$verificar->fetch()) {
                        throw new RuntimeException(
                            'Registo de cliente não encontrado.'
                        );
                    }
                }
            }

            $bd->commit();

            return true;

        } catch (Throwable $e) {

            $bd->rollBack();
            throw $e;
        }
    }
}
