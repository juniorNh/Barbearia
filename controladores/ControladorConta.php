<?php
declare(strict_types=1);

// Área do cliente: criação de conta.
final class ControladorConta
{
    public static function registar(): never
    {
        $c = Pedido::exigirEscrita();
        if (TentativaAcesso::excedeu('registo')) {
            Resposta::erro('Demasiadas tentativas. Aguarde alguns minutos e tente novamente.', 429);
        }
        $nome = Pedido::texto($c, 'nome');
        $contacto = Pedido::texto($c, 'contacto');
        $email = Pedido::texto($c, 'email');
        $senha = (string)($c['senha'] ?? '');
        $erro = Validacao::primeiroErro(
            Validacao::nome($nome), Validacao::contacto($contacto), Validacao::email($email),
            Validacao::senha($senha, (string)($c['senha2'] ?? '')));
        if ($erro !== null) Resposta::erro($erro);
        if (Utilizador::porEmail(mb_strtolower($email))) Resposta::erro('Este email já está registado.', 409);

        TentativaAcesso::registar('registo');
        try {
            Cliente::criarComConta($nome, $contacto, $email, $senha);
        } catch (PDOException $e) {
            if ($e->getCode() === '23000') Resposta::erro('Este email já está registado.', 409);
            throw $e;
        }
        Resposta::json(['ok' => true], 201);
    }
}
