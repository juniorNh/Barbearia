#!/usr/bin/env bash
# Testes do módulo financeiro (pagamentos, despesas, receitas, histórico, relatórios, dashboard).
# Uso (a partir da pasta do projeto): bash testes/teste_financas.sh http://127.0.0.1:8099
# Requer o comando "mysql", python3 e a base "barbearia" recém-instalada (com os serviços de exemplo)
# e o Administrador de teste admin@teste.com / senhaforte1 (apenas para ambiente de teste).
B=${1:-http://127.0.0.1:8099}; ok=0; falhas=0
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
API="$B/api/index.php"
MY="mysql --default-character-set=utf8mb4 -N"
$MY -e "DELETE FROM tentativas_acesso" barbearia
csrf(){ curl -s -b "$1" -c "$1" "$API?r=sessao" | sed -n 's/.*"csrf":"\([a-f0-9]*\)".*/\1/p'; }
verifica(){ if [[ "$2" == *"$3"* ]]; then echo "OK    $1"; ok=$((ok+1)); else echo "FALHA $1 (obtido: ${2:0:220})"; falhas=$((falhas+1)); fi; }
post(){ local t; t="$(csrf "$1")"; curl -s -b "$1" -c "$1" -H "Content-Type: application/json" -H "X-CSRF-Token: $t" -d "$3" -w "|%{http_code}" "$API?r=$2"; }
get(){ curl -s -b "$1" -c "$1" -w "|%{http_code}" -G "$API" --data-urlencode "r=$2" "${@:3}"; }
J(){ python3 -c 'import sys,json;d=json.loads(sys.stdin.read().rsplit("|",1)[0]);print(eval(sys.argv[1],{"d":d,"f":lambda x:"%.2f"%x}))' "$1"; }
sql(){ $MY -e "$1" barbearia; }
if [ "$(sql "SELECT COUNT(*) FROM atendimentos")" != "0" ]; then
  echo "Este teste precisa de uma base de dados recém-instalada (sem atendimentos). Reinstale a base e repita."; exit 2
fi
HOJE=$(date -u -d '+2 hours' '+%Y-%m-%d')
AMANHA=$(date -u -d '+2 hours +1 day' '+%Y-%m-%d')
A=$(mktemp); F1=$(mktemp); F2=$(mktemp); C1=$(mktemp); V=$(mktemp)
SRV=$(sql "SELECT id FROM servicos WHERE nome='Corte normal'")
SRV2=$(sql "SELECT id FROM servicos WHERE nome='Barba'")

echo "== Preparação"
post $A entrar '{"area":"admin","email":"admin@teste.com","senha":"senhaforte1"}' >/dev/null
for n in a b; do post $A utilizadores "{\"nome\":\"Barbeiro $n Fin\",\"email\":\"fin$n@teste.com\",\"perfil\":\"funcionario\",\"senha\":\"barbeiro123\",\"senha2\":\"barbeiro123\"}" >/dev/null; done
post $F1 entrar '{"area":"admin","email":"fina@teste.com","senha":"barbeiro123"}' >/dev/null
post $F2 entrar '{"area":"admin","email":"finb@teste.com","senha":"barbeiro123"}' >/dev/null
post $C1 registar '{"nome":"Cliente Fin Um","contacto":"84700001","email":"fincli@teste.com","senha":"12345678","senha2":"12345678"}' >/dev/null
post $C1 entrar '{"area":"conta","email":"fincli@teste.com","senha":"12345678"}' >/dev/null
IDF1=$(sql "SELECT id FROM utilizadores WHERE email='fina@teste.com'")
IDF2=$(sql "SELECT id FROM utilizadores WHERE email='finb@teste.com'")
for n in 1 2 3 4; do eval "W$n=\$(sql \"INSERT INTO clientes (nome_completo, contacto) VALUES ('Cliente Balcao Fin $n','84 888 000$n'); SELECT LAST_INSERT_ID()\")"; done
novo(){ post $A atendimentos "{\"cliente_id\":$1,\"servico_id\":$2,\"funcionario_id\":$3}" >/dev/null; sql "SELECT MAX(id) FROM atendimentos"; }
AT1=$(novo $W1 $SRV $IDF1); AT2=$(novo $W2 $SRV2 $IDF2); AT3=$(novo $W3 $SRV $IDF1); AT4=$(novo $W4 $SRV2 $IDF1)
for id in $AT1 $AT2; do post $A atendimentos_estado "{\"id\":$id,\"acao\":\"iniciar\"}" >/dev/null; post $A atendimentos_estado "{\"id\":$id,\"acao\":\"concluir\"}" >/dev/null; done
post $A atendimentos_estado "{\"id\":$AT3,\"acao\":\"iniciar\"}" >/dev/null; post $A atendimentos_estado "{\"id\":$AT3,\"acao\":\"concluir\"}" >/dev/null
verifica "Há 3 atendimentos concluídos e 1 em espera" "$(sql "SELECT SUM(estado='concluido'), SUM(estado='em_espera') FROM atendimentos")" "3	1"
verifica "A tabela pagamentos existe" "$(sql "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='barbearia' AND table_name='pagamentos'")" "1"

echo "== Ficheiros e separação"
verifica "Nenhum ficheiro PHP contém HTML" "$(grep -rlE '<(html|head|body|div|form|table|input|p|h1|a)[ >]' --include=*.php "$RAIZ" | wc -l | tr -d ' ')" "0"
for p in admin/financas.html admin/pagamentos.html admin/receitas.html admin/despesas.html admin/historico.html admin/relatorios.html js/graficos.js js/financeiro.js js/financas.js js/pagamentos.js js/receitas.js js/despesas.js js/historico.js js/relatorios.js; do
  verifica "Ficheiro estático servido: $p" "$(curl -s -o /dev/null -w '%{http_code}' "$B/$p")" "200"
done
verifica "O JavaScript nunca usa innerHTML" "$(grep -c 'innerHTML' "$RAIZ"/publico/js/*.js | grep -v ':0' | wc -l | tr -d ' ')" "0"

echo "== Permissões"
for r in por_receber pagamentos despesas financas_resumo financas_serie financas_historico; do
  verifica "Sem sessão, $r devolve 401" "$(get $V $r)" "|401"
  verifica "Cliente, $r devolve 403" "$(get $C1 $r)" "|403"
done
for r in despesas financas_resumo financas_serie financas_historico; do verifica "Funcionário, $r devolve 403" "$(get $F1 $r)" "|403"; done
verifica "Funcionário não regista despesas (403)" "$(post $F1 despesas "{\"descricao\":\"Teste\",\"valor\":\"10\",\"data_despesa\":\"$HOJE\"}")" "|403"
verifica "Cliente não regista pagamentos (403)" "$(post $C1 pagamentos "{\"atendimento_id\":$AT1,\"metodo\":\"mpesa\"}")" "|403"
verifica "Funcionário vê 'por receber'" "$(get $F1 por_receber)" "|200"

echo "== Por receber"
verifica "O Funcionário A vê só os seus 2 atendimentos por receber" "$(get $F1 por_receber | J "len(d['atendimentos'])")" "2"
verifica "O Funcionário B vê só o seu 1" "$(get $F2 por_receber | J "len(d['atendimentos'])")" "1"
verifica "O Administrador vê os 3" "$(get $A por_receber | J "len(d['atendimentos'])")" "3"
verifica "Atendimento em espera não aparece" "$(get $A por_receber | grep -c "\"id\":$AT4,")" "0"
verifica "O valor é o preço do serviço" "$(get $A por_receber | J "sorted(a['valor'] for a in d['atendimentos'])")" "['150.00', '200.00', '200.00']"

