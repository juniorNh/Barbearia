// Simulação de navegador (jsdom) das páginas reais, com cookies de sessão.
const { JSDOM, CookieJar, ResourceLoader, VirtualConsole } = require('jsdom');
const base = 'http://127.0.0.1:8099';
const jar = new CookieJar();
let armazenado = {}; // sessionStorage partilhado entre páginas (mesmo separador)
const espera = (ms) => new Promise(r => setTimeout(r, ms));
let ok = 0, falhas = 0;
const verifica = (nome, cond, extra = '') => { cond ? (ok++, console.log('OK    ' + nome)) : (falhas++, console.log('FALHA ' + nome + ' ' + extra)); };

async function fetchComCookies(url, opcoes = {}) {
  const cabecalhos = { ...(opcoes.headers || {}) };
  const cookies = jar.getCookieStringSync(url);
  if (cookies) cabecalhos.Cookie = cookies;
  const r = await fetch(url, { ...opcoes, headers: cabecalhos, redirect: 'manual' });
  for (const c of r.headers.getSetCookie()) jar.setCookieSync(c, url);
  return r;
}

class Carregador extends ResourceLoader {
  fetch(url, opcoes) { return url.startsWith(base) ? super.fetch(url, opcoes) : null; }
}

async function abrir(caminho) {
  const erros = [];
  const navegacoes = [];
  const consola = new VirtualConsole();
  consola.on('jsdomError', (e) => {
    if (/navigation/i.test(e.message)) navegacoes.push(e.message); else erros.push(e.message);
  });
  consola.on('error', (m) => erros.push(String(m)));
  const dom = await JSDOM.fromURL(base + caminho, {
    runScripts: 'dangerously', resources: new Carregador(), cookieJar: jar, virtualConsole: consola, pretendToBeVisual: true,
    beforeParse(w) {
      w.fetch = (u, o) => fetchComCookies(new URL(u, w.location.href).href, o);
      for (const [k, v] of Object.entries(armazenado)) w.sessionStorage.setItem(k, v);
      w.confirm = () => true;
      w.HTMLElement.prototype.scrollIntoView = () => {};
    },
  });
  await espera(700);
  const w = dom.window, d = w.document;
  w.addEventListener('pagehide', () => {});
  dom.guardar = () => { armazenado = {}; for (let i = 0; i < w.sessionStorage.length; i++) { const k = w.sessionStorage.key(i); armazenado[k] = w.sessionStorage.getItem(k); } };
  return {
    w, d, erros, navegacoes, guardar: () => dom.guardar(),
    texto: (sel) => (d.querySelector(sel)?.textContent || '').trim(),
    todos: (sel) => [...d.querySelectorAll(sel)],
    preencher(form, campos) { for (const [k, v] of Object.entries(campos)) d.querySelector(`${form} [name=${k}]`).value = v; },
    async enviar(form) { d.querySelector(form).dispatchEvent(new w.Event('submit', { bubbles: true, cancelable: true })); await espera(900); dom.guardar(); },
    async clicar(sel) { d.querySelector(sel).click(); await espera(900); dom.guardar(); },
  };
}

