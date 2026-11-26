<?php
declare(strict_types=1);

// Controlador do perfil pessoal.
final class ControladorPerfil
{
    private const PERFIS = [
        'cliente',
        'funcionario',
        'administrador'
    ];

    // Consultar perfil.
    public static function obter(): never
    {
        $utilizador = Autenticacao::exigir(self::PERFIS);

        $perfil = Perfil::obter((int)$utilizador['id']);

        if (!$perfil) {
            Resposta::erro('Perfil não encontrado.', 404);
        }

        Resposta::json(['perfil' => $perfil]);
    }

    // Atualizar perfil.
    public static function atualizar(): never
    {
        $utilizador = Autenticacao::exigir(self::PERFIS);

        $c = Pedido::exigirEscrita();

        $nome = Pedido::texto($c, 'nome');
        $email = mb_strtolower(Pedido::texto($c, 'email'));
        $contacto = Pedido::texto($c, 'contacto');

        $perfilAtual = Perfil::obter((int)$utilizador['id']);

        if (!$perfilAtual) {
            Resposta::erro('Perfil não encontrado.', 404);
        }

        $erro = Validacao::primeiroErro(
            Validacao::nome($nome),
            Validacao::email($email)
        );

        if ($perfilAtual['perfil'] === 'cliente') {
            $erro = Validacao::primeiroErro(
                $erro,
                Validacao::contacto($contacto)
            );
        }

        if ($erro !== null) {
            Resposta::erro($erro);
        }

        $atualizado = Perfil::atualizar(
            (int)$utilizador['id'],
            $nome,
            $email,
            $contacto
        );

        if (!$atualizado) {
            Resposta::erro(
                'Este email já está associado a outra conta.',
                409
            );
        }

        // O nome mostrado no menu e nas boas-vindas vem da sessão: mantém-na atualizada.
        $_SESSION['utilizador']['nome'] = $nome;

        Resposta::json([
            'ok' => true,
            'perfil' => Perfil::obter((int)$utilizador['id'])
        ]);
    }
}
