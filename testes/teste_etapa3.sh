#!/usr/bin/env bash
# Testes da etapa 3 (serviços e preços).
# Uso (a partir da pasta do projeto): bash testes/teste_etapa3.sh http://127.0.0.1:8099
# Requer o comando "mysql" e a base "barbearia" recém-instalada (com os serviços de exemplo)
# e o Administrador de teste admin@teste.com / senhaforte1 (apenas para ambiente de teste).
B=${1:-http://127.0.0.1:8099}; ok=0; falhas=0
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
API="$B/api/index.php"
mysql -e "DELETE FROM tentativas_acesso" barbearia
csrf(){ curl -s -b "$1" -c "$1" "$API?r=sessao" | sed -n 's/.*"csrf":"\([a-f0-9]*\)".*/\1/p'; }
verifica(){ if [[ "$2" == *"$3"* ]]; then echo "OK    $1"; ok=$((ok+1)); else echo "FALHA $1 (obtido: ${2:0:160})"; falhas=$((falhas+1)); fi; }
post(){ local t; t="$(csrf "$1")"; curl -s -b "$1" -c "$1" -H "Content-Type: application/json" -H "X-CSRF-Token: $t" -d "$3" -w "|%{http_code}" "$API?r=$2"; }
get(){ curl -s -b "$1" -c "$1" -w "|%{http_code}" "$API?r=$2"; }
preco(){ mysql --default-character-set=utf8mb4 -N -e "SELECT preco FROM servicos WHERE nome='$1'" barbearia; }
idsrv(){ mysql --default-character-set=utf8mb4 -N -e "SELECT id FROM servicos WHERE nome='$1'" barbearia; }
sql(){ mysql --default-character-set=utf8mb4 -N -e "$1" barbearia; }
J(){ python3 -c 'import sys,json;d=json.loads(sys.stdin.read().rsplit("|",1)[0]);print(eval(sys.argv[1]))' "$1"; }
V=$(mktemp); A=$(mktemp); F=$(mktemp); C=$(mktemp)

echo "== Separação das tecnologias e ficheiros"
verifica "Nenhum ficheiro PHP contém HTML" "$(grep -rlE '<(html|head|body|div|form|table|input|p|h1|a)[ >]' --include=*.php "$RAIZ" | wc -l | tr -d ' ')" "0"
verifica "Nenhuma página HTML contém PHP" "$(grep -rl '<?php' --include=*.html "$RAIZ/publico" | wc -l | tr -d ' ')" "0"
for p in admin/servicos.html js/servicos.js js/inicio.js; do
  verifica "Ficheiro estático servido: $p" "$(curl -s -o /dev/null -w '%{http_code}' "$B/$p")" "200"
done

echo "== Lista pública (sem login)"
PUB="$(get $V servicos_publicos)"
verifica "Lista pública responde 200" "$PUB" "|200"
for par in "Corte normal:200.00" "Degradê (Fade):250.00" "Barba:150.00" "Corte + Barba:350.00" "Lavagem:100.00"; do
  verifica "Serviço de exemplo ${par%%:*} com preço ${par##*:}" "$(echo "$PUB" | grep -o "\"nome\":\"[^\"]*${par%%:*}[^\"]*\",\"descricao\":\"[^\"]*\",\"preco\":\"${par##*:}\"" | wc -l | tr -d ' ')" "1"
done
verifica "Lista pública não expõe o campo ativo" "$(echo "$PUB" | grep -c '"ativo"')" "0"

echo "== Permissões"
verifica "Gestão sem sessão devolve 401" "$(get $V servicos)" "|401"
post $A entrar '{"area":"admin","email":"admin@teste.com","senha":"senhaforte1"}' >/dev/null
post $A utilizadores '{"nome":"Func Tres","email":"func3@teste.com","perfil":"funcionario","senha":"barbeiro123","senha2":"barbeiro123"}' >/dev/null
post $F entrar '{"area":"admin","email":"func3@teste.com","senha":"barbeiro123"}' >/dev/null
post $C registar '{"nome":"Cliente Tres","contacto":"841000003","email":"cli3@teste.com","senha":"12345678","senha2":"12345678"}' >/dev/null
post $C entrar '{"area":"conta","email":"cli3@teste.com","senha":"12345678"}' >/dev/null
verifica "Funcionário não vê a gestão (403)" "$(get $F servicos)" "|403"
verifica "Cliente não vê a gestão (403)" "$(get $C servicos)" "|403"
verifica "Cliente não cria serviços (403)" "$(post $C servicos '{"nome":"Hack","preco":"1"}')" "|403"
verifica "Funcionário não altera preços (403)" "$(post $F servicos_editar "{\"id\":$(idsrv Barba),\"nome\":\"Barba\",\"preco\":\"1\"}")" "|403"
verifica "Funcionário não desativa serviços (403)" "$(post $F servicos_alternar "{\"id\":$(idsrv Barba)}")" "|403"
verifica "Preço da Barba continua 150.00" "$(preco Barba)" "150.00"
verifica "Criar sem token CSRF é recusado (403)" "$(curl -s -b $A -c $A -H 'Content-Type: application/json' -d '{"nome":"Sem Token","preco":"10"}' -w '|%{http_code}' "$API?r=servicos")" "|403"

