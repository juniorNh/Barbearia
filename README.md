# Sistema de Gestão de Barbearia (HTML/CSS/JS + PHP + MySQL + PHP server)

Estado: **Etapa 5** concluída (atendimentos e fila). Inclui as etapas 2 (login, perfis, utilizadores, registo do cliente), 3 (serviços e preços) e 4 (clientes).

## Tecnologias separadas
| Camada | Onde | O que contém |
|---|---|---|
| Interface | `publico/*.html`, `publico/css/`, `publico/js/` | HTML, CSS e JavaScript puros. Nenhum PHP. |
| API | `publico/api/index.php`, `controladores/` | PHP que só devolve JSON. Nenhum HTML. |
| Regras e segurança | `nucleo/` | Sessão, CSRF, validação, autenticação |
| Dados | `modelos/`, `config/`, `sql/` | PDO e MySQL |

O JavaScript pede os dados à API (`fetch`) e monta as páginas. O PHP valida a sessão e o perfil em cada pedido, por isso abrir uma página protegida sem permissão não mostra dados.

## Instalar no XAMPP (Windows)
1. Copie a pasta `barbearia` para `C:\xampp\htdocs\`.
2. No painel do XAMPP, inicie **Apache** e **MySQL**.
3. Na pasta `barbearia`, execute: `C:\xampp\php\php.exe sql\instalar.php`
   Cria a base de dados e pede o nome, o email e a senha do primeiro Administrador.
4. Abra no navegador:
   - Cliente: `http://localhost/barbearia/publico/`
   - Pessoal: `http://localhost/barbearia/publico/admin/entrar.html`

O acesso à base de dados usa os valores por defeito do XAMPP (utilizador `root`, sem senha). Para mudar, edite `config/configuracao.php`.

## Instalar no Ubuntu (Apache + PHP + MariaDB)
1. `sudo apt update && sudo apt install apache2 php libapache2-mod-php php-mysql php-mbstring mariadb-server unzip` e confirme com `php -v` que o PHP é 8.1 ou superior.
2. `sudo unzip ~/Downloads/barbearia-etapa3.zip -d /var/www/` (fica em `/var/www/barbearia`).
3. Base de dados e utilizador (no Ubuntu o `root` do MariaDB não usa senha por TCP, por isso crie um utilizador próprio): `sudo mysql` e dentro dele:
   ```sql
   CREATE DATABASE barbearia CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   CREATE USER 'barbearia'@'localhost' IDENTIFIED BY 'TROQUE_ESTA_SENHA';
   CREATE USER 'barbearia'@'127.0.0.1' IDENTIFIED BY 'TROQUE_ESTA_SENHA';
   GRANT ALL ON barbearia.* TO 'barbearia'@'localhost';
   GRANT ALL ON barbearia.* TO 'barbearia'@'127.0.0.1';
   EXIT;
   ```
4. `sudo nano /var/www/barbearia/config/configuracao.php`: troque `'root'` por `'barbearia'` e a senha vazia `''` (a que vem a seguir a `BARBEARIA_BD_SENHA`) pela senha escolhida.
5. `cd /var/www/barbearia && php sql/instalar.php` (cria as tabelas, os serviços de exemplo e o primeiro Administrador).
6. Exponha só a pasta `publico`: `sudo sed -i 's#DocumentRoot /var/www/html#DocumentRoot /var/www/barbearia/publico#' /etc/apache2/sites-available/000-default.conf` e `sudo systemctl restart apache2`.
7. Duração das sessões (evita que o Ubuntu apague as sessões ao fim de 24 minutos): `sudo sed -i 's/^session.gc_maxlifetime = .*/session.gc_maxlifetime = 28800/' /etc/php/*/apache2/php.ini` e `sudo systemctl restart apache2`.
8. Abra `http://localhost/` (cliente) e `http://localhost/admin/entrar.html` (pessoal).

Nota: com a raiz do Apache em `publico`, os endereços não levam `/barbearia/publico`.

