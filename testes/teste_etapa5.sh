#!/usr/bin/env bash
# Testes da etapa 5 (atendimentos e fila).
# Uso (a partir da pasta do projeto): bash testes/teste_etapa5.sh http://127.0.0.1:8099
# Requer o comando "mysql", python3 e a base "barbearia" recém-instalada (com os serviços de exemplo)
# e o Administrador de teste admin@teste.com / senhaforte1 (apenas para ambiente de teste).
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
A=$(mktemp); F1=$(mktemp); F2=$(mktemp); C1=$(mktemp); C2=$(mktemp); C3=$(mktemp); C4=$(mktemp); V=$(mktemp)
SRV=$(sql "SELECT id FROM servicos WHERE nome='Corte normal'")
SRV2=$(sql "SELECT id FROM servicos WHERE nome='Barba'")

echo "== Preparação"
post $A entrar '{"area":"admin","email":"admin@teste.com","senha":"senhaforte1"}' >/dev/null
for n in a b; do post $A utilizadores "{\"nome\":\"Barbeiro $n Cinco\",\"email\":\"func5$n@teste.com\",\"perfil\":\"funcionario\",\"senha\":\"barbeiro123\",\"senha2\":\"barbeiro123\"}" >/dev/null; done
post $F1 entrar '{"area":"admin","email":"func5a@teste.com","senha":"barbeiro123"}' >/dev/null
post $F2 entrar '{"area":"admin","email":"func5b@teste.com","senha":"barbeiro123"}' >/dev/null
i=0; for jar in $C1 $C2 $C3 $C4; do i=$((i+1)); post $jar registar "{\"nome\":\"Cliente Fila $i\",\"contacto\":\"8450000$i\",\"email\":\"fila$i@teste.com\",\"senha\":\"12345678\",\"senha2\":\"12345678\"}" >/dev/null
  post $jar entrar "{\"area\":\"conta\",\"email\":\"fila$i@teste.com\",\"senha\":\"12345678\"}" >/dev/null; done
IDF1=$(sql "SELECT id FROM utilizadores WHERE email='func5a@teste.com'")
IDF2=$(sql "SELECT id FROM utilizadores WHERE email='func5b@teste.com'")
IDADM=$(sql "SELECT id FROM utilizadores WHERE email='admin@teste.com'")
IDCLI1=$(sql "SELECT id FROM clientes WHERE nome_completo='Cliente Fila 1'")
IDUCLI1=$(sql "SELECT utilizador_id FROM clientes WHERE id=$IDCLI1")
verifica "Há dois barbeiros e quatro clientes com sessão" "$(sql "SELECT COUNT(*) FROM utilizadores WHERE email LIKE 'func5%' OR email LIKE 'fila%'")" "6"

echo "== Ficheiros e separação"
verifica "Nenhum ficheiro PHP contém HTML" "$(grep -rlE '<(html|head|body|div|form|table|input|p|h1|a)[ >]' --include=*.php "$RAIZ" | wc -l | tr -d ' ')" "0"
for p in admin/atendimentos.html js/atendimentos.js conta/inicio.html js/cliente-inicio.js; do
  verifica "Ficheiro estático servido: $p" "$(curl -s -o /dev/null -w '%{http_code}' "$B/$p")" "200"
done
verifica "O JavaScript nunca usa innerHTML" "$(grep -c 'innerHTML' "$RAIZ"/publico/js/*.js | grep -v ':0' | wc -l | tr -d ' ')" "0"

