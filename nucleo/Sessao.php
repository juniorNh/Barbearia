<?php
declare(strict_types=1);

// Sessão segura.
final class Sessao
{
    public static function iniciar(): void
    {
        if (session_status() === PHP_SESSION_ACTIVE) return;
        session_name('barbearia_sessao');
        $segundos = (int)Configuracao::obter('sessao_horas') * 3600;
        ini_set('session.gc_maxlifetime', (string)$segundos);
        session_set_cookie_params([
            'lifetime' => $segundos, 'path' => '/', 'httponly' => true, 'samesite' => 'Lax',
            'secure'   => !empty($_SERVER['HTTPS']),
        ]);
        ini_set('session.use_strict_mode', '1');
        ini_set('session.use_only_cookies', '1');
        session_start();
    }

    public static function utilizador(): ?array
    {
        return $_SESSION['utilizador'] ?? null;
    }
}
