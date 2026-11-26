'use strict';
// Atendimentos e fila (Administrador e Funcionário).
(async () => {
  const eu = await Interface.exigir(['administrador', 'funcionario'], 'admin/entrar.html');
  const ehAdmin = eu.perfil === 'administrador';
  const form = document.getElementById('form-atendimento');
  const buscaCliente = document.getElementById('busca-cliente');
  const selCliente = document.getElementById('cliente');
  const selServico = document.getElementById('servico');
  const selBarbeiro = document.getElementById('barbeiro');
  const precoServico = document.getElementById('preco-servico');
  const corpoFila = document.getElementById('fila');
  const corpoHistorico = document.getElementById('historico');
  const filtroEstado = document.getElementById('filtro-estado');
  const resumo = document.getElementById('resumo');
  const anterior = document.getElementById('anterior');
  const seguinte = document.getElementById('seguinte');
  let servicos = [];
  let barbeiros = [];
  let pagina = 1;
  let temporizador = null;

  const opcao = (valor, texto) => Interface.el('option', { value: String(valor), texto });

  // ---------- Novo atendimento ----------
  async function carregarClientes() {
    const parametros = new URLSearchParams({ q: buscaCliente.value.trim(), pagina: 1 });
    const { clientes } = await Api.pedir(`clientes&${parametros}`);
    selCliente.replaceChildren(...(clientes.length
      ? clientes.map(c => opcao(c.id, `${c.nome_completo} (${c.contacto})`))
      : [opcao('', 'Nenhum cliente encontrado')]));
  }

  async function carregarListas() {
    ({ servicos } = await Api.pedir('servicos_publicos'));
    ({ barbeiros } = await Api.pedir('barbeiros'));
    const servicoEscolhido = selServico.value;
    const barbeiroEscolhido = selBarbeiro.value;
    selServico.replaceChildren(...servicos.map(s => opcao(s.id, s.nome)));
    if ([...selServico.options].some(o => o.value === servicoEscolhido)) selServico.value = servicoEscolhido;
    if (ehAdmin) {
      selBarbeiro.replaceChildren(...barbeiros.map(b => opcao(b.id, `${b.nome} (${b.na_fila} na fila)`)));
      if ([...selBarbeiro.options].some(o => o.value === barbeiroEscolhido)) selBarbeiro.value = barbeiroEscolhido;
    } else {
      selBarbeiro.replaceChildren(opcao(eu.id, eu.nome)); // o Funcionário regista sempre na sua fila
      selBarbeiro.disabled = true;
    }
    mostrarPreco();
  }

  // O preço aparece sozinho ao escolher o serviço. Não é um campo editável.
  function mostrarPreco() {
    const s = servicos.find(x => String(x.id) === selServico.value);
    precoServico.textContent = s ? Interface.formatarPreco(s.preco) : '-';
  }
  selServico.addEventListener('change', mostrarPreco);

  buscaCliente.addEventListener('input', () => {
    clearTimeout(temporizador);
    temporizador = setTimeout(() => carregarClientes().catch(e => Interface.aviso(e.message)), 300);
  });

  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const s = servicos.find(x => String(x.id) === selServico.value);
    const nomeCliente = selCliente.selectedOptions[0]?.textContent || '';
    if (!selCliente.value || !s) { Interface.aviso('Escolha o cliente e o serviço.'); return; }
    const barbeiro = selBarbeiro.selectedOptions[0]?.textContent || '';
    if (!window.confirm(`Registar o atendimento?\n\nCliente: ${nomeCliente}\nServiço: ${s.nome}\nPreço: ${Interface.formatarPreco(s.preco)}\nBarbeiro: ${barbeiro}`)) return;
    const corpo = { cliente_id: Number(selCliente.value), servico_id: Number(selServico.value) };
    if (ehAdmin) corpo.funcionario_id = Number(selBarbeiro.value);
    try {
      await Api.pedir('atendimentos', 'POST', corpo);
      Interface.aviso('Atendimento registado. O cliente entrou na fila.', 'sucesso');
      await Promise.all([carregarFila(), carregarHistorico(), carregarListas()]);
    } catch (erro) { Interface.aviso(erro.message); }
  });

  // ---------- Fila de hoje ----------
  async function carregarFila() {
    const { fila } = await Api.pedir('fila');
    if (fila.length === 0) {
      corpoFila.replaceChildren(Interface.el('tr', {}, Interface.el('td', { colspan: '7', class: 'cinza', texto: 'Ninguém na fila neste momento.' })));
      return;
    }
    corpoFila.replaceChildren(...fila.map(linhaFila));
  }

  function botao(texto, id, acao, pergunta) {
    const b = Interface.el('button', { class: 'sec pequeno', type: 'button', texto });
    b.addEventListener('click', async () => {
      if (pergunta && !window.confirm(pergunta)) return;
      try {
        await Api.pedir('atendimentos_estado', 'POST', { id: Number(id), acao });
        await Promise.all([carregarFila(), carregarHistorico(), carregarListas()]);
      } catch (erro) { Interface.aviso(erro.message); await carregarFila(); }
    });
    return b;
  }

  function linhaFila(a) {
    const acoes = Interface.el('td');
    if (a.estado === 'em_espera') acoes.append(botao('Iniciar', a.id, 'iniciar'), ' ');
    if (a.estado === 'em_atendimento') acoes.append(botao('Concluir', a.id, 'concluir', `Concluir o atendimento de ${a.cliente}? Passa a contar como receita.`), ' ');
    acoes.append(botao('Cancelar', a.id, 'cancelar', `Cancelar o atendimento de ${a.cliente}?`));
    const vez = a.estado === 'em_atendimento' ? 'Agora' : `${Number(a.a_frente) + 1}.º`;
    const celulas = [a.funcionario, vez, a.cliente, a.servico, Interface.formatarPreco(a.preco_cobrado), Interface.rotuloEstado(a.estado)]
      .map(t => Interface.el('td', { texto: t }));
    return Interface.el('tr', { class: `estado-${a.estado}` }, ...celulas, acoes);
  }

  // ---------- Histórico ----------
  async function carregarHistorico() {
    const parametros = new URLSearchParams({ estado: filtroEstado.value, pagina });
    const dados = await Api.pedir(`atendimentos&${parametros}`);
    if (dados.atendimentos.length === 0 && dados.total > 0 && pagina > 1) {
      pagina = Math.max(1, Math.ceil(dados.total / dados.por_pagina));
      return carregarHistorico();
    }
    if (dados.atendimentos.length === 0) {
      corpoHistorico.replaceChildren(Interface.el('tr', {}, Interface.el('td', { colspan: '6', class: 'cinza', texto: 'Sem atendimentos.' })));
    } else {
      corpoHistorico.replaceChildren(...dados.atendimentos.map(a => Interface.el('tr', { class: `estado-${a.estado}` },
        ...[Interface.formatarDataHora(a.data_hora), a.cliente, a.servico, a.funcionario, Interface.formatarPreco(a.preco_cobrado), Interface.rotuloEstado(a.estado)]
          .map(t => Interface.el('td', { texto: t })))));
    }
    const inicio = dados.total === 0 ? 0 : (pagina - 1) * dados.por_pagina + 1;
    const fim = Math.min(pagina * dados.por_pagina, dados.total);
    resumo.textContent = dados.total === 0 ? '0 atendimentos' : `A mostrar ${inicio} a ${fim} de ${dados.total}`;
    anterior.disabled = pagina <= 1;
    seguinte.disabled = fim >= dados.total;
  }

  filtroEstado.addEventListener('change', () => { pagina = 1; carregarHistorico().catch(e => Interface.aviso(e.message)); });
  anterior.addEventListener('click', async () => { pagina -= 1; await carregarHistorico(); });
  seguinte.addEventListener('click', async () => { pagina += 1; await carregarHistorico(); });

  await carregarListas();
  await Promise.all([carregarClientes(), carregarFila(), carregarHistorico()]);
  // A fila muda quando os clientes entram: atualiza sozinha.
  setInterval(() => carregarFila().catch(() => {}), 15000);
})();