echo "== Permissões"
for r in atendimentos fila minha_area barbeiros; do verifica "Sem sessão, $r devolve 401" "$(get $V $r)" "|401"; done
verifica "Cliente não vê o histórico do pessoal (403)" "$(get $C1 atendimentos)" "|403"
verifica "Cliente não vê a fila do pessoal (403)" "$(get $C1 fila)" "|403"
verifica "Cliente não regista atendimentos (403)" "$(post $C1 atendimentos "{\"cliente_id\":$IDCLI1,\"servico_id\":$SRV,\"funcionario_id\":$IDF1}")" "|403"
verifica "Cliente não muda estados (403)" "$(post $C1 atendimentos_estado '{"id":1,"acao":"concluir"}')" "|403"
verifica "Funcionário não acede à área do cliente (403)" "$(get $F1 minha_area)" "|403"
verifica "Funcionário não entra na fila como cliente (403)" "$(post $F1 entrar_na_fila "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1}")" "|403"
verifica "Cliente vê a lista de barbeiros" "$(get $C1 barbeiros)" "|200"
verifica "Lista de barbeiros não expõe emails" "$(get $C1 barbeiros | grep -c '@')" "0"

echo "== Cliente entra na fila"
verifica "Entrar sem token CSRF é recusado (403)" "$(curl -s -b $C1 -c $C1 -H 'Content-Type: application/json' -d "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1}" -w '|%{http_code}' "$API?r=entrar_na_fila")" "|403"
verifica "Serviço inexistente é recusado" "$(post $C1 entrar_na_fila "{\"servico_id\":99999,\"funcionario_id\":$IDF1}")" "Serviço indispon"
verifica "Barbeiro inexistente é recusado" "$(post $C1 entrar_na_fila "{\"servico_id\":$SRV,\"funcionario_id\":99999}")" "Barbeiro indispon"
verifica "Um cliente não pode ser o barbeiro" "$(post $C1 entrar_na_fila "{\"servico_id\":$SRV,\"funcionario_id\":$IDUCLI1}")" "Barbeiro indispon"
verifica "Sem serviço é recusado" "$(post $C1 entrar_na_fila "{\"funcionario_id\":$IDF1}")" "Serviço indispon"
verifica "Nada foi gravado pelos pedidos inválidos" "$(sql "SELECT COUNT(*) FROM atendimentos")" "0"
verifica "Cliente 1 entra na fila do barbeiro A (201)" "$(post $C1 entrar_na_fila "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1,\"preco\":1,\"cliente_id\":999,\"estado\":\"concluido\"}")" "|201"
verifica "O preço gravado é o do serviço (200.00), não o enviado" "$(sql "SELECT preco_cobrado FROM atendimentos ORDER BY id LIMIT 1")" "200.00"
verifica "O cliente gravado é o da sessão" "$(sql "SELECT cliente_id FROM atendimentos ORDER BY id LIMIT 1")" "$IDCLI1"
verifica "O estado inicial é em_espera (o enviado é ignorado)" "$(sql "SELECT estado FROM atendimentos ORDER BY id LIMIT 1")" "em_espera"
verifica "Cliente 1 já na fila não entra outra vez (409)" "$(post $C1 entrar_na_fila "{\"servico_id\":$SRV2,\"funcionario_id\":$IDF2}")" "|409"
verifica "Mensagem clara para quem já está na fila" "$(post $C1 entrar_na_fila "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1}")" "Já está na fila"
verifica "Só existe 1 entrada ativa do cliente 1" "$(sql "SELECT COUNT(*) FROM atendimentos WHERE cliente_id=$IDCLI1")" "1"
verifica "Data e hora são registadas automaticamente (hora de Maputo)" "$(sql "SELECT DATE_FORMAT(data_hora,'%Y-%m-%d %H') FROM atendimentos ORDER BY id LIMIT 1")" "$(date -u -d '+2 hours' '+%Y-%m-%d %H')"

