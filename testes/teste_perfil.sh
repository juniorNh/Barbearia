#!/usr/bin/env bash
# Testes do perfil do utilizador (ver e editar os próprios dados).
# Uso (a partir da pasta do projeto): bash testes/teste_perfil.sh http://127.0.0.1:8099
# Requer o comando "mysql", python3 e a base "barbearia" recém-instalada, com o Administrador de teste
# admin@teste.com / senhaforte1 (apenas para ambiente de teste).
B=${1:-http://127.0.0.1:8099}; ok=0; falhas=0
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
API="$B/api/index.php"
MY="mysql --default-character-set=utf8mb4 -N"
$MY -e "DELETE FROM tentativas_acesso" barbearia
csrf(){ curl -s -b "$1" -c "$1" "$API?r=sessao" | sed -n 's/.*"csrf":"\([a-f0-9]*\)".*/\1/p'; }
verifica(){ if [[ "$2" == *"$3"* ]]; then echo "OK    $1"; ok=$((ok+1)); else echo "FALHA $1 (obtido: ${2:0:200})"; falhas=$((falhas+1)); fi; }
post(){ local t; t="$(csrf "$1")"; curl -s -b "$1" -c "$1" -H "Content-Type: application/json" -H "X-CSRF-Token: $t" -d "$3" -w "|%{http_code}" "$API?r=$2"; }
get(){ curl -s -b "$1" -c "$1" -w "|%{http_code}" -G "$API" --data-urlencode "r=$2" "${@:3}"; }
J(){ python3 -c 'import sys,json;d=json.loads(sys.stdin.read().rsplit("|",1)[0]);print(eval(sys.argv[1]))' "$1"; }
sql(){ $MY -e "$1" barbearia; }
A=$(mktemp); F=$(mktemp); C1=$(mktemp); C2=$(mktemp); V=$(mktemp); N=$(mktemp)

echo "== Preparação"
post $A entrar '{"area":"admin","email":"admin@teste.com","senha":"senhaforte1"}' >/dev/null
post $A utilizadores '{"nome":"Barbeiro Perfil","email":"perfilf@teste.com","perfil":"funcionario","senha":"barbeiro123","senha2":"barbeiro123"}' >/dev/null
post $F entrar '{"area":"admin","email":"perfilf@teste.com","senha":"barbeiro123"}' >/dev/null
for i in 1 2; do
  jar=$( [ $i = 1 ] && echo $C1 || echo $C2 )
  post $jar registar "{\"nome\":\"Cliente Perfil $i\",\"contacto\":\"8480000$i\",\"email\":\"perfil$i@teste.com\",\"senha\":\"12345678\",\"senha2\":\"12345678\"}" >/dev/null
  post $jar entrar "{\"area\":\"conta\",\"email\":\"perfil$i@teste.com\",\"senha\":\"12345678\"}" >/dev/null
done
IDC1=$(sql "SELECT id FROM utilizadores WHERE email='perfil1@teste.com'")
IDADM=$(sql "SELECT id FROM utilizadores WHERE email='admin@teste.com'")
IDF=$(sql "SELECT id FROM utilizadores WHERE email='perfilf@teste.com'")

echo "== Ficheiros e separação"
verifica "Nenhum ficheiro PHP contém HTML" "$(grep -rlE '<(html|head|body|div|form|table|input|p|h1|a)[ >]' --include=*.php "$RAIZ" | wc -l | tr -d ' ')" "0"
for p in conta/perfil.html js/perfil.js css/perfil.css; do verifica "Ficheiro estático servido: $p" "$(curl -s -o /dev/null -w '%{http_code}' "$B/$p")" "200"; done
verifica "O JavaScript nunca usa innerHTML" "$(grep -c 'innerHTML' "$RAIZ"/publico/js/*.js | grep -v ':0' | wc -l | tr -d ' ')" "0"
verifica "O script criar_admin.php recusa-se a criar um segundo Administrador" "$(php "$RAIZ/criar_admin.php" </dev/null 2>&1)" "Já existe um administrador"

echo "== Acesso"
verifica "Sem sessão, ver o perfil devolve 401" "$(get $V perfil)" "|401"
verifica "Sem sessão, editar o perfil devolve 401" "$(curl -s -H 'Content-Type: application/json' -d '{}' -w '|%{http_code}' "$API?r=perfil")" "|401"
verifica "Editar sem token CSRF é recusado (403)" "$(curl -s -b $C1 -c $C1 -H 'Content-Type: application/json' -d '{"nome":"Sem Token","email":"semtoken@teste.com","contacto":"841111111"}' -w '|%{http_code}' "$API?r=perfil")" "|403"

echo "== Ver o perfil"
P1="$(get $C1 perfil)"
verifica "O cliente vê os seus dados" "$(echo "$P1" | J "d['perfil']['nome']+'|'+d['perfil']['email']+'|'+d['perfil']['perfil']+'|'+d['perfil']['contacto']")" "Cliente Perfil 1|perfil1@teste.com|cliente|84800001"
verifica "O cliente vê o seu próprio número de conta" "$(echo "$P1" | J "d['perfil']['id']")" "$IDC1"
verifica "O perfil não expõe a senha" "$(echo "$P1" | grep -ci 'senha')" "0"
verifica "O cliente 2 vê os dele, não os do cliente 1" "$(get $C2 perfil | J "d['perfil']['email']")" "perfil2@teste.com"
verifica "O Funcionário vê o seu perfil, sem contacto" "$(get $F perfil | J "d['perfil']['perfil']+'|'+str(d['perfil']['contacto'])")" "funcionario|None"
verifica "O Administrador vê o seu perfil" "$(get $A perfil | J "d['perfil']['perfil']")" "administrador"
verifica "O pedido não aceita escolher outra conta" "$(get $C1 perfil --data-urlencode "id=$IDADM" | J "d['perfil']['email']")" "perfil1@teste.com"

echo "== Editar (cliente)"
HASH0=$(sql "SELECT senha_hash FROM utilizadores WHERE id=$IDC1")
verifica "Nome curto é recusado" "$(post $C1 perfil '{"nome":"Jo","email":"perfil1@teste.com","contacto":"84800001"}')" "nome completo"
verifica "Email inválido é recusado" "$(post $C1 perfil '{"nome":"Cliente Perfil 1","email":"abc","contacto":"84800001"}')" "email válido"
verifica "Contacto inválido é recusado" "$(post $C1 perfil '{"nome":"Cliente Perfil 1","email":"perfil1@teste.com","contacto":"xx"}')" "contacto válido"
verifica "Contacto vazio é recusado para clientes" "$(post $C1 perfil '{"nome":"Cliente Perfil 1","email":"perfil1@teste.com","contacto":""}')" "contacto válido"
verifica "Nada mudou depois dos pedidos inválidos" "$(sql "SELECT CONCAT(nome,'|',email) FROM utilizadores WHERE id=$IDC1")" "Cliente Perfil 1|perfil1@teste.com"
verifica "Email de outra conta é recusado (409)" "$(post $C1 perfil '{"nome":"Cliente Perfil 1","email":"perfil2@teste.com","contacto":"84800001"}')" "|409"
verifica "Email de outra conta, com maiúsculas, também (409)" "$(post $C1 perfil '{"nome":"Cliente Perfil 1","email":"PERFIL2@Teste.com","contacto":"84800001"}')" "|409"
verifica "Email do Administrador também é recusado (409)" "$(post $C1 perfil '{"nome":"Cliente Perfil 1","email":"admin@teste.com","contacto":"84800001"}')" "|409"
verifica "Manter o próprio email é permitido" "$(post $C1 perfil '{"nome":"Cliente Perfil 1","email":"perfil1@teste.com","contacto":"84800001"}')" "|200"
verifica "O cliente atualiza nome, email e contacto" "$(post $C1 perfil '{"nome":"  Cliente Perfil Novo  ","email":" Novo.Perfil@Teste.com ","contacto":"84 555 0000","perfil":"administrador","id":1,"ativo":0}')" "|200"
verifica "A resposta traz o perfil atualizado" "$(get $C1 perfil | J "d['perfil']['nome']+'|'+d['perfil']['email']+'|'+d['perfil']['contacto']")" "Cliente Perfil Novo|novo.perfil@teste.com|84 555 0000"
verifica "O nome na conta foi atualizado" "$(sql "SELECT nome FROM utilizadores WHERE id=$IDC1")" "Cliente Perfil Novo"
verifica "O registo de cliente acompanha (nome e contacto)" "$(sql "SELECT CONCAT(nome_completo,'|',contacto) FROM clientes WHERE utilizador_id=$IDC1")" "Cliente Perfil Novo|84 555 0000"
verifica "O pessoal vê o nome novo na lista de clientes" "$(get $A clientes --data-urlencode 'q=Perfil Novo' | J "d['clientes'][0]['nome_completo']")" "Cliente Perfil Novo"
verifica "O tipo de conta não muda (continua cliente)" "$(sql "SELECT perfil FROM utilizadores WHERE id=$IDC1")" "cliente"
verifica "A conta continua ativa" "$(sql "SELECT ativo FROM utilizadores WHERE id=$IDC1")" "1"
verifica "Os dados de outra conta (o Administrador) não mudaram" "$(sql "SELECT CONCAT(nome,'|',email) FROM utilizadores WHERE id=$IDADM")" "Admin Teste|admin@teste.com"
verifica "A senha não foi tocada" "$(sql "SELECT senha_hash FROM utilizadores WHERE id=$IDC1")" "$HASH0"
verifica "A sessão mostra o nome novo" "$(get $C1 sessao | J "d['utilizador']['nome']")" "Cliente Perfil Novo"
verifica "Entra com o email novo" "$(post $N entrar '{"area":"conta","email":"novo.perfil@teste.com","senha":"12345678"}')" '"perfil":"cliente"'
verifica "O email antigo já não entra" "$(post $V entrar '{"area":"conta","email":"perfil1@teste.com","senha":"12345678"}')" "|401"
post $C1 perfil '{"nome":"<script>alert(1)</script> Silva","email":"novo.perfil@teste.com","contacto":"84 555 0000"}' >/dev/null
verifica "Texto com marcas HTML é gravado como texto simples" "$(sql "SELECT COUNT(*) FROM utilizadores WHERE nome='<script>alert(1)</script> Silva'")" "1"

echo "== Editar (pessoal)"
NCLI=$(sql "SELECT COUNT(*) FROM clientes")
verifica "O Funcionário atualiza nome e email (200)" "$(post $F perfil '{"nome":"Barbeiro Perfil Dois","email":"perfilf2@teste.com","contacto":"xx"}')" "|200"
verifica "Os dados do Funcionário ficaram gravados" "$(sql "SELECT CONCAT(nome,'|',email,'|',perfil) FROM utilizadores WHERE id=$IDF")" "Barbeiro Perfil Dois|perfilf2@teste.com|funcionario"
verifica "O contacto não é exigido nem gravado para o pessoal" "$(sql "SELECT COUNT(*) FROM clientes")" "$NCLI"
verifica "O Funcionário não consegue passar a Administrador" "$(post $F perfil '{"nome":"Barbeiro Perfil Dois","email":"perfilf2@teste.com","perfil":"administrador"}')" "|200"
verifica "O tipo de conta do Funcionário continua o mesmo" "$(sql "SELECT perfil FROM utilizadores WHERE id=$IDF")" "funcionario"
verifica "O Administrador atualiza o seu nome (200)" "$(post $A perfil '{"nome":"Administrador Geral","email":"admin@teste.com"}')" "|200"
verifica "A sessão do Administrador mostra o nome novo" "$(get $A sessao | J "d['utilizador']['nome']")" "Administrador Geral"
verifica "O Funcionário também não pode usar o email de um cliente (409)" "$(post $F perfil '{"nome":"Barbeiro Perfil Dois","email":"perfil2@teste.com"}')" "|409"
verifica "O Funcionário entra com o email novo" "$(post $V entrar '{"area":"admin","email":"perfilf2@teste.com","senha":"barbeiro123"}')" '"perfil":"funcionario"'

echo; echo "Resultado: $ok passaram, $falhas falharam"; [ $falhas -eq 0 ]
