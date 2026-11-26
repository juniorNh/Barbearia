#!/usr/bin/env bash
# Testes das marcações (agendamentos). Uso: bash testes/teste_agendamentos.sh http://127.0.0.1:8099
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
dia(){ date -d "+3 days $1" '+%Y-%m-%dT%H:%M'; }
A=$(mktemp); F1=$(mktemp); F2=$(mktemp); C1=$(mktemp); C2=$(mktemp); V=$(mktemp)
SRV=$(sql "SELECT id FROM servicos WHERE nome='Corte normal'")

echo "== Preparação"
post $A entrar '{"area":"admin","email":"admin@teste.com","senha":"senhaforte1"}' >/dev/null
for n in a b; do post $A utilizadores "{\"nome\":\"Barbeiro $n Marc\",\"email\":\"marc$n@teste.com\",\"perfil\":\"funcionario\",\"senha\":\"barbeiro123\",\"senha2\":\"barbeiro123\"}" >/dev/null; done
post $F1 entrar '{"area":"admin","email":"marca@teste.com","senha":"barbeiro123"}' >/dev/null
post $F2 entrar '{"area":"admin","email":"marcb@teste.com","senha":"barbeiro123"}' >/dev/null
i=0; for jar in $C1 $C2; do i=$((i+1)); post $jar registar "{\"nome\":\"Cliente Marc $i\",\"contacto\":\"8460000$i\",\"email\":\"marc$i@teste.com\",\"senha\":\"12345678\",\"senha2\":\"12345678\"}" >/dev/null
  post $jar entrar "{\"area\":\"conta\",\"email\":\"marc$i@teste.com\",\"senha\":\"12345678\"}" >/dev/null; done
IDF1=$(sql "SELECT id FROM utilizadores WHERE email='marca@teste.com'")
IDF2=$(sql "SELECT id FROM utilizadores WHERE email='marcb@teste.com'")
IDCLI1=$(sql "SELECT id FROM clientes WHERE nome_completo='Cliente Marc 1'")
IDUCLI1=$(sql "SELECT utilizador_id FROM clientes WHERE id=$IDCLI1")
verifica "A tabela agendamentos e a coluna da duração existem" "$(sql "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='barbearia' AND ((table_name='agendamentos' AND column_name='duracao_minutos') OR (table_name='servicos' AND column_name='duracao_minutos'))")" "2"

echo "== Ficheiros e separação"
verifica "Nenhum ficheiro PHP contém HTML" "$(grep -rlE '<(html|head|body|div|form|table|input|p|h1|a)[ >]' --include=*.php "$RAIZ" | wc -l | tr -d ' ')" "0"
for p in admin/agendamentos.html js/agendamentos.js; do verifica "Ficheiro estático servido: $p" "$(curl -s -o /dev/null -w '%{http_code}' "$B/$p")" "200"; done
verifica "O JavaScript nunca usa innerHTML" "$(grep -c 'innerHTML' "$RAIZ"/publico/js/*.js | grep -v ':0' | wc -l | tr -d ' ')" "0"

echo "== Permissões"
for r in agendamentos_meus agendamentos_pessoal; do verifica "Sem sessão, $r devolve 401" "$(get $V $r)" "|401"; done
verifica "Sem sessão não se cria marcação (401)" "$(curl -s -H 'Content-Type: application/json' -d '{}' -w '|%{http_code}' "$API?r=agendamentos_criar")" "|401"
verifica "O pessoal não cria marcações como cliente (403)" "$(post $F1 agendamentos_criar "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1,\"data_hora\":\"$(dia 10:00)\"}")" "|403"
verifica "O pessoal não consulta 'as minhas marcações' (403)" "$(get $F1 agendamentos_meus)" "|403"
verifica "O cliente não vê a lista do pessoal (403)" "$(get $C1 agendamentos_pessoal)" "|403"
verifica "Criar sem token CSRF é recusado (403)" "$(curl -s -b $C1 -c $C1 -H 'Content-Type: application/json' -d "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1,\"data_hora\":\"$(dia 10:00)\"}" -w '|%{http_code}' "$API?r=agendamentos_criar")" "|403"

echo "== Validação"
verifica "Data no passado é recusada" "$(post $C1 agendamentos_criar "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1,\"data_hora\":\"2020-01-01T10:00\"}")" "futuras"
verifica "Data a mais de 90 dias é recusada" "$(post $C1 agendamentos_criar "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1,\"data_hora\":\"$(date -d '+120 days 10:00' '+%Y-%m-%dT%H:%M')\"}")" "90 dias"
verifica "Formato de data inválido é recusado" "$(post $C1 agendamentos_criar "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1,\"data_hora\":\"amanhã\"}")" "futuras"
verifica "Data com segundos é recusada" "$(post $C1 agendamentos_criar "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1,\"data_hora\":\"$(dia 10:00):30\"}")" "futuras"
verifica "Sem data é recusado" "$(post $C1 agendamentos_criar "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1}")" "futuras"
verifica "Serviço inexistente é recusado" "$(post $C1 agendamentos_criar "{\"servico_id\":99999,\"funcionario_id\":$IDF1,\"data_hora\":\"$(dia 10:00)\"}")" "Serviço indispon"
verifica "Barbeiro inexistente é recusado" "$(post $C1 agendamentos_criar "{\"servico_id\":$SRV,\"funcionario_id\":99999,\"data_hora\":\"$(dia 10:00)\"}")" "Barbeiro indispon"
verifica "Um cliente não pode ser o barbeiro" "$(post $C1 agendamentos_criar "{\"servico_id\":$SRV,\"funcionario_id\":$IDUCLI1,\"data_hora\":\"$(dia 10:00)\"}")" "Barbeiro indispon"
verifica "Nada foi gravado pelos pedidos inválidos" "$(sql "SELECT COUNT(*) FROM agendamentos")" "0"