echo "== Administrador: cadastrar"
verifica "Administrador vê todos os serviços" "$(get $A servicos)" "Corte normal"
verifica "Cria serviço com preço inteiro (201)" "$(post $A servicos '{"duracao_minutos":30,"nome":"Pigmentação","descricao":"Cobertura de falhas","preco":"500"}')" "|201"
verifica "Preço inteiro fica com 2 casas" "$(preco Pigmentação)" "500.00"
verifica "Cria serviço com vírgula decimal" "$(post $A servicos '{"duracao_minutos":30,"nome":"Sobrancelha","descricao":"","preco":"75,5"}')" "|201"
verifica "Vírgula convertida corretamente" "$(preco Sobrancelha)" "75.50"
verifica "Aceita preço enviado como número" "$(post $A servicos '{"duracao_minutos":30,"nome":"Massagem","preco":120}')" "|201"
verifica "Nome repetido é recusado (409)" "$(post $A servicos '{"duracao_minutos":30,"nome":"Barba","preco":"99"}')" "|409"
verifica "Nome repetido com outras maiúsculas é recusado" "$(post $A servicos '{"duracao_minutos":30,"nome":"BARBA","preco":"99"}')" "|409"
verifica "Preço zero é recusado" "$(post $A servicos '{"duracao_minutos":30,"nome":"Zero","preco":"0"}')" "preço válido"
verifica "Preço negativo é recusado" "$(post $A servicos '{"duracao_minutos":30,"nome":"Negativo","preco":"-5"}')" "preço válido"
verifica "Preço com letras é recusado" "$(post $A servicos '{"duracao_minutos":30,"nome":"Letras","preco":"abc"}')" "preço válido"
verifica "Preço com 3 casas decimais é recusado" "$(post $A servicos '{"duracao_minutos":30,"nome":"Casas","preco":"10,999"}')" "preço válido"
verifica "Preço vazio é recusado" "$(post $A servicos '{"duracao_minutos":30,"nome":"Vazio","preco":""}')" "preço válido"
verifica "Nome vazio é recusado" "$(post $A servicos '{"duracao_minutos":30,"nome":"","preco":"10"}')" "nome do serviço"
verifica "Descrição longa demais é recusada" "$(post $A servicos "{\"duracao_minutos\":30,\"nome\":\"Longa\",\"preco\":\"10\",\"descricao\":\"$(printf 'a%.0s' $(seq 1 300))\"}")" "255"
verifica "Nada foi gravado pelos pedidos inválidos" "$(mysql -N -e "SELECT COUNT(*) FROM servicos WHERE nome IN ('Zero','Negativo','Letras','Casas','Vazio','Longa','Hack','Sem Token')" barbearia)" "0"

