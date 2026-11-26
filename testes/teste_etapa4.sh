#!/usr/bin/env bash
# Testes da etapa 4 (clientes: registar, editar, consultar, pesquisar).
# Uso (a partir da pasta do projeto): bash testes/teste_etapa4.sh http://127.0.0.1:8099
# Requer o comando "mysql" e a base "barbearia" recém-instalada, com o Administrador de teste
# admin@teste.com / senhaforte1 (apenas para ambiente de teste).
B=${1:-http://127.0.0.1:8099}; ok=0; falhas=0
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
API="$B/api/index.php"
MY="mysql --default-character-set=utf8mb4 -N"
$MY -e "DELETE FROM tentativas_acesso" barbearia
csrf(){ curl -s -b "$1" -c "$1" "$API?r=sessao" | sed -n 's/.*"csrf":"\([a-f0-9]*\)".*/\1/p'; }
verifica(){ if [[ "$2" == *"$3"* ]]; then echo "OK    $1"; ok=$((ok+1)); else echo "FALHA $1 (obtido: ${2:0:160})"; falhas=$((falhas+1)); fi; }
post(){ local t; t="$(csrf "$1")"; curl -s -b "$1" -c "$1" -H "Content-Type: application/json" -H "X-CSRF-Token: $t" -d "$3" -w "|%{http_code}" "$API?r=$2"; }
get(){ curl -s -b "$1" -c "$1" -w "|%{http_code}" -G "$API" --data-urlencode "r=$2" "${@:3}"; }
n(){ echo "$1" | grep -o '"id":[0-9]*' | wc -l | tr -d ' '; }
total(){ echo "$1" | sed -n 's/.*"total":\([0-9]*\).*/\1/p'; }
V=$(mktemp); A=$(mktemp); F=$(mktemp); C=$(mktemp)

echo "== Ficheiros e separação"
verifica "Nenhum ficheiro PHP contém HTML" "$(grep -rlE '<(html|head|body|div|form|table|input|p|h1|a)[ >]' --include=*.php "$RAIZ" | wc -l | tr -d ' ')" "0"
for p in admin/clientes.html js/clientes.js; do
  verifica "Ficheiro estático servido: $p" "$(curl -s -o /dev/null -w '%{http_code}' "$B/$p")" "200"
done

echo "== Permissões"
verifica "Lista de clientes sem sessão devolve 401" "$(get $V clientes)" "|401"
post $A entrar '{"area":"admin","email":"admin@teste.com","senha":"senhaforte1"}' >/dev/null
post $A utilizadores '{"nome":"Func Quatro","email":"func4@teste.com","perfil":"funcionario","senha":"barbeiro123","senha2":"barbeiro123"}' >/dev/null
post $F entrar '{"area":"admin","email":"func4@teste.com","senha":"barbeiro123"}' >/dev/null
post $C registar '{"nome":"Cliente Quatro","contacto":"84 100 0004","email":"cli4@teste.com","senha":"12345678","senha2":"12345678"}' >/dev/null
post $C entrar '{"area":"conta","email":"cli4@teste.com","senha":"12345678"}' >/dev/null
verifica "Cliente (com conta) não lista clientes (403)" "$(get $C clientes)" "|403"
verifica "Cliente (com conta) não regista clientes (403)" "$(post $C clientes '{"nome":"Intruso Teste","contacto":"841111111"}')" "|403"
verifica "Cliente (com conta) não edita clientes (403)" "$(post $C clientes_editar '{"id":1,"nome":"Intruso Teste","contacto":"841111111"}')" "|403"
verifica "Funcionário lista clientes" "$(get $F clientes)" "|200"
verifica "Registar sem token CSRF é recusado (403)" "$(curl -s -b $A -c $A -H 'Content-Type: application/json' -d '{"nome":"Sem Token","contacto":"841111111"}' -w '|%{http_code}' "$API?r=clientes")" "|403"

echo "== Registar"
verifica "Administrador regista cliente (201)" "$(post $A clientes '{"nome":"João Pedro Machava","contacto":"84 123 9876"}')" "|201"
verifica "Funcionário regista cliente (201)" "$(post $F clientes '{"nome":"Ana Maria Sitoe","contacto":"+258 82 765 4321"}')" "|201"
verifica "Cliente registado no balcão fica sem conta" "$($MY -e "SELECT utilizador_id IS NULL FROM clientes WHERE nome_completo='Ana Maria Sitoe'" barbearia)" "1"
verifica "Nome curto é recusado" "$(post $A clientes '{"nome":"Jo","contacto":"841234567"}')" "nome completo"
verifica "Nome vazio é recusado" "$(post $A clientes '{"nome":"","contacto":"841234567"}')" "nome completo"
verifica "Contacto inválido é recusado" "$(post $A clientes '{"nome":"Pedro Teste","contacto":"abc"}')" "contacto v"
verifica "Contacto vazio é recusado" "$(post $A clientes '{"nome":"Pedro Teste","contacto":""}')" "contacto v"
verifica "Contacto curto é recusado" "$(post $A clientes '{"nome":"Pedro Teste","contacto":"123"}')" "contacto v"
verifica "Nada foi gravado pelos pedidos inválidos" "$($MY -e "SELECT COUNT(*) FROM clientes WHERE nome_completo IN ('Pedro Teste','Jo','Intruso Teste','Sem Token')" barbearia)" "0"
verifica "Registar por GET na rota de edição é recusado (405)" "$(get $A clientes_editar)" "|405"

echo "== Consultar e pesquisar"
R="$(get $A clientes)"
verifica "Lista devolve total, página e tamanho da página" "$R" '"por_pagina":20'
verifica "Lista inclui ID, nome, contacto e data de registo" "$R" '"data_registo"'
verifica "Lista indica se o cliente tem conta" "$R" '"tem_conta"'
verifica "Lista não expõe o hash da senha nem o email" "$(echo "$R" | grep -c 'senha_hash\|@teste.com')" "0"
verifica "Pesquisa por parte do nome" "$(n "$(get $A clientes --data-urlencode 'q=Machava')")" "1"
verifica "Pesquisa ignora maiúsculas e acentos (joao -> João)" "$(n "$(get $A clientes --data-urlencode 'q=JOAO pedro')")" "1"
verifica "Pesquisa por contacto" "$(n "$(get $A clientes --data-urlencode 'q=765 4321')")" "1"
verifica "Contacto inexistente não devolve resultados" "$(n "$(get $A clientes --data-urlencode 'q=845551234')")" "0"
verifica "Pesquisa por contacto sem espaços encontra número escrito com espaços" "$(n "$(get $A clientes --data-urlencode 'q=841239876')")" "1"
verifica "Pesquisa por contacto com indicativo" "$(n "$(get $A clientes --data-urlencode 'q=+258')")" "1"
verifica "Pesquisa sem resultados devolve lista vazia" "$(total "$(get $A clientes --data-urlencode 'q=zzzzxxxx')")" "0"
verifica "O carácter % é tratado como texto (não como curinga)" "$(total "$(get $A clientes --data-urlencode 'q=%')")" "0"
verifica "O carácter _ é tratado como texto (não como curinga)" "$(total "$(get $A clientes --data-urlencode 'q=_')")" "0"
verifica "Tentativa de injeção SQL na pesquisa é inofensiva" "$(get $A clientes --data-urlencode "q=' OR '1'='1")" "|200"
verifica "Injeção SQL não devolve clientes" "$(total "$(get $A clientes --data-urlencode "q=' OR '1'='1")")" "0"
verifica "A tabela de clientes continua intacta" "$($MY -e "SELECT COUNT(*) > 0 FROM clientes" barbearia)" "1"
verifica "Termo só com espaços devolve todos" "$(( $(total "$(get $A clientes --data-urlencode 'q=   ')") >= 3 ))" "1"

echo "== Paginação"
for i in $(seq 1 25); do post $A clientes "{\"nome\":\"Cliente Paginado $(printf '%02d' $i)\",\"contacto\":\"8400000$(printf '%02d' $i)\"}" >/dev/null; done
P1="$(get $A clientes --data-urlencode 'q=Paginado')"
verifica "Total correto na pesquisa (25)" "$(total "$P1")" "25"
verifica "Página 1 tem 20 clientes" "$(n "$P1")" "20"
P2="$(get $A clientes --data-urlencode 'q=Paginado' --data-urlencode 'pagina=2')"
verifica "Página 2 tem os 5 restantes" "$(n "$P2")" "5"
verifica "Página 2 começa em Paginado 21 (ordem alfabética)" "$(echo "$P2" | grep -o 'Cliente Paginado [0-9]*' | head -1)" "Cliente Paginado 21"
verifica "Página inexistente devolve lista vazia" "$(n "$(get $A clientes --data-urlencode 'q=Paginado' --data-urlencode 'pagina=9')")" "0"
verifica "Página inválida (0) é tratada como página 1" "$(n "$(get $A clientes --data-urlencode 'q=Paginado' --data-urlencode 'pagina=0')")" "20"
verifica "Página negativa é tratada como página 1" "$(n "$(get $A clientes --data-urlencode 'q=Paginado' --data-urlencode 'pagina=-3')")" "20"
verifica "Página não numérica é tratada como página 1" "$(n "$(get $A clientes --data-urlencode 'q=Paginado' --data-urlencode 'pagina=abc')")" "20"

echo "== Editar"
ID=$($MY -e "SELECT id FROM clientes WHERE nome_completo='Ana Maria Sitoe'" barbearia)
verifica "Funcionário edita nome e contacto" "$(post $F clientes_editar "{\"id\":$ID,\"nome\":\"Ana Maria Sitoe Cossa\",\"contacto\":\"82 000 1111\"}")" "|200"
verifica "Alteração gravada na base de dados" "$($MY -e "SELECT CONCAT(nome_completo,'|',contacto) FROM clientes WHERE id=$ID" barbearia)" "Ana Maria Sitoe Cossa|82 000 1111"
verifica "Edição com nome inválido é recusada" "$(post $A clientes_editar "{\"id\":$ID,\"nome\":\"X\",\"contacto\":\"82 000 1111\"}")" "nome completo"
verifica "Edição com contacto inválido é recusada" "$(post $A clientes_editar "{\"id\":$ID,\"nome\":\"Ana Maria Sitoe Cossa\",\"contacto\":\"xx\"}")" "contacto v"
verifica "Dados não mudaram após edições recusadas" "$($MY -e "SELECT contacto FROM clientes WHERE id=$ID" barbearia)" "82 000 1111"
verifica "Editar cliente inexistente devolve 404" "$(post $A clientes_editar '{"id":99999,"nome":"Nao Existe","contacto":"841234567"}')" "|404"
verifica "Editar sem id devolve 404" "$(post $A clientes_editar '{"nome":"Sem Id Teste","contacto":"841234567"}')" "|404"
CID=$($MY -e "SELECT c.id FROM clientes c JOIN utilizadores u ON u.id=c.utilizador_id WHERE u.email='cli4@teste.com'" barbearia)
verifica "Administrador edita um cliente que tem conta" "$(post $A clientes_editar "{\"id\":$CID,\"nome\":\"Cliente Quatro Silva\",\"contacto\":\"84 100 0004\"}")" "|200"
verifica "O nome da conta acompanha o nome do cliente" "$($MY -e "SELECT nome FROM utilizadores WHERE email='cli4@teste.com'" barbearia)" "Cliente Quatro Silva"
verifica "A conta continua a ter perfil cliente" "$($MY -e "SELECT perfil FROM utilizadores WHERE email='cli4@teste.com'" barbearia)" "cliente"
verifica "Edição não altera a ligação entre conta e cliente" "$($MY -e "SELECT COUNT(*) FROM clientes c JOIN utilizadores u ON u.id=c.utilizador_id WHERE u.email='cli4@teste.com'" barbearia)" "1"
verifica "Cliente editado aparece na pesquisa pelo nome novo" "$(n "$(get $A clientes --data-urlencode 'q=Quatro Silva')")" "1"

echo "== Texto malicioso fica como texto"
post $A clientes '{"nome":"<script>alert(1)</script> Teste","contacto":"841234567"}' >/dev/null
verifica "Nome com marcas HTML é gravado como texto simples" "$($MY -e "SELECT COUNT(*) FROM clientes WHERE nome_completo='<script>alert(1)</script> Teste'" barbearia)" "1"
verifica "O JavaScript nunca usa innerHTML" "$(grep -c 'innerHTML' "$RAIZ"/publico/js/*.js | grep -v ':0' | wc -l | tr -d ' ')" "0"

echo; echo "Resultado: $ok passaram, $falhas falharam"; [ $falhas -eq 0 ]
