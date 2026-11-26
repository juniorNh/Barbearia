<?php
declare(strict_types=1);
// Script de instalação (só linha de comandos): cria a base de dados e o primeiro Administrador.
// Uso (XAMPP): C:\xampp\php\php.exe sql\instalar.php
if (PHP_SAPI !== 'cli') { http_response_code(403); exit('Execute este script na linha de comandos.'); }

require __DIR__ . '/../nucleo/Configuracao.php';
$c = Configuracao::obter('bd');
$pdo = new PDO("mysql:host={$c['servidor']};charset=utf8mb4", $c['utilizador'], $c['senha'],
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
$pdo->exec(file_get_contents(__DIR__ . '/esquema.sql'));
echo "Base de dados criada.\n";

$pdo->exec("USE `{$c['nome']}`");
// Serviços de exemplo (preços do enunciado), só se a tabela estiver vazia. O Administrador pode alterá-los.
if (!$pdo->query('SELECT 1 FROM servicos LIMIT 1')->fetch()) {
    $pdo->exec("INSERT INTO servicos (nome, descricao, preco) VALUES
        ('Corte normal',   'Corte clássico com acabamento limpo', 200.00),
        ('Degradê (Fade)', 'Degradê de precisão',                 250.00),
        ('Barba',          'Desenho e alinhamento da barba',      150.00),
        ('Corte + Barba',  'Corte e barba no mesmo atendimento',  350.00),
        ('Lavagem',        'Lavagem do cabelo',                   100.00)");
    echo "Serviços de exemplo criados.\n";
}
if ($pdo->query("SELECT 1 FROM utilizadores WHERE perfil='administrador' LIMIT 1")->fetch()) {
    exit("Já existe um Administrador. Nada a fazer.\n");
}
function perguntar(string $texto, bool $oculto = false): string {
    echo $texto;
    if ($oculto && DIRECTORY_SEPARATOR === '/') system('stty -echo');
    $v = trim((string)fgets(STDIN));
    if ($oculto && DIRECTORY_SEPARATOR === '/') { system('stty echo'); echo "\n"; }
    return $v;
}
$nome  = perguntar('Nome do Administrador: ');
$email = mb_strtolower(perguntar('Email: '));
$senha = perguntar('Senha (mínimo 8 caracteres): ', true);
if (mb_strlen($nome) < 3 || !filter_var($email, FILTER_VALIDATE_EMAIL) || mb_strlen($senha) < 8) {
    exit("Dados inválidos. Execute novamente.\n");
}
$pdo->prepare("INSERT INTO utilizadores (nome, email, senha_hash, perfil) VALUES (?, ?, ?, 'administrador')")
    ->execute([$nome, $email, password_hash($senha, PASSWORD_DEFAULT)]);
echo "Administrador criado. Pode entrar em publico/admin/entrar.html\n";
