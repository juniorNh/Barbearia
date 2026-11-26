<?php
declare(strict_types=1);

// Proteção CSRF e utilitários de segurança.
final class Seguranca
{
    public static function tokenCsrf(): string
    {
        return $_SESSION['csrf'] ??= bin2hex(random_bytes(32));
    }

    public static function validarCsrf(): bool
    {
        $enviado = (string)($_SERVER['HTTP_X_CSRF_TOKEN'] ?? '');
        return $enviado !== '' && hash_equals(self::tokenCsrf(), $enviado);
    }

    public static function ip(): string
    {
        return substr((string)($_SERVER['REMOTE_ADDR'] ?? '0.0.0.0'), 0, 45);
    }
}