## API (resumo)
Pedidos para `publico/api/index.php?r=<rota>`. Os pedidos que alteram dados exigem POST, JSON e o cabeçalho `X-CSRF-Token`.
`sessao` (GET), `entrar`, `sair`, `registar`, `utilizadores` (GET lista, POST cria), `utilizadores_alternar`,
`servicos_publicos` (GET, aberta), `servicos` (GET lista, POST cria), `servicos_editar`, `servicos_alternar` (só Administrador),
`clientes` (GET lista com `q` e `pagina`, POST regista) e `clientes_editar` (Administrador e Funcionário),
`barbeiros` (GET, qualquer pessoa com sessão), `atendimentos` (GET histórico, POST regista), `atendimentos_estado`, `fila` (pessoal),
`minha_area` (GET) e `entrar_na_fila` (POST) (cliente).

## Testes
Com uma base de dados recém-instalada e o servidor a correr (o Administrador de teste é `admin@teste.com` / `senhaforte1`):
`bash testes/teste_etapa2.sh <endereço>` (49 verificações) `bash testes/teste_etapa3.sh <endereço>` (52 verificações) `bash testes/teste_etapa4.sh <endereço>` (58 verificações) e `bash testes/teste_etapa5.sh <endereço>` (88 verificações).
`testes/navegador_simulado.js` percorre as páginas reais como um navegador (86 verificações; requer Node e `npm i jsdom@24`).

## Se volta sempre à página de entrada
1. **Use sempre o mesmo endereço.** As sessões são guardadas por endereço: `localhost`, `127.0.0.1` e o IP da rede são três sites diferentes para o navegador. Entre e navegue sempre pelo mesmo.
2. **Teste a sessão.** Abra `http://localhost/barbearia/publico/api/index.php?r=sessao`. Sem ter entrado deve mostrar `"utilizador":null`; depois de entrar deve mostrar o seu nome. Se mostrar uma página de erro ou ficar em branco, o problema é no Apache/PHP/MySQL (veja `C:\xampp\apache\logs\error.log`). Se continuar a mostrar `null` depois de entrar, o navegador não está a guardar o cookie (verifique se bloqueia cookies) ou a pasta `C:\xampp\tmp` não existe ou não tem permissão de escrita.
3. **Pasta antiga.** Se copiou esta versão por cima de uma anterior, apague a pasta `barbearia` antiga antes de copiar. Ficheiros `index.php` antigos em `publico/` têm prioridade sobre os `index.html` novos.
4. **Duração da sessão:** 8 horas (`sessao_horas` em `config/configuracao.php`). Antes, o XAMPP apagava a sessão ao fim de 24 minutos de inatividade.
5. Se já tem sessão ativa, as páginas de entrada levam direto ao painel.

## Serviços e preços (etapa 3)
- O Administrador adiciona, edita, ativa e desativa serviços em `publico/admin/servicos.html`. Pede confirmação ao alterar um preço e ao desativar.
- O preço é sempre maior que zero, com até 2 casas decimais (aceita vírgula). Os nomes são únicos.
- A página do cliente (`publico/`) mostra só os serviços ativos, lidos da API.
- Se já tinha a base instalada, volte a executar `sql\instalar.php`: cria os 5 serviços de exemplo (preços do enunciado) se a tabela estiver vazia.

## Clientes (etapa 4)
- Administrador e Funcionário registam, editam e consultam clientes em `publico/admin/clientes.html`. O cliente com conta de acesso não vê esta página.
- Cada cliente tem ID, nome completo, contacto e data de registo.
- A pesquisa procura por nome ou contacto em simultâneo, ignora maiúsculas e acentos ("joao" encontra "João") e ignora espaços no contacto ("841239876" encontra "84 123 9876"). Os caracteres `%` e `_` contam como texto.
- A lista tem 20 clientes por página, ordenados por nome.
- Clientes registados no balcão não têm conta. Se o cliente tem conta e o pessoal corrige o nome, o nome da conta é atualizado também.

