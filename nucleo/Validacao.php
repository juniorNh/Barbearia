<?php
declare(strict_types=1);

// Validação de dados introduzidos. Cada método devolve null (válido) ou a mensagem de erro.
final class Validacao
{
    public static function nome(string $v): ?string
    {
        $n = mb_strlen(trim($v));
        return ($n < 3 || $n > 120) ? 'Indique o nome completo (3 a 120 caracteres).' : null;
    }

    public static function email(string $v): ?string
    {
        return (filter_var($v, FILTER_VALIDATE_EMAIL) && mb_strlen($v) <= 120) ? null : 'Indique um email válido.';
    }

    public static function contacto(string $v): ?string
    {
        return preg_match('/^\+?[0-9 ]{7,20}$/', trim($v)) ? null : 'Indique um contacto válido (7 a 20 dígitos).';
    }

    public static function senha(string $v, string $confirmacao): ?string
    {
        $min = Configuracao::obter('senha_min');
        if (mb_strlen($v) < $min) return "A senha precisa de pelo menos $min caracteres.";
        if ($v !== $confirmacao) return 'As senhas não coincidem.';
        return null;
    }

    public static function nomeServico(string $v): ?string
    {
        $n = mb_strlen(trim($v));
        return ($n < 2 || $n > 80) ? 'Indique o nome do serviço (2 a 80 caracteres).' : null;
    }

    public static function descricaoServico(string $v): ?string
    {
        return mb_strlen($v) > 255 ? 'A descrição pode ter no máximo 255 caracteres.' : null;
    }

    /** O preço é sempre maior que zero, com até 2 casas decimais (aceita vírgula). */
    public static function preco(string $v): ?string
    {
        $v = str_replace(',', '.', trim($v));
        if (!preg_match('/^\d{1,8}(\.\d{1,2})?$/', $v) || (float)$v <= 0) {
            return 'Indique um preço válido, maior que zero (por exemplo 200 ou 150,50).';
        }
        return null;
    }

    public static function normalizarPreco(string $v): string
    {
        return number_format((float)str_replace(',', '.', trim($v)), 2, '.', '');
    }

    public static function data(string $v): ?string
    {
        $d = DateTime::createFromFormat('Y-m-d', $v);
        return ($d && $d->format('Y-m-d') === $v) ? null : 'Indique uma data válida.';
    }

    public static function descricaoDespesa(string $v): ?string
    {
        $n = mb_strlen(trim($v));
        return ($n < 3 || $n > 200) ? 'Indique a descrição da despesa (3 a 200 caracteres).' : null;
    }

    /** Valor monetário maior que zero, com até 2 casas decimais (aceita vírgula). */
    public static function valor(string $v): ?string
    {
        $v = str_replace(',', '.', trim($v));
        if (!preg_match('/^\d{1,8}(\.\d{1,2})?$/', $v) || (float)$v <= 0) {
            return 'Indique um valor válido, maior que zero (por exemplo 500 ou 75,50).';
        }
        return null;
    }

    /** Devolve a primeira mensagem de erro de uma lista, ou null. */
    public static function primeiroErro(?string ...$erros): ?string
    {
        foreach ($erros as $e) if ($e !== null) return $e;
        return null;
    }
}
