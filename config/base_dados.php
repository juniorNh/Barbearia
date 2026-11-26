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

            $dsn = "mysql:host={$c['servidor']};port={$c['porta']};dbname={$c['nome']};charset=utf8mb4";

            $opcoes = [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
            ];

            // Só no Render (TiDB exige SSL). No XAMPP fica desligado.
            if ($c['ssl']) {
                $opcoes[PDO::MYSQL_ATTR_SSL_CA] = '/etc/ssl/certs/ca-certificates.crt';
            }

            try {
                self::$ligacao = new PDO($dsn, $c['utilizador'], $c['senha'], $opcoes);
            } catch (PDOException $e) {
                error_log('Falha na ligação à BD: ' . $e->getMessage());
                http_response_code(500);
                exit('Erro ao ligar à base de dados.');
            }

            // Maputo é UTC+2 e não tem hora de verão.
            self::$ligacao->exec("SET time_zone = '+02:00'");
        }
        return self::$ligacao;
    }
}