echo "== Registar pagamentos"
verifica "Sem token CSRF é recusado (403)" "$(curl -s -b $F1 -c $F1 -H 'Content-Type: application/json' -d "{\"atendimento_id\":$AT3,\"metodo\":\"mpesa\"}" -w '|%{http_code}' "$API?r=pagamentos")" "|403"
verifica "Método inválido é recusado" "$(post $F1 pagamentos "{\"atendimento_id\":$AT3,\"metodo\":\"bitcoin\"}")" "método de pagamento"
verifica "Sem método é recusado" "$(post $F1 pagamentos "{\"atendimento_id\":$AT3}")" "método de pagamento"
verifica "Atendimento inexistente devolve 404" "$(post $F1 pagamentos '{"atendimento_id":99999,"metodo":"mpesa"}')" "|404"
verifica "Atendimento ainda em espera não se paga (409)" "$(post $A pagamentos "{\"atendimento_id\":$AT4,\"metodo\":\"mpesa\"}")" "|409"
verifica "O Funcionário B não paga atendimentos do A (403)" "$(post $F2 pagamentos "{\"atendimento_id\":$AT3,\"metodo\":\"mpesa\"}")" "|403"
verifica "Nada foi gravado pelos pedidos inválidos" "$(sql "SELECT COUNT(*) FROM pagamentos")" "0"
verifica "O Funcionário A regista o pagamento do seu atendimento (201)" "$(post $F1 pagamentos "{\"atendimento_id\":$AT1,\"metodo\":\"mpesa\",\"valor\":1,\"registado_por\":999}")" "|201"
verifica "O valor gravado é o preço do atendimento, não o enviado" "$(sql "SELECT valor FROM pagamentos WHERE atendimento_id=$AT1")" "200.00"
verifica "Quem registou vem da sessão" "$(sql "SELECT registado_por FROM pagamentos WHERE atendimento_id=$AT1")" "$IDF1"
verifica "A data do pagamento é automática (hora de Maputo)" "$(sql "SELECT DATE_FORMAT(data_pagamento,'%Y-%m-%d %H') FROM pagamentos WHERE atendimento_id=$AT1")" "$(date -u -d '+2 hours' '+%Y-%m-%d %H')"
verifica "Pagar duas vezes o mesmo atendimento é recusado (409)" "$(post $F1 pagamentos "{\"atendimento_id\":$AT1,\"metodo\":\"numerario\"}")" "já tem o pagamento"
verifica "O Funcionário B regista o pagamento do seu atendimento" "$(post $F2 pagamentos "{\"atendimento_id\":$AT2,\"metodo\":\"numerario\"}")" "|201"
verifica "O preço do serviço Barba é gravado (150.00)" "$(sql "SELECT valor FROM pagamentos WHERE atendimento_id=$AT2")" "150.00"
verifica "Um só pagamento por atendimento (a base de dados garante)" "$(sql "INSERT INTO pagamentos (atendimento_id,valor,metodo,registado_por) VALUES ($AT1,1,'mpesa',$IDF1)" 2>&1 | grep -c 'Duplicate')" "1"