echo "== Posição na fila"
post $C2 entrar_na_fila "{\"servico_id\":$SRV2,\"funcionario_id\":$IDF1}" >/dev/null
post $C3 entrar_na_fila "{\"servico_id\":$SRV,\"funcionario_id\":$IDF2}" >/dev/null
M1="$(get $C1 minha_area)"; M2="$(get $C2 minha_area)"; M3="$(get $C3 minha_area)"
verifica "Cliente 1 é o primeiro (0 pessoas à frente)" "$(echo "$M1" | J "d['ativo']['a_frente']")" "0"
verifica "Cliente 2 tem 1 pessoa à frente (mesmo barbeiro)" "$(echo "$M2" | J "d['ativo']['a_frente']")" "1"
verifica "Cliente 3 está noutra fila (0 à frente)" "$(echo "$M3" | J "d['ativo']['a_frente']")" "0"
verifica "Área do cliente mostra serviço, preço e barbeiro" "$(echo "$M2" | J "d['ativo']['servico']+'|'+d['ativo']['preco_cobrado']+'|'+d['ativo']['funcionario']")" "Barba|150.00|Barbeiro a Cinco"
verifica "Área do cliente não mostra dados de outros clientes" "$(echo "$M2" | grep -c 'Cliente Fila 1')" "0"
verifica "Barbeiros mostram o tamanho da fila (A=2)" "$(get $C4 barbeiros | J "[b['na_fila'] for b in d['barbeiros'] if b['id']==$IDF1][0]")" "2"
verifica "Barbeiros mostram o tamanho da fila (B=1)" "$(get $C4 barbeiros | J "[b['na_fila'] for b in d['barbeiros'] if b['id']==$IDF2][0]")" "1"

echo "== Atendimento registado pelo pessoal"
W1=$(sql "INSERT INTO clientes (nome_completo, contacto) VALUES ('Cliente Balcao Um','84 999 0001'); SELECT LAST_INSERT_ID()")
W2=$(sql "INSERT INTO clientes (nome_completo, contacto) VALUES ('Cliente Balcao Dois','84 999 0002'); SELECT LAST_INSERT_ID()")
verifica "Funcionário A regista um atendimento (201)" "$(post $F1 atendimentos "{\"cliente_id\":$W1,\"servico_id\":$SRV,\"funcionario_id\":$IDF2}")" "|201"
verifica "O Funcionário regista sempre na sua fila (barbeiro enviado é ignorado)" "$(sql "SELECT funcionario_id FROM atendimentos WHERE cliente_id=$W1")" "$IDF1"
verifica "Cliente do balcão já na fila não entra outra vez" "$(post $A atendimentos "{\"cliente_id\":$W1,\"servico_id\":$SRV,\"funcionario_id\":$IDF1}")" "Este cliente já está na fila"
verifica "Administrador regista para o barbeiro B (201)" "$(post $A atendimentos "{\"cliente_id\":$W2,\"servico_id\":$SRV2,\"funcionario_id\":$IDF2}")" "|201"
verifica "O Administrador escolheu o barbeiro B" "$(sql "SELECT funcionario_id FROM atendimentos WHERE cliente_id=$W2")" "$IDF2"
verifica "O preço do atendimento é o do serviço (Barba 150.00)" "$(sql "SELECT preco_cobrado FROM atendimentos WHERE cliente_id=$W2")" "150.00"
W4=$(sql "INSERT INTO clientes (nome_completo, contacto) VALUES ('Cliente Balcao Quatro','84 999 0004'); SELECT LAST_INSERT_ID()")
verifica "Administrador sem barbeiro é recusado" "$(post $A atendimentos "{\"cliente_id\":$W4,\"servico_id\":$SRV}")" "Barbeiro indispon"
verifica "Cliente inexistente devolve 404" "$(post $A atendimentos "{\"cliente_id\":99999,\"servico_id\":$SRV,\"funcionario_id\":$IDF1}")" "|404"