(async () => {
  console.log('== Página pública');
  let p = await abrir('/index.html');
  verifica('Sem erros de JavaScript', p.erros.length === 0, p.erros.join(' | '));
  verifica('Mostra 5 serviços com preço', p.todos('.cartao').length === 5 && p.texto('.cartao .preco').includes('MT'), p.texto('#servicos'));
  verifica('Menu mostra Início, Entrar e Criar conta', p.todos('#topo nav a').map(a => a.textContent).join(',') === 'Início,Entrar,Criar conta', p.texto('#topo'));
  verifica('O rodapé aparece uma vez', p.todos('footer.rodape').length === 1, String(p.todos('footer.rodape').length));
  verifica('A página inicial NÃO redireciona para a entrada', p.navegacoes.length === 0);

  console.log('== Registo do cliente');
  p = await abrir('/conta/registar.html');
  p.preencher('#form-registar', { nome: 'Maria Teste', contacto: '841234567', email: 'maria@teste.com', senha: '12345678', senha2: '12345678' });
  await p.enviar('#form-registar');
  verifica('Registo concluído e segue para a entrada', p.navegacoes.length > 0 && p.w.sessionStorage.getItem('aviso')?.includes('Conta criada'), p.texto('#aviso') + p.erros.join('|'));

  console.log('== Entrada do cliente');
  p = await abrir('/conta/entrar.html');
  verifica('Mostra o aviso de conta criada', p.texto('#aviso').includes('Conta criada'), p.texto('#aviso'));
  p.preencher('#form-entrar', { email: 'maria@teste.com', senha: 'errada123' });
  await p.enviar('#form-entrar');
  verifica('Senha errada mostra erro e fica na página', p.texto('#aviso').includes('incorretos') && p.navegacoes.length === 0, p.texto('#aviso'));
  p.preencher('#form-entrar', { email: 'maria@teste.com', senha: '12345678' });
  await p.enviar('#form-entrar');
  verifica('Entrada correta segue para a área do cliente', p.navegacoes.length > 0, p.texto('#aviso'));
  p = await abrir('/conta/entrar.html');
  verifica('Com sessão ativa, a entrada do cliente vai direto para a área do cliente', p.navegacoes.length > 0);
  p = await abrir('/conta/inicio.html');
  verifica('Área do cliente mostra o nome (sem voltar à entrada)', p.texto('#nome') === 'Maria Teste' && p.navegacoes.length === 0, `nome="${p.texto('#nome')}" navegacoes=${p.navegacoes.length} erros=${p.erros.join('|')}`);
  verifica('Menu do cliente: A minha área + Sair', p.texto('#topo nav').includes('A minha área') && p.texto('#topo nav').includes('Sair'), p.texto('#topo'));
  verifica('Área do cliente mostra o formulário para entrar na fila', p.d.querySelector('#form-fila').hidden === false && p.d.querySelector('#vez').hidden === true, p.texto('#conteudo'));
  verifica('O preço aparece sozinho ao escolher o serviço', /\d.*MT/.test(p.texto('#preco-servico')), p.texto('#preco-servico'));
  verifica('O barbeiro mostra o tamanho da fila', p.texto('#barbeiro').includes('na fila'), p.texto('#barbeiro'));
  await p.enviar('#form-fila');
  verifica('Cliente entra na fila e vê a sua vez', p.d.querySelector('#vez').hidden === false && p.d.querySelector('#form-fila').hidden === true && p.texto('#vez-detalhe').includes('próximo') , p.texto('#vez-detalhe') + p.texto('#aviso'));
  verifica('A vez mostra serviço, preço, barbeiro e estado', ['Serviço', 'Preço', 'Barbeiro', 'Em espera'].every(t => p.texto('#vez-detalhe').includes(t)), p.texto('#vez-detalhe'));
  verifica('O pedido aparece no histórico do cliente', p.texto('#historico').includes('Em espera'), p.texto('#historico'));
  const dia = new Date(Date.now() + 3 * 24 * 3600 * 1000); const d2 = (n) => String(n).padStart(2, '0');
  p.d.querySelector('#m-data').value = `${dia.getFullYear()}-${d2(dia.getMonth() + 1)}-${d2(dia.getDate())}T10:00`;
  verifica('Formulário de marcação mostra o preço sozinho', /MT/.test(p.texto('#m-preco')), p.texto('#m-preco'));
  await p.enviar('#form-marcacao');
  verifica('Cliente marca e a marcação aparece na lista', p.texto('#marcacoes').includes('Pendente') && p.texto('#marcacoes').includes('30 min') && p.texto('#aviso').includes('Marcação registada'), p.texto('#marcacoes') + p.texto('#aviso'));
  p.d.querySelector('#m-data').value = `${dia.getFullYear()}-${d2(dia.getMonth() + 1)}-${d2(dia.getDate())}T10:15`;
  await p.enviar('#form-marcacao');
  verifica('Horário ocupado mostra o erro do servidor', p.texto('#aviso').includes('já tem um agendamento'), p.texto('#aviso'));
  await p.clicar('#marcacoes tr button');
  verifica('Cliente cancela a marcação', p.texto('#marcacoes').includes('Cancelado') && p.todos('#marcacoes tr button').length === 0, p.texto('#marcacoes') + p.texto('#aviso'));
  p = await abrir('/conta/perfil.html');
  verifica('Perfil do cliente mostra o nome, o email e o tipo de conta', p.texto('#nome-perfil') === 'Maria Teste' && p.texto('#email-perfil') === 'maria@teste.com' && p.texto('#tipo-perfil') === 'Cliente', p.texto('#nome-perfil') + '|' + p.texto('#email-perfil') + '|' + p.texto('#tipo-perfil') + '|' + p.erros.join(';'));
  verifica('O campo contacto aparece para o cliente e traz o valor guardado', p.d.querySelector('#grupo-contacto').hidden === false && p.d.querySelector('#campo-contacto').value === '841234567', p.d.querySelector('#campo-contacto').value);
  verifica('A página do perfil tem o menu com Meu Perfil e o rodapé', p.texto('#topo nav').includes('Meu Perfil') && p.todos('footer.rodape').length === 1);
  p.d.querySelector('#campo-contacto').value = '849999999';
  await p.enviar('#form-perfil');
  verifica('Guardar o perfil mostra o sucesso e o contacto novo', p.texto('#aviso').includes('atualizados com sucesso') && p.d.querySelector('#campo-contacto').value === '849999999', p.texto('#aviso'));
  p.d.querySelector('#campo-nome').value = 'Jo';
  await p.enviar('#form-perfil');
  verifica('Nome inválido mostra o erro do servidor', p.texto('#aviso').includes('nome completo'), p.texto('#aviso'));
  p = await abrir('/admin/painel.html');
  verifica('Cliente na área do pessoal vê "Acesso negado"', p.texto('#conteudo').includes('Acesso negado'), p.texto('#conteudo'));
  p = await abrir('/conta/inicio.html');
  await p.clicar('#topo nav button');
  verifica('Sair redireciona', p.navegacoes.length > 0);
  p = await abrir('/conta/inicio.html');
  verifica('Depois de sair, a área do cliente manda para a entrada', p.navegacoes.length > 0 && p.texto('#nome') === '', `navegacoes=${p.navegacoes.length}`);

  console.log('== Área do pessoal');
  p = await abrir('/admin/painel.html');
  verifica('Painel sem sessão manda para a entrada do pessoal', p.navegacoes.length > 0);
  p = await abrir('/admin/entrar.html');
  p.preencher('#form-entrar', { email: 'admin@teste.com', senha: 'senhaforte1' });
  await p.enviar('#form-entrar');
  verifica('Administrador entra', p.navegacoes.length > 0, p.texto('#aviso'));
  p = await abrir('/admin/entrar.html');
  verifica('Com sessão ativa, a entrada do pessoal vai direto para o painel', p.navegacoes.length > 0);
  p = await abrir('/admin/painel.html');
  verifica('Painel mostra o nome e o perfil', p.texto('#nome') === 'Admin Teste' && p.texto('#perfil') === 'Administrador', p.texto('#conteudo'));
  verifica('Menu do Administrador: Painel, Serviços, Utilizadores', p.texto('#topo nav').includes('Serviços') && p.texto('#topo nav').includes('Utilizadores'), p.texto('#topo'));
  p = await abrir('/admin/servicos.html');
  verifica('Serviços: tabela com 5 linhas', p.todos('#lista tr').length === 5, `${p.todos('#lista tr').length} erros=${p.erros.join('|')}`);
  p.preencher('#form-servico', { nome: 'Hidratação', descricao: 'Tratamento', preco: '180,50', duracao_minutos: '45' });
  await p.enviar('#form-servico');
  verifica('A tabela de serviços tem tantas colunas no cabeçalho como nas linhas', p.todos('thead th').length === p.todos('#lista tr:first-child td').length && p.texto('thead').includes('Duração'), p.todos('thead th').length + ' vs ' + p.todos('#lista tr:first-child td').length);
  verifica('Adiciona serviço e atualiza a tabela', p.todos('#lista tr').length === 6 && p.texto('#aviso').includes('sucesso'), p.texto('#aviso'));
  await p.clicar('#lista tr:nth-child(1) button');
  verifica('Editar preenche o formulário', p.d.querySelector('#nome').value !== '' && p.texto('#titulo-form') === 'Editar serviço');
  p.d.querySelector('#preco').value = '210';
  await p.enviar('#form-servico');
  verifica('Guardar edição volta ao modo novo serviço', p.texto('#titulo-form') === 'Novo serviço' && p.texto('#aviso').includes('atualizado'), p.texto('#aviso'));
  p = await abrir('/admin/utilizadores.html');
  verifica('Utilizadores: lista o administrador', p.todos('#lista tr').length >= 1 && p.texto('#lista').includes('admin@teste.com'), p.texto('#lista'));
  p.preencher('#form-utilizador', { nome: 'Carlos Barbeiro', email: 'carlos@teste.com', perfil: 'funcionario', senha: 'barbeiro123', senha2: 'barbeiro123' });
  await p.enviar('#form-utilizador');
  verifica('Cria funcionário e atualiza a lista', p.texto('#lista').includes('carlos@teste.com'), p.texto('#aviso'));
  console.log('== Clientes');
  const escrever = async (q, texto) => { const b = q.d.querySelector('#busca'); b.value = texto; b.dispatchEvent(new q.w.Event('input', { bubbles: true })); await espera(1000); };
  p = await abrir('/admin/clientes.html');
  verifica('Clientes: lista mostra a cliente que criou conta', p.texto('#lista').includes('Maria Teste') && p.texto('#resumo').includes('1'), p.texto('#lista') + p.erros.join('|'));
  verifica('Clientes: indica que a Maria tem conta', p.texto('#lista tr').includes('Sim'), p.texto('#lista'));
  p.preencher('#form-cliente', { nome: 'Pedro Machava', contacto: '84 555 1234' });
  await p.enviar('#form-cliente');
  verifica('Regista cliente e atualiza a tabela', p.todos('#lista tr').length === 2 && p.texto('#aviso').includes('registado'), p.texto('#aviso'));
  await escrever(p, 'machava');
  verifica('Pesquisa por nome filtra a lista', p.todos('#lista tr').length === 1 && p.texto('#lista').includes('Pedro Machava'), p.texto('#lista'));
  await escrever(p, '845551234');
  verifica('Pesquisa por contacto (sem espaços) encontra o cliente', p.texto('#lista').includes('Pedro Machava'), p.texto('#lista'));
  await escrever(p, 'zzzz');
  verifica('Pesquisa sem resultados mostra mensagem', p.texto('#lista').includes('Nenhum cliente encontrado') && p.texto('#resumo') === '0 clientes', p.texto('#lista'));
  await escrever(p, '');
  await p.clicar('#lista tr:nth-child(1) button');
  verifica('Editar preenche o formulário', p.d.querySelector('#nome').value === 'Maria Teste' && p.texto('#titulo-form') === 'Editar cliente', p.d.querySelector('#nome').value);
  p.d.querySelector('#nome').value = 'Maria Teste Silva';
  await p.enviar('#form-cliente');
  verifica('Guardar edição atualiza a tabela e volta ao modo novo cliente', p.texto('#lista').includes('Maria Teste Silva') && p.texto('#titulo-form') === 'Novo cliente', p.texto('#aviso'));
  p.preencher('#form-cliente', { nome: 'Jo', contacto: '841234567' });
  await p.enviar('#form-cliente');
  verifica('Dados inválidos mostram erro do servidor', p.texto('#aviso').includes('nome completo'), p.texto('#aviso'));
  verifica('Botão Anterior desativado na primeira página', p.d.querySelector('#anterior').disabled === true && p.d.querySelector('#seguinte').disabled === true);
  p = await abrir('/conta/perfil.html');
  verifica('Perfil do Administrador: tipo de conta e sem campo de contacto', p.texto('#tipo-perfil') === 'Administrador' && p.d.querySelector('#grupo-contacto').hidden === true, p.texto('#tipo-perfil'));
  verifica('O pessoal também vê o Meu Perfil no menu', p.texto('#topo nav').includes('Meu Perfil') && p.texto('#topo nav').includes('Financeiro'), p.texto('#topo'));
  console.log('== Atendimentos e fila (pessoal)');
  p = await abrir('/admin/atendimentos.html');
  verifica('Fila mostra o pedido da Maria', p.todos('#fila tr').length === 1 && p.texto('#fila').includes('Maria Teste'), p.texto('#fila') + p.erros.join('|'));
  verifica('Fila indica a vez e o estado', p.texto('#fila').includes('1.º') && p.texto('#fila').includes('Em espera'), p.texto('#fila'));
  verifica('Formulário mostra o preço do serviço', /MT/.test(p.texto('#preco-servico')), p.texto('#preco-servico'));
  await p.clicar('#fila tr button');
  verifica('Iniciar passa a Em atendimento', p.texto('#fila').includes('Em atendimento') && p.texto('#fila').includes('Agora'), p.texto('#fila') + p.texto('#aviso'));
  const botoes = p.todos('#fila tr button').map(b => b.textContent);
  verifica('Em atendimento oferece Concluir e Cancelar', botoes.includes('Concluir') && botoes.includes('Cancelar') && !botoes.includes('Iniciar'), botoes.join(','));
  await p.clicar('#fila tr button');
  verifica('Concluir tira a pessoa da fila', p.texto('#fila').includes('Ninguém na fila'), p.texto('#fila') + p.texto('#aviso'));
  verifica('Histórico mostra o atendimento concluído', p.texto('#historico').includes('Concluído') && p.texto('#historico').includes('Maria Teste'), p.texto('#historico'));
  p.d.querySelector('#cliente').value = p.d.querySelector('#cliente').options[0].value;
  await p.enviar('#form-atendimento');
  verifica('Registar atendimento coloca o cliente na fila', p.todos('#fila tr').length === 1 && p.texto('#aviso').includes('registado'), p.texto('#fila') + p.texto('#aviso'));
  const sel = p.d.querySelector('#filtro-estado'); sel.value = 'em_espera'; sel.dispatchEvent(new p.w.Event('change', { bubbles: true })); await espera(900);
  verifica('Filtro do histórico por estado', p.todos('#historico tr').length === 1 && p.texto('#historico').includes('Em espera'), p.texto('#historico'));
  console.log('== Marcações (pessoal)');
  p = await abrir('/admin/agendamentos.html');
  verifica('Pessoal vê a marcação do cliente', p.todos('#lista tr').length === 1 && p.texto('#lista').includes('Maria Teste') && p.texto('#lista').includes('Cancelado'), p.texto('#lista') + p.erros.join('|'));
  verifica('Menu do pessoal tem Marcações', p.texto('#topo nav').includes('Marcações'), p.texto('#topo'));
  console.log('== Financeiro (pessoal)');
  p = await abrir('/admin/pagamentos.html');
  verifica('Por receber mostra o atendimento concluído', p.todos('#por-receber tr').length === 1 && p.texto('#por-receber').includes('Maria Teste'), p.texto('#por-receber') + p.erros.join('|'));
  verifica('Há 6 métodos de pagamento para escolher', p.todos('#por-receber select option').length === 6, String(p.todos('#por-receber select option').length));
  verifica('O Administrador vê o submenu financeiro', p.todos('#submenu a').length === 6, p.texto('#submenu'));
  await p.clicar('#por-receber button');
  verifica('Registar pagamento atualiza as duas listas', p.texto('#por-receber').includes('Não há pagamentos por receber') && p.texto('#pagamentos').includes('Maria Teste') && p.texto('#aviso').includes('Pagamento registado'), p.texto('#por-receber') + p.texto('#pagamentos') + p.texto('#aviso'));
  p = await abrir('/admin/despesas.html');
  p.preencher('#form-despesa', { descricao: 'Renda do espaço', valor: '100,50' });
  await p.enviar('#form-despesa');
  verifica('Regista despesa e mostra-a na lista com o total', p.texto('#lista').includes('Renda do espaço') && p.texto('#resumo').includes('100,50') && p.texto('#aviso').includes('Despesa registada'), p.texto('#lista') + p.texto('#resumo') + p.texto('#aviso'));
  p.preencher('#form-despesa', { descricao: 'Renda do espaço', valor: '-3' });
  await p.enviar('#form-despesa');
  verifica('Valor inválido mostra o erro do servidor', p.texto('#aviso').includes('valor válido'), p.texto('#aviso'));
  p = await abrir('/admin/financas.html');
  verifica('Dashboard mostra os indicadores', /MT/.test(p.texto('#c-hoje')) && /MT/.test(p.texto('#c-saldo')) && p.erros.length === 0, p.texto('#c-hoje') + p.erros.join('|'));
  verifica('Dashboard tem os dois gráficos', p.todos('svg').length === 2 && p.todos('svg rect').length > 0, String(p.todos('svg').length));
  verifica('O lucro do mês é receitas menos despesas', p.texto('#c-lucro-mes') === p.texto('#c-saldo'), p.texto('#c-lucro-mes') + ' | ' + p.texto('#c-saldo'));
  p = await abrir('/admin/receitas.html');
  verifica('Receitas: 30 dias e um gráfico', p.todos('#lista tr').length === 30 && p.todos('svg').length === 1, String(p.todos('#lista tr').length) + p.erros.join('|'));
  verifica('Receitas: mostra o método de pagamento usado', p.texto('#metodos').includes('Numerário'), p.texto('#metodos'));
  const agr = p.d.querySelector('#agrupar'); agr.value = 'semana'; agr.dispatchEvent(new p.w.Event('change', { bubbles: true })); await espera(900);
  verifica('Receitas por semana: 12 linhas', p.todos('#lista tr').length === 12, String(p.todos('#lista tr').length));
  agr.value = 'mes'; agr.dispatchEvent(new p.w.Event('change', { bubbles: true })); await espera(900);
  verifica('Receitas por mês: 12 linhas', p.todos('#lista tr').length === 12, String(p.todos('#lista tr').length));
  p = await abrir('/admin/relatorios.html');
  verifica('Relatório: 30 dias mais a linha de total', p.todos('#lista tr').length === 31 && p.texto('#lista tr:last-child').includes('Total'), String(p.todos('#lista tr').length));
  verifica('Relatório: receitas, despesas e lucro nos indicadores', /MT/.test(p.texto('#t-receitas')) && p.texto('#t-despesas').includes('100,50'), p.texto('#t-despesas'));
  verifica('Relatório: gráfico com barras e linha do lucro', p.todos('svg rect').length > 0 && p.todos('svg polyline').length === 1);
  p = await abrir('/admin/historico.html');
  verifica('Histórico: uma entrada e uma saída', p.todos('#lista tr').length === 2 && p.texto('#lista').includes('Entrada') && p.texto('#lista').includes('Saída'), p.texto('#lista'));
  verifica('Histórico: totais de entradas e saídas', /MT/.test(p.texto('#t-entradas')) && p.texto('#t-saidas').includes('100,50'), p.texto('#t-saidas'));
  const tipo = p.d.querySelector('#tipo'); tipo.value = 'saida'; await p.enviar('#filtros');
  verifica('Histórico: filtrar só saídas', p.todos('#lista tr').length === 1 && p.texto('#lista').includes('Renda do espaço'), p.texto('#lista'));
  p = await abrir('/index.html');
  verifica('Serviço novo aparece na página pública', p.texto('#servicos').includes('Hidratação'), p.texto('#servicos'));
  verifica('Menu do pessoal na página inicial inclui Sair', p.texto('#topo nav').includes('Sair'), p.texto('#topo'));

  console.log(`\nResultado: ${ok} passaram, ${falhas} falharam`);
  process.exit(falhas ? 1 : 0);
})().catch(e => { console.error('ERRO NO TESTE', e); process.exit(2); });
