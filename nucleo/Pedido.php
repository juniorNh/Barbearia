<?php
declare(strict_types=1);

// Leitura segura dos pedidos recebidos pela API.
final class Pedido
{
    public static function ehLeitura(): bool
    {
        return $_SERVER['REQUEST_METHOD'] === 'GET';
    }

    /** Para pedidos que alteram dados: exige POST, JSON e token CSRF. Devolve o corpo já descodificado. */
    public static function exigirEscrita(): array
    {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') Resposta::erro('Método não permitido.', 405);
        if (!str_starts_with((string)($_SERVER['CONTENT_TYPE'] ?? ''), 'application/json')) {
            Resposta::erro('Formato do pedido inválido.', 415);
        }
        if (!Seguranca::validarCsrf()) Resposta::erro('Pedido inválido. Recarregue a página e tente novamente.', 403);
        $corpo = json_decode((string)file_get_contents('php://input'), true);
        if (!is_array($corpo)) Resposta::erro('Pedido inválido.', 400);
        return $corpo;
    }

    public static function texto(array $corpo, string $campo): string
    {
        $v = $corpo[$campo] ?? '';
        if (is_int($v) || is_float($v)) $v = (string)$v;
        return is_string($v) ? trim($v) : '';
    }
}
