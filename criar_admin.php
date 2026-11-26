<?php
declare(strict_types=1);

// Só pode ser executado na linha de comandos.
if (PHP_SAPI !== 'cli') {
    http_response_code(403);
    exit('Execute este script na linha de comandos.');
}

require __DIR__ . '/nucleo/arranque.php';

try {
    // Verifica se já existe um administrador
    if (Utilizador::existeAdministrador()) {
        exit("Já existe um administrador registado.\n");
    }

    // Solicita os dados
    echo "Nome do administrador: ";
    $nome = trim(fgets(STDIN));

    echo "Email: ";
    $email = mb_strtolower(trim(fgets(STDIN)));

    echo "Senha: ";
    $senha = trim(fgets(STDIN));

    // Verifica os dados
    if ($nome === '' || !filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($senha) < 8) {
        exit("Dados inválidos. Verifique o nome, email e senha (mínimo 8 caracteres).\n");
    }

    // Cria a conta
    $id = Utilizador::criar(
        $nome,
        $email,
        $senha,
        'administrador'
    );

    echo "Administrador criado com sucesso! ID: $id\n";

} catch (Throwable $e) {
    echo "Erro: " . $e->getMessage() . "\n";
}