## Atendimentos e fila (etapa 5)
- **Cliente** (`conta/inicio.html`): escolhe o serviço e o barbeiro, vê o preço (calculado pelo sistema, não editável) e entra na fila. Depois acompanha quantas pessoas estão à sua frente, a sua posição e o estado. Vê o histórico dos seus atendimentos. A página atualiza sozinha a cada 10 segundos.
- **Pessoal** (`admin/atendimentos.html`): regista atendimentos (cliente, serviço, barbeiro; o preço aparece sozinho e há confirmação antes de guardar), gere a fila de hoje (Iniciar, Concluir, Cancelar) e consulta o histórico com filtro por estado. O Funcionário vê e gere só os seus; o Administrador vê e gere todos.
- **Regras:** o preço vem sempre do serviço; a fila é por barbeiro e só conta o dia de hoje; cada cliente só pode ter uma entrada ativa; um barbeiro atende uma pessoa de cada vez; só os atendimentos concluídos contam como receita; pedidos em espera de dias anteriores são cancelados automaticamente.
- **Barbeiros disponíveis:** as contas ativas de Administrador e Funcionário.
- A base de dados não muda nesta etapa. O fuso horário da ligação passa a ser o de Maputo (UTC+2).

## Marcações (extra acrescentado a pedido)
- **Cliente** (`conta/inicio.html`): marca serviço, barbeiro, dia e hora (até 90 dias), vê o preço e a duração, consulta as suas marcações e cancela as futuras.
- **Pessoal** (`admin/agendamentos.html`): consulta todas as marcações (só leitura).
- O servidor impede duas marcações sobrepostas para o mesmo barbeiro; o preço vem sempre do serviço.
- Base de dados: a tabela `agendamentos` e a coluna `servicos.duracao_minutos` (ver `sql/agendamentos.sql` para quem já tem a base instalada).
- Limitações: as marcações não entram na fila nem nas finanças, e o pessoal ainda não as confirma nem conclui.
- `testes/teste_agendamentos.sh`: 48 verificações.

## Financeiro (pagamentos, receitas, despesas, histórico, relatórios e dashboard)
- **Pagamentos** (`admin/pagamentos.html`, Administrador e Funcionário): lista os atendimentos concluídos ainda por receber e regista o pagamento com o método (numerário, M-Pesa, e-Mola, mKesh, cartão ou transferência). O valor é sempre o preço do atendimento e a data é automática. Um atendimento só tem um pagamento. O Funcionário só regista os seus.
- **Receitas** (`admin/receitas.html`): dinheiro recebido por dia, semana (começa à segunda-feira) ou mês, com filtro por período e total por método de pagamento.
- **Despesas** (`admin/despesas.html`): registar (descrição, valor, data) e consultar com filtro por período e total.
- **Histórico** (`admin/historico.html`): todos os movimentos (entradas = pagamentos, saídas = despesas), com filtros por tipo e período.
- **Relatórios** (`admin/relatorios.html`): compara receitas, despesas e lucro por dia, semana ou mês, com gráfico e totais.
- **Dashboard** (`admin/financas.html`): receitas de hoje, da semana e do mês, despesas e lucro do mês, saldo total, valor por receber e dois gráficos (30 dias e 12 meses).
- Regra: receitas = soma dos pagamentos; lucro (saldo) = receitas - despesas. Só o Administrador vê o financeiro; o Funcionário só vê os pagamentos dos seus atendimentos.
- Base de dados: tabela `pagamentos` (ver `sql/financas.sql` para quem já tem a base instalada).
- `testes/teste_financas.sh`: 123 verificações (precisa de uma base recém-instalada).

## Perfil do utilizador (alteração do utilizador, integrada)
- `conta/perfil.html`: qualquer pessoa com sessão (cliente, Funcionário ou Administrador) vê os seus dados e edita nome e email. O cliente edita também o contacto. O tipo de conta e a senha não mudam aqui. O email não pode pertencer a outra conta. Ao guardar, o nome na sessão atualiza-se.
- Menu com "Início", "Meu Perfil" e rodapé em todas as páginas (`js/interface.js`, `css/estilo.css`, `css/perfil.css`).
- `testes/teste_perfil.sh`: 47 verificações.

## Duração dos serviços (alteração do utilizador, integrada)
- Cada serviço tem a duração em minutos (5 a 240), obrigatória ao criar e editar. É usada nas marcações. A lista pública passa a estar ordenada por nome.

## `criar_admin.php`
- Script de linha de comandos (`php criar_admin.php`) que cria o primeiro Administrador. Recusa-se a correr no navegador.

## Próxima etapa
Etapa 6: despesas e finanças (receitas, despesas e saldo).
