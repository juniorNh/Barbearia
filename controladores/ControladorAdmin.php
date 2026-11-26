<?php
declare(strict_types=1);

// Área interna: gestão de utilizadores do pessoal (só Administrador).
final class ControladorAdmin
{
    public static function listar(): never
    {
        Autenticacao::exigir(['administrador']);
        Resposta::json(['utilizadores' => Utilizador::listarPessoal()]);
    }

    public static function criar(): never
    {
        Autenticacao::exigir(['administrador']);
        $c = Pedido::exigirEscrita();
        $nome = Pedido::texto($c, 'nome');
        $email = Pedido::texto($c, 'email');
        $perfil = Pedido::texto($c, 'perfil');
        $senha = (string)($c['senha'] ?? '');
        $erro = Validacao::primeiroErro(
            Validacao::nome($nome), Validacao::email($email),
            in_array($perfil, Autenticacao::PESSOAL, true) ? null : 'Perfil inválido.',
            Validacao::senha($senha, (string)($c['senha2'] ?? '')));
        if ($erro !== null) Resposta::erro($erro);
        if (Utilizador::porEmail(mb_strtolower($email))) Resposta::erro('Já existe uma conta com este email.', 409);
        Utilizador::criar($nome, $email, $senha, $perfil);
        Resposta::json(['ok' => true], 201);
    }

    public static function alternar(): never
    {
        $u = Autenticacao::exigir(['administrador']);
        $c = Pedido::exigirEscrita();
        $id = (int)($c['id'] ?? 0);
        if ($id === $u['id']) Resposta::erro('Não pode desativar a sua própria conta.');
        Utilizador::alternarAtivo($id);
        Resposta::json(['ok' => true]);
    }
}