echo "== Despesas"
verifica "Descrição curta é recusada" "$(post $A despesas "{\"descricao\":\"ab\",\"valor\":\"10\",\"data_despesa\":\"$HOJE\"}")" "descrição"
verifica "Valor zero é recusado" "$(post $A despesas "{\"descricao\":\"Renda\",\"valor\":\"0\",\"data_despesa\":\"$HOJE\"}")" "valor válido"
verifica "Valor negativo é recusado" "$(post $A despesas "{\"descricao\":\"Renda\",\"valor\":\"-5\",\"data_despesa\":\"$HOJE\"}")" "valor válido"
verifica "Valor com letras é recusado" "$(post $A despesas "{\"descricao\":\"Renda\",\"valor\":\"abc\",\"data_despesa\":\"$HOJE\"}")" "valor válido"
verifica "Valor com 3 casas decimais é recusado" "$(post $A despesas "{\"descricao\":\"Renda\",\"valor\":\"10,999\",\"data_despesa\":\"$HOJE\"}")" "valor válido"
verifica "Data inválida é recusada" "$(post $A despesas '{"descricao":"Renda","valor":"10","data_despesa":"2026-02-30"}')" "data válida"
verifica "Sem data é recusado" "$(post $A despesas '{"descricao":"Renda","valor":"10"}')" "data válida"
verifica "Data no futuro é recusada" "$(post $A despesas "{\"descricao\":\"Renda\",\"valor\":\"10\",\"data_despesa\":\"$AMANHA\"}")" "futuro"
verifica "Nada foi gravado pelos pedidos inválidos" "$(sql "SELECT COUNT(*) FROM despesas")" "0"
verifica "Regista despesa com vírgula decimal (201)" "$(post $A despesas "{\"descricao\":\"Renda do espaço\",\"valor\":\"100,50\",\"data_despesa\":\"$HOJE\"}")" "|201"
verifica "A vírgula foi convertida (100.50)" "$(sql "SELECT valor FROM despesas WHERE descricao='Renda do espaço'")" "100.50"
verifica "Regista despesa com valor inteiro enviado como número" "$(post $A despesas "{\"descricao\":\"Produtos de limpeza\",\"valor\":60,\"data_despesa\":\"$HOJE\"}")" "|201"
verifica "Quem registou vem da sessão" "$(sql "SELECT u.perfil FROM despesas d JOIN utilizadores u ON u.id=d.registado_por LIMIT 1")" "administrador"
verifica "Lista as despesas, com o total" "$(get $A despesas | J "str(len(d['despesas']))+'|'+f(d['soma'])+'|'+str(d['total'])")" "2|160.50|2"
verifica "Filtro por período sem despesas devolve 0" "$(get $A despesas --data-urlencode 'de=2020-01-01' --data-urlencode 'ate=2020-12-31' | J "d['total']")" "0"
verifica "Filtro com data inválida é recusado" "$(get $A despesas --data-urlencode 'de=ontem')" "|400"