echo "== Criar"
verifica "Cliente 1 marca para o barbeiro A às 10:00 (201)" "$(post $C1 agendamentos_criar "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1,\"data_hora\":\"$(dia 10:00)\",\"preco\":1,\"cliente_id\":999,\"estado\":\"concluido\"}")" "|201"
verifica "O preço gravado é o do serviço (200.00)" "$(sql "SELECT preco_cobrado FROM agendamentos ORDER BY id LIMIT 1")" "200.00"
verifica "A duração gravada é a do serviço (30)" "$(sql "SELECT duracao_minutos FROM agendamentos ORDER BY id LIMIT 1")" "30"
verifica "O cliente gravado é o da sessão" "$(sql "SELECT cliente_id FROM agendamentos ORDER BY id LIMIT 1")" "$IDCLI1"
verifica "O estado inicial é pendente (o enviado é ignorado)" "$(sql "SELECT estado FROM agendamentos ORDER BY id LIMIT 1")" "pendente"
verifica "A data e hora gravadas são as escolhidas" "$(sql "SELECT DATE_FORMAT(data_hora,'%Y-%m-%dT%H:%i') FROM agendamentos ORDER BY id LIMIT 1")" "$(dia 10:00)"

echo "== Conflitos de horário"
verifica "Mesma hora e mesmo barbeiro (409)" "$(post $C2 agendamentos_criar "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1,\"data_hora\":\"$(dia 10:00)\"}")" "|409"
verifica "Sobreposição parcial às 10:15 (409)" "$(post $C2 agendamentos_criar "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1,\"data_hora\":\"$(dia 10:15)\"}")" "|409"
verifica "Mensagem clara do conflito" "$(post $C2 agendamentos_criar "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1,\"data_hora\":\"$(dia 10:00)\"}")" "já tem um agendamento"
verifica "Logo a seguir, às 10:30, é permitido (201)" "$(post $C2 agendamentos_criar "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1,\"data_hora\":\"$(dia 10:30)\"}")" "|201"
verifica "Logo antes, às 09:30, é permitido (201)" "$(post $C1 agendamentos_criar "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1,\"data_hora\":\"$(dia 09:30)\"}")" "|201"
verifica "Outro barbeiro à mesma hora é permitido (201)" "$(post $C2 agendamentos_criar "{\"servico_id\":$SRV,\"funcionario_id\":$IDF2,\"data_hora\":\"$(dia 10:00)\"}")" "|201"

echo "== Consultar"
M1="$(get $C1 agendamentos_meus)"
verifica "O cliente 1 vê as suas 2 marcações" "$(echo "$M1" | J "len(d['agendamentos'])")" "2"
verifica "Cada marcação mostra serviço, barbeiro, duração e preço" "$(echo "$M1" | J "d['agendamentos'][0]['servico']+'|'+d['agendamentos'][0]['funcionario']+'|'+str(d['agendamentos'][0]['duracao_minutos'])+'|'+d['agendamentos'][0]['preco_cobrado']")" "Corte normal|Barbeiro a Marc|30|200.00"
verifica "O cliente não vê marcações de outros" "$(echo "$M1" | grep -c 'Cliente Marc 2')" "0"
verifica "O pessoal vê todas (4)" "$(get $F1 agendamentos_pessoal | J "len(d['agendamentos'])")" "4"
verifica "A lista do pessoal mostra o nome do cliente" "$(get $A agendamentos_pessoal)" "Cliente Marc 2"
verifica "A lista não expõe emails nem senhas" "$(get $A agendamentos_pessoal | grep -c 'senha\|@teste.com')" "0"

echo "== Cancelar"
AG1=$(sql "SELECT id FROM agendamentos WHERE cliente_id=$IDCLI1 ORDER BY data_hora DESC LIMIT 1")
verifica "Sem id é recusado" "$(post $C1 agendamentos_cancelar '{}')" "inválido"
verifica "Um cliente não cancela a marcação de outro (409)" "$(post $C2 agendamentos_cancelar "{\"id\":$AG1}")" "|409"
verifica "O cliente cancela a sua marcação" "$(post $C1 agendamentos_cancelar "{\"id\":$AG1}")" "|200"
verifica "O estado passou a cancelado" "$(sql "SELECT estado FROM agendamentos WHERE id=$AG1")" "cancelado"
verifica "Cancelar outra vez é recusado (409)" "$(post $C1 agendamentos_cancelar "{\"id\":$AG1}")" "|409"
verifica "O horário cancelado fica livre para outro cliente (201)" "$(post $C2 agendamentos_criar "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1,\"data_hora\":\"$(dia 10:00)\"}")" "|201"
AG2=$(sql "SELECT id FROM agendamentos WHERE cliente_id=$IDCLI1 AND estado='pendente' LIMIT 1")
sql "UPDATE agendamentos SET data_hora = data_hora - INTERVAL 10 DAY WHERE id=$AG2"
verifica "Marcação que já passou não se cancela (409)" "$(post $C1 agendamentos_cancelar "{\"id\":$AG2}")" "|409"

echo "== Convive com a fila"
verifica "Quem tem marcação também pode entrar na fila (201)" "$(post $C1 entrar_na_fila "{\"servico_id\":$SRV,\"funcionario_id\":$IDF1}")" "|201"
verifica "As marcações não aparecem na fila de hoje" "$(get $F1 fila | J "len(d['fila'])")" "1"

echo; echo "Resultado: $ok passaram, $falhas falharam"; [ $falhas -eq 0 ]