echo "== Fila e histórico do pessoal"
FA="$(get $F1 fila)"; FADM="$(get $A fila)"
verifica "Funcionário A vê só a sua fila" "$(echo "$FA" | J "set(x['funcionario_id'] for x in d['fila'])")" "{$IDF1}"
verifica "Funcionário A tem 3 na fila" "$(echo "$FA" | J "len(d['fila'])")" "3"
verifica "Administrador vê as filas de todos (5)" "$(echo "$FADM" | J "len(d['fila'])")" "5"
verifica "A fila mostra o nome do cliente" "$FA" "Cliente Fila 1"
verifica "A fila não expõe emails nem senhas" "$(echo "$FADM" | grep -c 'senha\|@teste.com')" "0"
verifica "Histórico do Funcionário A só tem os seus (3)" "$(get $F1 atendimentos | J "d['total']")" "3"
verifica "Histórico do Administrador tem todos (5)" "$(get $A atendimentos | J "d['total']")" "5"
verifica "Filtro por estado funciona" "$(get $A atendimentos --data-urlencode 'estado=concluido' | J "d['total']")" "0"
verifica "Filtro de estado inválido é ignorado" "$(get $A atendimentos --data-urlencode "estado=x' OR 1=1" | J "d['total']")" "5"

echo "== Estados"
AT1=$(sql "SELECT id FROM atendimentos WHERE cliente_id=$IDCLI1")
AT2=$(sql "SELECT a.id FROM atendimentos a JOIN clientes c ON c.id=a.cliente_id WHERE c.nome_completo='Cliente Fila 2'")
AT3=$(sql "SELECT a.id FROM atendimentos a JOIN clientes c ON c.id=a.cliente_id WHERE c.nome_completo='Cliente Fila 3'")
verifica "Ação inválida é recusada" "$(post $F1 atendimentos_estado "{\"id\":$AT1,\"acao\":\"apagar\"}")" "Ação inválida"
verifica "Atendimento inexistente devolve 404" "$(post $F1 atendimentos_estado '{"id":99999,"acao":"iniciar"}')" "|404"
verifica "Funcionário B não gere atendimentos do A (403)" "$(post $F2 atendimentos_estado "{\"id\":$AT1,\"acao\":\"iniciar\"}")" "|403"
verifica "Não se pode concluir quem ainda está em espera (409)" "$(post $F1 atendimentos_estado "{\"id\":$AT1,\"acao\":\"concluir\"}")" "|409"
verifica "Funcionário A inicia o atendimento do cliente 1" "$(post $F1 atendimentos_estado "{\"id\":$AT1,\"acao\":\"iniciar\"}")" "|200"
verifica "O estado passou a em_atendimento" "$(sql "SELECT estado FROM atendimentos WHERE id=$AT1")" "em_atendimento"
verifica "Não se inicia outro com um em curso (409)" "$(post $F1 atendimentos_estado "{\"id\":$AT2,\"acao\":\"iniciar\"}")" "Conclua primeiro"
verifica "O cliente 1 vê que está a ser atendido" "$(get $C1 minha_area | J "d['ativo']['estado']")" "em_atendimento"
verifica "O cliente 2 continua com 1 pessoa à frente (a que está a ser atendida)" "$(get $C2 minha_area | J "d['ativo']['a_frente']")" "1"
verifica "Concluir antes de concluir: sem data de conclusão" "$(sql "SELECT concluido_em IS NULL FROM atendimentos WHERE id=$AT1")" "1"
verifica "Funcionário A conclui o atendimento do cliente 1" "$(post $F1 atendimentos_estado "{\"id\":$AT1,\"acao\":\"concluir\"}")" "|200"
verifica "O atendimento ficou concluído com data de conclusão" "$(sql "SELECT CONCAT(estado,'|',concluido_em IS NOT NULL) FROM atendimentos WHERE id=$AT1")" "concluido|1"
verifica "Concluir outra vez é recusado (409)" "$(post $F1 atendimentos_estado "{\"id\":$AT1,\"acao\":\"concluir\"}")" "|409"
verifica "Cancelar um concluído é recusado (409)" "$(post $F1 atendimentos_estado "{\"id\":$AT1,\"acao\":\"cancelar\"}")" "|409"
verifica "O cliente 2 passa a ser o primeiro (0 à frente)" "$(get $C2 minha_area | J "d['ativo']['a_frente']")" "0"
verifica "O cliente 1 já não tem pedido ativo" "$(get $C1 minha_area | J "d['ativo']")" "None"
verifica "O cliente 1 vê o atendimento concluído no histórico" "$(get $C1 minha_area | J "d['historico'][0]['estado']")" "concluido"
verifica "O cliente 1 pode voltar a entrar na fila (201)" "$(post $C1 entrar_na_fila "{\"servico_id\":$SRV2,\"funcionario_id\":$IDF2}")" "|201"
verifica "Funcionário A inicia o cliente 2" "$(post $F1 atendimentos_estado "{\"id\":$AT2,\"acao\":\"iniciar\"}")" "|200"
verifica "Funcionário A cancela o cliente 2 em atendimento" "$(post $F1 atendimentos_estado "{\"id\":$AT2,\"acao\":\"cancelar\"}")" "|200"
verifica "Cancelado não volta a iniciar (409)" "$(post $F1 atendimentos_estado "{\"id\":$AT2,\"acao\":\"iniciar\"}")" "|409"
verifica "O cliente 2 vê o cancelamento e pode voltar a entrar" "$(get $C2 minha_area | J "d['ativo'] is None and d['historico'][0]['estado']=='cancelado'")" "True"
verifica "Administrador gere o atendimento de outro barbeiro" "$(post $A atendimentos_estado "{\"id\":$AT3,\"acao\":\"iniciar\"}")" "|200"
verifica "Só os atendimentos concluídos contam como receita (1 de 200.00)" "$(sql "SELECT CONCAT(COUNT(*),'|',SUM(preco_cobrado)) FROM atendimentos WHERE estado='concluido'")" "1|200.00"