echo "== Indicadores (dashboard)"
R="$(get $A financas_resumo)"
verifica "Receitas de hoje (200 + 150)" "$(echo "$R" | J "f(d['receitas_hoje'])")" "350.00"
verifica "Receitas da semana" "$(echo "$R" | J "f(d['receitas_semana'])")" "350.00"
verifica "Receitas do mês" "$(echo "$R" | J "f(d['receitas_mes'])")" "350.00"
verifica "Despesas do mês" "$(echo "$R" | J "f(d['despesas_mes'])")" "160.50"
verifica "Lucro do mês = receitas - despesas" "$(echo "$R" | J "f(d['lucro_mes'])")" "189.50"
verifica "Saldo total = receitas - despesas" "$(echo "$R" | J "f(d['saldo'])")" "189.50"
verifica "Por receber: 1 atendimento de 200" "$(echo "$R" | J "str(d['n_por_receber'])+'|'+f(d['por_receber'])")" "1|200.00"
verifica "O Funcionário A paga o último atendimento (201)" "$(post $F1 pagamentos "{\"atendimento_id\":$AT3,\"metodo\":\"emola\"}")" "|201"
R="$(get $A financas_resumo)"
verifica "Depois de pagar, as receitas sobem para 550" "$(echo "$R" | J "f(d['receitas_total'])")" "550.00"
verifica "Depois de pagar, já nada fica por receber" "$(echo "$R" | J "d['n_por_receber']")" "0"
verifica "O saldo acompanha (550 - 160.50 = 389.50)" "$(echo "$R" | J "f(d['saldo'])")" "389.50"

echo "== Pagamentos registados"
verifica "O Funcionário A vê só os seus 2 pagamentos" "$(get $F1 pagamentos | J "d['total']")" "2"
verifica "O Funcionário B vê só o seu 1" "$(get $F2 pagamentos | J "d['total']")" "1"
verifica "O Administrador vê os 3" "$(get $A pagamentos | J "d['total']")" "3"
verifica "A lista mostra cliente, serviço, método e valor" "$(get $A pagamentos | J "d['pagamentos'][0]['cliente']+'|'+d['pagamentos'][0]['metodo']+'|'+d['pagamentos'][0]['valor']")" "Cliente Balcao Fin 3|emola|200.00"
verifica "A soma dos pagamentos do Funcionário A é 400" "$(get $F1 pagamentos | J "f(d['soma'])")" "400.00"
verifica "A lista não expõe emails nem senhas" "$(get $A pagamentos | grep -c 'senha\|@teste.com')" "0"

