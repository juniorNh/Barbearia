<?php
declare(strict_types=1);

// Entrada, saída e controlo de acesso por perfil.
final class Autenticacao
{
    public const PESSOAL = ['administrador', 'funcionario'];
    public const CLIENTE = ['cliente'];

    /** Devolve true se a entrada foi aceite. */
    public static function entrar(string $email, string $senha, array $perfisPermitidos): bool
    {
        $u = Utilizador::porEmail(mb_strtolower(trim($email)));
        // A verificação é feita sempre, para não revelar se o email existe.
        $hash = $u['senha_hash'] ?? '$2y$10$usesomesillystringfore7hnbRJHxXVLeakoG8K30oukPsA.ztMG';
        $senhaOk = password_verify($senha, $hash);
        if (!$u || !$senhaOk || !(int)$u['ativo'] || !in_array($u['perfil'], $perfisPermitidos, true)) {
            TentativaAcesso::registar('entrada');
            return false;
        }
        session_regenerate_id(true);
        $_SESSION['utilizador'] = ['id' => (int)$u['id'], 'nome' => $u['nome'], 'perfil' => $u['perfil']];
        unset($_SESSION['csrf']);
        return true;
    }

    public static function sair(): void
    {
        $_SESSION = [];
        if (ini_get('session.use_cookies')) {
            $p = session_get_cookie_params();
            setcookie(session_name(), '', time() - 3600, $p['path'], $p['domain'] ?? '', $p['secure'], $p['httponly']);
        }
        session_destroy();
    }

    /** Barra o acesso se não houver sessão (401) ou se o perfil não for o exigido (403). */
    public static function exigir(array $perfis): array
    {
        $u = Sessao::utilizador();
        if ($u === null) Resposta::erro('Sessão expirada. Entre novamente.', 401);
        // Primeiro confirma que a conta continua ativa; só depois avalia o perfil.
        $atual = Utilizador::porId($u['id']);
        if (!$atual || !(int)$atual['ativo']) {
            self::sair();
            Resposta::erro('Sessão expirada. Entre novamente.', 401);
        }
        if (!in_array($u['perfil'], $perfis, true)) Resposta::erro('Acesso negado.', 403);
        return $u;
    }
}