echo "== Dias anteriores"
post $C4 entrar_na_fila "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1}" >/dev/null
AT4=$(sql "SELECT a.id FROM atendimentos a JOIN clientes c ON c.id=a.cliente_id WHERE c.nome_completo='Cliente Fila 4'")
sql "UPDATE atendimentos SET data_hora = data_hora - INTERVAL 1 DAY WHERE id=$AT4"
get $F1 fila >/dev/null
verifica "Pedido em espera de ontem é cancelado automaticamente" "$(sql "SELECT estado FROM atendimentos WHERE id=$AT4")" "cancelado"
verifica "Esse cliente pode voltar a entrar na fila" "$(post $C4 entrar_na_fila "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1}")" "|201"
sql "UPDATE atendimentos SET data_hora = data_hora - INTERVAL 1 DAY WHERE id=$AT3"
verifica "Atendimento em curso de ontem continua visível para ser concluído" "$(get $A fila | J "any(x['id']==$AT3 for x in d['fila'])")" "True"
verifica "O atendimento em curso de ontem não é cancelado sozinho" "$(sql "SELECT estado FROM atendimentos WHERE id=$AT3")" "em_atendimento"

echo "== Desativações"
post $A utilizadores_alternar "{\"id\":$IDF2}" >/dev/null
verifica "Barbeiro desativado deixa a lista de barbeiros" "$(get $C4 barbeiros | J "any(b['id']==$IDF2 for b in d['barbeiros'])")" "False"
W3=$(sql "INSERT INTO clientes (nome_completo, contacto) VALUES ('Cliente Balcao Tres','84 999 0003'); SELECT LAST_INSERT_ID()")
verifica "Barbeiro desativado não recebe clientes" "$(post $A atendimentos "{\"cliente_id\":$W3,\"servico_id\":$SRV,\"funcionario_id\":$IDF2}")" "Barbeiro indispon"
post $A servicos_alternar "{\"id\":$SRV2}" >/dev/null
verifica "Serviço desativado não pode ser escolhido pelo cliente" "$(post $C3 entrar_na_fila "{\"servico_id\":$SRV2,\"funcionario_id\":$IDF1}")" "Serviço indispon"

echo; echo "Resultado: $ok passaram, $falhas falharam"; [ $falhas -eq 0 ]