echo "== Séries por dia, semana e mês (dados fixos de janeiro e fevereiro de 2026)"
ins(){ sql "INSERT INTO atendimentos (cliente_id,servico_id,funcionario_id,preco_cobrado,estado,data_hora,concluido_em) VALUES ($W1,$SRV,$IDF1,$2,'concluido','$1','$1'); INSERT INTO pagamentos (atendimento_id,valor,metodo,data_pagamento,registado_por) VALUES (LAST_INSERT_ID(),$2,'$3','$1',$IDF1)"; }
ins '2026-01-05 10:30:00' 200 numerario; ins '2026-01-11 22:00:00' 100 mpesa; ins '2026-01-12 09:00:00' 300 emola; ins '2026-02-03 12:00:00' 150 cartao
sql "INSERT INTO despesas (descricao,valor,data_despesa,registado_por) VALUES ('Água',50.00,'2026-01-06',$IDF1),('Luz',25.50,'2026-02-03',$IDF1)"
D="$(get $A financas_serie --data-urlencode 'agrupar=dia' --data-urlencode 'de=2026-01-01' --data-urlencode 'ate=2026-01-31')"
verifica "Por dia: 31 períodos (incluindo os sem movimentos)" "$(echo "$D" | J "len(d['periodos'])")" "31"
verifica "Por dia: 5 de janeiro recebeu 200" "$(echo "$D" | J "f([p for p in d['periodos'] if p['periodo']=='2026-01-05'][0]['receitas'])")" "200.00"
verifica "Por dia: um pagamento às 22:00 fica no dia certo (11 de janeiro)" "$(echo "$D" | J "f([p for p in d['periodos'] if p['periodo']=='2026-01-11'][0]['receitas'])")" "100.00"
verifica "Por dia: dia sem movimentos tem zeros" "$(echo "$D" | J "f([p for p in d['periodos'] if p['periodo']=='2026-01-20'][0]['receitas'])")" "0.00"
verifica "Por dia: 6 de janeiro tem a despesa e lucro negativo" "$(echo "$D" | J "(lambda P: f(P['despesas'])+'|'+f(P['lucro']))([p for p in d['periodos'] if p['periodo']=='2026-01-06'][0])")" "50.00|-50.00"
verifica "Por dia: totais (600, 50, 550)" "$(echo "$D" | J "f(d['totais']['receitas'])+'|'+f(d['totais']['despesas'])+'|'+f(d['totais']['lucro'])+'|'+str(d['totais']['pagamentos'])")" "600.00|50.00|550.00|3"
verifica "Por método de pagamento" "$(echo "$D" | J "sorted((m['metodo'],f(m['valor'])) for m in d['por_metodo'])")" "[('emola', '300.00'), ('mpesa', '100.00'), ('numerario', '200.00')]"
S="$(get $A financas_serie --data-urlencode 'agrupar=semana' --data-urlencode 'de=2026-01-01' --data-urlencode 'ate=2026-01-31')"
verifica "Por semana: 5 semanas, a começar na segunda-feira anterior (29 de dezembro)" "$(echo "$S" | J "[p['periodo'] for p in d['periodos']]")" "['2025-12-29', '2026-01-05', '2026-01-12', '2026-01-19', '2026-01-26']"
verifica "Por semana: domingo 11 conta na semana de 5 de janeiro (200 + 100)" "$(echo "$S" | J "f(d['periodos'][1]['receitas'])")" "300.00"
verifica "Por semana: semana de 12 de janeiro (300)" "$(echo "$S" | J "f(d['periodos'][2]['receitas'])")" "300.00"
verifica "Por semana: a despesa de 6 de janeiro conta na semana de 5" "$(echo "$S" | J "f(d['periodos'][1]['despesas'])")" "50.00"
M="$(get $A financas_serie --data-urlencode 'agrupar=mes' --data-urlencode 'de=2026-01-01' --data-urlencode 'ate=2026-02-28')"
verifica "Por mês: janeiro e fevereiro" "$(echo "$M" | J "[p['periodo'] for p in d['periodos']]")" "['2026-01', '2026-02']"
verifica "Por mês: janeiro (600, 50, 550)" "$(echo "$M" | J "f(d['periodos'][0]['receitas'])+'|'+f(d['periodos'][0]['despesas'])+'|'+f(d['periodos'][0]['lucro'])")" "600.00|50.00|550.00"
verifica "Por mês: fevereiro (150, 25.5, 124.5)" "$(echo "$M" | J "f(d['periodos'][1]['receitas'])+'|'+f(d['periodos'][1]['despesas'])+'|'+f(d['periodos'][1]['lucro'])")" "150.00|25.50|124.50"
verifica "Série por defeito (dia) tem 30 períodos" "$(get $A financas_serie | J "len(d['periodos'])")" "30"
verifica "Série por defeito (semana) tem 12 períodos" "$(get $A financas_serie --data-urlencode 'agrupar=semana' | J "len(d['periodos'])")" "12"
verifica "Série por defeito (mês) tem 12 períodos" "$(get $A financas_serie --data-urlencode 'agrupar=mes' | J "len(d['periodos'])")" "12"
verifica "A série de hoje inclui as receitas de hoje (350 + 200)" "$(get $A financas_serie | J "f(d['totais']['receitas'])")" "550.00"
verifica "Agrupamento inválido é recusado" "$(get $A financas_serie --data-urlencode 'agrupar=ano')" "|400"
verifica "Data inválida é recusada" "$(get $A financas_serie --data-urlencode 'de=2026-13-01')" "|400"
verifica "Data inicial depois da final é recusada" "$(get $A financas_serie --data-urlencode 'de=2026-02-01' --data-urlencode 'ate=2026-01-01')" "|400"
verifica "Intervalo enorme por dia é recusado" "$(get $A financas_serie --data-urlencode 'agrupar=dia' --data-urlencode 'de=2020-01-01' --data-urlencode 'ate=2026-01-01')" "demasiado grande"

