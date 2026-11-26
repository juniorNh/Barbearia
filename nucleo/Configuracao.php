<?php
declare(strict_types=1);

final class Configuracao
{
    private static ?array $dados = null;

    public static function obter(string $chave): mixed
    {
        self::$dados ??= require __DIR__ . '/../config/configuracao.php';

        return self::$dados[$chave] ?? null;
    }
}
