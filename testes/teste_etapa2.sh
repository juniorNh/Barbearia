#!/usr/bin/env bash
# Testes de fumo da etapa 2 (API, perfis, segurança e separação das tecnologias).
# Uso (a partir da pasta do projeto): bash testes/teste_etapa2.sh http://127.0.0.1:8099
# Requer o comando "mysql" e a base "barbearia" instalada com o Administrador de teste
# admin@teste.com / senhaforte1 (apenas para ambiente de teste).
B=${1:-http://127.0.0.1:8099}; ok=0; falhas=0
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
API="$B/api/index.php"
csrf(){ curl -s -b "$1" -c "$1" "$API?r=sessao" | sed -n 's/.*"csrf":"\([a-f0-9]*\)".*/\1/p'; }
verifica(){ if [[ "$2" == *"$3"* ]]; then echo "OK    $1"; ok=$((ok+1)); else echo "FALHA $1 (obtido: ${2:0:140})"; falhas=$((falhas+1)); fi; }
# post <jar> <rota> <json>  -> corpo|codigo
post(){ local t; t="$(csrf "$1")"; curl -s -b "$1" -c "$1" -H "Content-Type: application/json" -H "X-CSRF-Token: $t" -d "$3" -w "|%{http_code}" "$API?r=$2"; }
get(){ curl -s -b "$1" -c "$1" -w "|%{http_code}" "$API?r=$2"; }
idde(){ mysql -N -e "SELECT id FROM utilizadores WHERE email='$1'" barbearia; }
J=$(mktemp); A=$(mktemp); X=$(mktemp); F=$(mktemp); R=$(mktemp)

echo "== Separação das tecnologias"
verifica "Nenhum ficheiro PHP contém HTML" "$(grep -rlE '<(html|head|body|div|form|table|input|p|h1|a)[ >]' --include=*.php "$RAIZ" | wc -l | tr -d ' ')" "0"
verifica "Nenhuma página HTML contém PHP" "$(grep -rl '<?php' --include=*.html "$RAIZ/publico" | wc -l | tr -d ' ')" "0"
for p in index.html conta/entrar.html conta/registar.html conta/inicio.html admin/entrar.html admin/painel.html admin/utilizadores.html css/estilo.css js/api.js js/interface.js; do
  verifica "Ficheiro estático servido: $p" "$(curl -s -o /dev/null -w '%{http_code}' "$B/$p")" "200"
done

echo "== API e segurança"
verifica "API sem sessão devolve utilizador nulo" "$(get $J sessao)" '"utilizador":null'
verifica "Rota inexistente devolve 404" "$(get $J xyz)" "|404"
verifica "Lista de utilizadores sem sessão devolve 401" "$(get $J utilizadores)" "|401"
verifica "Registo sem token CSRF é recusado (403)" "$(curl -s -b $J -c $J -H 'Content-Type: application/json' -d '{}' -w '|%{http_code}' "$API?r=registar")" "|403"
verifica "Registo com formato não JSON é recusado (415)" "$(curl -s -b $J -c $J -d 'a=b' -w '|%{http_code}' "$API?r=registar")" "|415"
verifica "Registo por GET é recusado (405)" "$(get $J registar)" "|405"
verifica "Senha curta é recusada" "$(post $J registar '{"nome":"Joao Silva","contacto":"841234567","email":"joao@x.com","senha":"123","senha2":"123"}')" "pelo menos 8"
verifica "Senhas diferentes são recusadas" "$(post $J registar '{"nome":"Joao Silva","contacto":"841234567","email":"joao@x.com","senha":"12345678","senha2":"87654321"}')" "coincidem"
verifica "Contacto inválido é recusado" "$(post $J registar '{"nome":"Joao Silva","contacto":"abc","email":"joao@x.com","senha":"12345678","senha2":"12345678"}')" "contacto v"
verifica "Registo válido devolve 201" "$(post $J registar '{"nome":"Joao Silva","contacto":"841234567","email":"joao@x.com","senha":"12345678","senha2":"12345678"}')" "|201"
verifica "Email repetido (maiúsculas) é recusado (409)" "$(post $J registar '{"nome":"Outro Nome","contacto":"841234567","email":"JOAO@x.com","senha":"12345678","senha2":"12345678"}')" "|409"
post $J registar '{"nome":"Hacker Teste","contacto":"841111111","email":"h@x.com","senha":"12345678","senha2":"12345678","perfil":"administrador"}' >/dev/null
verifica "Perfil enviado no registo é ignorado (fica cliente)" "$(mysql -N -e "SELECT perfil FROM utilizadores WHERE email='h@x.com'" barbearia)" "cliente"
verifica "Registo cria o cliente ligado à conta" "$(mysql -N -e "SELECT COUNT(*) FROM clientes c JOIN utilizadores u ON u.id=c.utilizador_id WHERE u.email='joao@x.com'" barbearia)" "1"
verifica "Senha guardada com hash" "$(mysql -N -e "SELECT LEFT(senha_hash,4) FROM utilizadores WHERE email='joao@x.com'" barbearia)" '$2y$'

echo "== Cliente"
verifica "Cliente entra com credenciais certas" "$(post $J entrar '{"area":"conta","email":"joao@x.com","senha":"12345678"}')" '"perfil":"cliente"'
verifica "Sessão mostra o cliente" "$(get $J sessao)" '"nome":"Joao Silva"'
verifica "Cliente não lista utilizadores (403)" "$(get $J utilizadores)" "|403"
verifica "Cliente não cria utilizadores (403)" "$(post $J utilizadores '{"nome":"Falso Admin","email":"fa@x.com","perfil":"administrador","senha":"12345678","senha2":"12345678"}')" "|403"
verifica "Cliente não entra pelo login do pessoal" "$(post $X entrar '{"area":"admin","email":"joao@x.com","senha":"12345678"}')" "|401"

echo "== Administrador e Funcionário"
verifica "Administrador entra" "$(post $A entrar '{"area":"admin","email":"admin@teste.com","senha":"senhaforte1"}')" '"perfil":"administrador"'
verifica "Administrador lista utilizadores" "$(get $A utilizadores)" "admin@teste.com"
verifica "Clientes não aparecem na lista do pessoal" "$(get $A utilizadores | grep -c 'joao@x.com')" "0"
verifica "Administrador cria um funcionário" "$(post $A utilizadores '{"nome":"Carlos Barbeiro","email":"carlos@teste.com","perfil":"funcionario","senha":"barbeiro123","senha2":"barbeiro123"}')" "|201"
verifica "Perfil cliente não pode ser criado pelo pessoal" "$(post $A utilizadores '{"nome":"Falso Cliente","email":"f@teste.com","perfil":"cliente","senha":"barbeiro123","senha2":"barbeiro123"}')" "Perfil inv"
verifica "Administrador não se desativa a si próprio" "$(post $A utilizadores_alternar "{\"id\":$(idde admin@teste.com)}")" "desativar a sua"
verifica "Funcionário entra" "$(post $F entrar '{"area":"admin","email":"carlos@teste.com","senha":"barbeiro123"}')" '"perfil":"funcionario"'
verifica "Funcionário não lista utilizadores (403)" "$(get $F utilizadores)" "|403"
post $A utilizadores_alternar "{\"id\":$(idde carlos@teste.com)}" >/dev/null
verifica "Conta desativada perde o acesso com a sessão aberta (401)" "$(get $F utilizadores)" "|401"
verifica "Conta desativada não consegue entrar" "$(post $R entrar '{"area":"admin","email":"carlos@teste.com","senha":"barbeiro123"}')" "|401"

echo "== Saída e limites"
verifica "Saída sem token CSRF é recusada" "$(curl -s -b $J -c $J -H 'Content-Type: application/json' -d '{}' -w '|%{http_code}' "$API?r=sair")" "|403"
verifica "Sessão continua ativa após saída recusada" "$(get $J sessao)" '"perfil":"cliente"'
verifica "Saída com token termina a sessão" "$(post $J sair '{}')" "|200"
verifica "Depois de sair, a sessão fica vazia" "$(get $J sessao)" '"utilizador":null'
for i in 1 2 3 4 5; do post $R entrar '{"area":"conta","email":"joao@x.com","senha":"errada123"}' >/dev/null; done
verifica "Bloqueio após 5 tentativas falhadas (429)" "$(post $R entrar '{"area":"conta","email":"joao@x.com","senha":"12345678"}')" "|429"
verifica "Pastas internas protegidas por .htaccess" "$(cat "$RAIZ/config/.htaccess" 2>/dev/null)" "Require all denied"

verifica "Cookie de sessão é HttpOnly, SameSite e tem validade" "$(curl -si "$API?r=sessao" | grep -i '^set-cookie' | grep -ci 'httponly.*samesite=lax\|samesite=lax.*httponly')" "1"
verifica "Cookie de sessão tem data de validade" "$(curl -si "$API?r=sessao" | grep -i '^set-cookie' | grep -ci 'expires=')" "1"
echo; echo "Resultado: $ok passaram, $falhas falharam"; [ $falhas -eq 0 ]