echo "== Histórico de movimentos"
H="$(get $A financas_historico --data-urlencode 'de=2026-01-01' --data-urlencode 'ate=2026-01-31')"
verifica "Janeiro: 3 entradas e 1 saída" "$(echo "$H" | J "d['total']")" "4"
verifica "Janeiro: entradas 600 e saídas 50" "$(echo "$H" | J "f(d['entradas'])+'|'+f(d['saidas'])")" "600.00|50.00"
verifica "Do mais recente para o mais antigo" "$(echo "$H" | J "[m['data'][:10] for m in d['movimentos']]")" "['2026-01-12', '2026-01-11', '2026-01-06', '2026-01-05']"
verifica "Filtrar só entradas" "$(get $A financas_historico --data-urlencode 'tipo=entrada' --data-urlencode 'de=2026-01-01' --data-urlencode 'ate=2026-01-31' | J "d['total']")" "3"
verifica "Filtrar só saídas" "$(get $A financas_historico --data-urlencode 'tipo=saida' --data-urlencode 'de=2026-01-01' --data-urlencode 'ate=2026-02-28' | J "d['total']")" "2"
verifica "Uma entrada mostra o serviço, o cliente e o método" "$(echo "$H" | J "d['movimentos'][0]['descricao']+'|'+d['movimentos'][0]['metodo']")" "Corte normal - Cliente Balcao Fin 1|emola"
verifica "Uma saída mostra a descrição da despesa" "$(echo "$H" | J "d['movimentos'][2]['descricao']")" "Água"
verifica "Sem filtros, o histórico tem tudo (3 + 4 pagamentos e 4 despesas)" "$(get $A financas_historico | J "d['total']")" "11"
verifica "Tipo desconhecido é ignorado (mostra tudo)" "$(get $A financas_historico --data-urlencode "tipo=x' OR 1=1" | J "d['total']")" "11"
verifica "Data inicial depois da final é recusada" "$(get $A financas_historico --data-urlencode 'de=2026-02-01' --data-urlencode 'ate=2026-01-01')" "|400"
verifica "A tabela de pagamentos continua intacta" "$(sql "SELECT COUNT(*) FROM pagamentos")" "7"

echo; echo "Resultado: $ok passaram, $falhas falharam"; [ $falhas -eq 0 ]
