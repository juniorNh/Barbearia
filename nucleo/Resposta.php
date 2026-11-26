<?php
declare(strict_types=1);

// Respostas da API: sempre JSON.
final class Resposta
{
    public static function json(array $dados, int $codigo = 200): never
    {
        http_response_code($codigo);
        header('Content-Type: application/json; charset=utf-8');
        header('Cache-Control: no-store');
        echo json_encode($dados, JSON_UNESCAPED_UNICODE);
        exit;
    }

    public static function erro(string $mensagem, int $codigo = 400): never
    {
        self::json(['erro' => $mensagem], $codigo);
    }
}
