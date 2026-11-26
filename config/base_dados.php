<?php
declare(strict_types=1);

// Ligação única à base de dados (PDO, consultas preparadas, erros como exceções).
final class BaseDados
{
    private static ?PDO $ligacao = null;

    public static function ligar(): PDO
    {
        if (self::$ligacao === null) {
            $c = Configuracao::obter('bd');
            $dsn = "mysql:host={$c['servidor']};dbname={$c['nome']};charset=utf8mb4";
            self::$ligacao = new PDO($dsn, $c['utilizador'], $c['senha'], [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
            ]);
            // Maputo é UTC+2 e não tem hora de verão. Garante que "hoje" e as horas são as locais.
            self::$ligacao->exec("SET time_zone = '+02:00'");
        }
        return self::$ligacao;
    }
}
