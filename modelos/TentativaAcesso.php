<?php
declare(strict_types=1);

// Limite de tentativas de entrada e de registo por endereço IP.
final class TentativaAcesso
{
    public static function registar(string $tipo): void
    {
        $bd = BaseDados::ligar();
        $bd->prepare('INSERT INTO tentativas_acesso (ip, tipo) VALUES (?, ?)')->execute([Seguranca::ip(), $tipo]);
        $bd->exec('DELETE FROM tentativas_acesso WHERE criado_em < (NOW() - INTERVAL 1 DAY)');
    }

    public static function excedeu(string $tipo): bool
    {
        $s = BaseDados::ligar()->prepare(
            'SELECT COUNT(*) FROM tentativas_acesso WHERE ip = ? AND tipo = ? AND criado_em > (NOW() - INTERVAL ? MINUTE)');
        $s->execute([Seguranca::ip(), $tipo, Configuracao::obter('janela_minutos')]);
        return (int)$s->fetchColumn() >= Configuracao::obter('max_tentativas');
    }
}