echo "== Duração dos serviços"
verifica "Sem duração é recusado" "$(post $A servicos '{"nome":"Sem Duracao","preco":"10"}')" "duração"
verifica "Duração abaixo de 5 minutos é recusada" "$(post $A servicos '{"nome":"Curto","preco":"10","duracao_minutos":4}')" "entre 5 e 240"
verifica "Duração acima de 240 minutos é recusada" "$(post $A servicos '{"nome":"Longo","preco":"10","duracao_minutos":241}')" "entre 5 e 240"
verifica "Duração com letras é recusada" "$(post $A servicos '{"nome":"Letras Dur","preco":"10","duracao_minutos":"abc"}')" "entre 5 e 240"
verifica "Duração com casas decimais é recusada" "$(post $A servicos '{"nome":"Decimal Dur","preco":"10","duracao_minutos":30.5}')" "entre 5 e 240"
verifica "Nada foi gravado pelos pedidos inválidos" "$(sql "SELECT COUNT(*) FROM servicos WHERE nome IN ('Sem Duracao','Curto','Longo','Letras Dur','Decimal Dur')")" "0"
verifica "Duração enviada como texto numérico é aceite (201)" "$(post $A servicos '{"nome":"Dur Texto","preco":"10","duracao_minutos":"45"}')" "|201"
verifica "A duração fica gravada (45)" "$(sql "SELECT duracao_minutos FROM servicos WHERE nome='Dur Texto'")" "45"
verifica "A lista pública mostra a duração" "$(get $V servicos_publicos | J "[s['duracao_minutos'] for s in d['servicos'] if s['nome']=='Dur Texto'][0]")" "45"
verifica "A lista de gestão mostra a duração" "$(get $A servicos | J "[s['duracao_minutos'] for s in d['servicos'] if s['nome']=='Dur Texto'][0]")" "45"
verifica "Editar sem duração é recusado" "$(post $A servicos_editar "{\"id\":$(idsrv 'Dur Texto'),\"nome\":\"Dur Texto\",\"preco\":\"10\"}")" "entre 5 e 240"
verifica "Editar altera a duração (90)" "$(post $A servicos_editar "{\"id\":$(idsrv 'Dur Texto'),\"nome\":\"Dur Texto\",\"preco\":\"10\",\"duracao_minutos\":90}")" "|200"
verifica "A nova duração ficou gravada (90)" "$(sql "SELECT duracao_minutos FROM servicos WHERE nome='Dur Texto'")" "90"
verifica "A lista pública está ordenada por nome" "$(get $V servicos_publicos | J "[s['nome'] for s in d['servicos']]==sorted([s['nome'] for s in d['servicos']])")" "True"

echo "== Administrador: editar"
ID=$(idsrv Lavagem)
verifica "Edita o preço da Lavagem" "$(post $A servicos_editar "{\"duracao_minutos\":30,\"id\":$ID,\"nome\":\"Lavagem\",\"descricao\":\"Lavagem e hidratação\",\"preco\":\"120\"}")" "|200"
verifica "Preço atualizado na base de dados" "$(preco Lavagem)" "120.00"
verifica "Preço novo aparece na lista pública" "$(get $V servicos_publicos | grep -o '"nome":"Lavagem","descricao":"[^"]*","preco":"120.00"' | wc -l | tr -d ' ')" "1"
verifica "Renomear para nome existente é recusado (409)" "$(post $A servicos_editar "{\"duracao_minutos\":30,\"id\":$ID,\"nome\":\"Barba\",\"preco\":\"120\"}")" "|409"
verifica "Editar com preço inválido é recusado" "$(post $A servicos_editar "{\"duracao_minutos\":30,\"id\":$ID,\"nome\":\"Lavagem\",\"preco\":\"-1\"}")" "preço válido"
verifica "Preço da Lavagem não mudou nos pedidos recusados" "$(preco Lavagem)" "120.00"
verifica "Editar serviço inexistente devolve 404" "$(post $A servicos_editar '{"duracao_minutos":30,"id":99999,"nome":"X","preco":"10"}')" "|404"
verifica "Manter o próprio nome ao editar é permitido" "$(post $A servicos_editar "{\"duracao_minutos\":30,\"id\":$ID,\"nome\":\"Lavagem\",\"preco\":\"130\"}")" "|200"

echo "== Administrador: desativar e ativar"
ID=$(idsrv Massagem)
verifica "Desativa o serviço Massagem" "$(post $A servicos_alternar "{\"id\":$ID}")" "|200"
verifica "Serviço desativado sai da lista pública" "$(get $V servicos_publicos | grep -c 'Massagem')" "0"
verifica "Serviço desativado continua na gestão" "$(get $A servicos)" "Massagem"
verifica "Reativa o serviço" "$(post $A servicos_alternar "{\"id\":$ID}")" "|200"
verifica "Serviço reativado volta à lista pública" "$(get $V servicos_publicos | grep -c 'Massagem')" "1"
verifica "Desativar serviço inexistente devolve 404" "$(post $A servicos_alternar '{"id":99999}')" "|404"

echo "== Texto malicioso fica como texto"
post $A servicos '{"duracao_minutos":30,"nome":"<script>alert(1)</script>","preco":"10"}' >/dev/null
verifica "Nome com marcas HTML é gravado como texto simples" "$(mysql -N -e "SELECT COUNT(*) FROM servicos WHERE nome='<script>alert(1)</script>'" barbearia)" "1"
verifica "O JavaScript apresenta os dados com textContent (nunca innerHTML)" "$(grep -c 'innerHTML' "$RAIZ"/publico/js/*.js | grep -v ':0' | wc -l | tr -d ' ')" "0"

echo; echo "Resultado: $ok passaram, $falhas falharam"; [ $falhas -eq 0 ]
