'use strict';
// Área do cliente: entrar na fila, marcar para outro dia e acompanhar a vez.
(async () => {
  const u = await Interface.exigir(['cliente'], 'conta/entrar.html');
  document.getElementById('nome').textContent = u.nome;
  const cartaoVez = document.getElementById('vez');
  const detalheVez = document.getElementById('vez-detalhe');
  const form = document.getElementById('form-fila');
  const selServico = document.getElementById('servico');
  const selBarbeiro = document.getElementById('barbeiro');
  const precoServico = document.getElementById('preco-servico');
  const corpoHistorico = document.getElementById('historico');
  const formMarcacao = document.getElementById('form-marcacao');
  const mServico = document.getElementById('m-servico');
  const mBarbeiro = document.getElementById('m-barbeiro');
  const mData = document.getElementById('m-data');
  const mPreco = document.getElementById('m-preco');
  const corpoMarcacoes = document.getElementById('marcacoes');
  let servicos = [];

  const opcao = (valor, texto) => Interface.el('option', { value: String(valor), texto });
  const linhaInfo = (rotulo, valor, classe = '') => Interface.el('p', {},
    Interface.el('span', { class: 'cinza', texto: `${rotulo}: ` }), Interface.el('span', { class: classe, texto: valor }));

  // Preenche uma lista mantendo o que a pessoa já tinha escolhido.
  function preencher(select, opcoes) {
    const escolhido = select.value;
    select.replaceChildren(...opcoes);
    if ([...select.options].some(o => o.value === escolhido)) select.value = escolhido;
  }

  async function carregarOpcoes() {
    ({ servicos } = await Api.pedir('servicos_publicos'));
    const { barbeiros } = await Api.pedir('barbeiros');
    preencher(selServico, servicos.map(s => opcao(s.id, s.nome)));
    preencher(selBarbeiro, barbeiros.map(b => opcao(b.id, `${b.nome} (${b.na_fila} na fila)`)));
    preencher(mServico, servicos.map(s => opcao(s.id, s.nome)));
    preencher(mBarbeiro, barbeiros.map(b => opcao(b.id, b.nome)));
    mostrarPreco();
  }

  // O preço aparece sozinho ao escolher o serviço. O cliente não o escreve nem o altera.
  function mostrarPreco() {
    const preco = (select) => {
      const s = servicos.find(x => String(x.id) === select.value);
      return s ? Interface.formatarPreco(s.preco) : '-';
    };
    precoServico.textContent = preco(selServico);
    mPreco.textContent = preco(mServico);
  }
  selServico.addEventListener('change', mostrarPreco);
  mServico.addEventListener('change', mostrarPreco);

  function mostrarVez(a) {
    const emAtendimento = a.estado === 'em_atendimento';
    const aFrente = Number(a.a_frente);
    const destaque = emAtendimento
      ? `É a sua vez: está a ser atendido por ${a.funcionario}.`
      : aFrente === 0 ? 'É o próximo a ser atendido.'
      : `Tem ${aFrente} ${aFrente === 1 ? 'pessoa' : 'pessoas'} à sua frente.`;
    detalheVez.replaceChildren(
      Interface.el('p', { class: 'destaque', texto: destaque }),
      linhaInfo('Serviço', a.servico),
      linhaInfo('Preço', Interface.formatarPreco(a.preco_cobrado)),
      linhaInfo('Barbeiro', a.funcionario),
      linhaInfo('Estado', Interface.rotuloEstado(a.estado)),
      emAtendimento ? '' : linhaInfo('Posição na fila', `${aFrente + 1}.º`));
  }

  async function carregar() {
    const dados = await Api.pedir('minha_area');
    cartaoVez.hidden = !dados.ativo;
    form.hidden = !!dados.ativo;
    if (dados.ativo) mostrarVez(dados.ativo);
    await carregarOpcoes();
    corpoHistorico.replaceChildren(...(dados.historico.length
      ? dados.historico.map(a => Interface.el('tr', { class: `estado-${a.estado}` },
          ...[Interface.formatarDataHora(a.data_hora), a.servico, a.funcionario, Interface.formatarPreco(a.preco_cobrado), Interface.rotuloEstado(a.estado)]
            .map(t => Interface.el('td', { texto: t }))))
      : [Interface.el('tr', {}, Interface.el('td', { colspan: '5', class: 'cinza', texto: 'Ainda não tem atendimentos.' }))]));
  }

  // ---------- Marcações ----------
  const dois = (n) => String(n).padStart(2, '0');
  const paraCampo = (d) => `${d.getFullYear()}-${dois(d.getMonth() + 1)}-${dois(d.getDate())}T${dois(d.getHours())}:${dois(d.getMinutes())}`;
  function limitesData() { // de agora até 90 dias (o servidor volta a validar)
    const agora = new Date();
    mData.min = paraCampo(agora);
    mData.max = paraCampo(new Date(agora.getTime() + 90 * 24 * 3600 * 1000));
  }

  async function carregarMarcacoes() {
    const { agendamentos } = await Api.pedir('agendamentos_meus');
    if (agendamentos.length === 0) {
      corpoMarcacoes.replaceChildren(Interface.el('tr', {}, Interface.el('td', { colspan: '7', class: 'cinza', texto: 'Ainda não tem marcações.' })));
      return;
    }
    corpoMarcacoes.replaceChildren(...agendamentos.map(a => {
      const acao = Interface.el('td');
      const futura = new Date(a.data_hora.replace(' ', 'T')) > new Date();
      if ((a.estado === 'pendente' || a.estado === 'confirmado') && futura) {
        const cancelar = Interface.el('button', { class: 'sec pequeno', type: 'button', texto: 'Cancelar' });
        cancelar.addEventListener('click', async () => {
          if (!window.confirm(`Cancelar a marcação de ${Interface.formatarDataHora(a.data_hora)} (${a.servico})?`)) return;
          try {
            await Api.pedir('agendamentos_cancelar', 'POST', { id: Number(a.id) });
            Interface.aviso('Marcação cancelada.', 'sucesso');
          } catch (erro) { Interface.aviso(erro.message); }
          await carregarMarcacoes();
        });
        acao.append(cancelar);
      }
      const celulas = [Interface.formatarDataHora(a.data_hora), a.servico, a.funcionario, `${a.duracao_minutos} min`,
        Interface.formatarPreco(a.preco_cobrado), Interface.rotuloEstado(a.estado)].map(t => Interface.el('td', { texto: t }));
      return Interface.el('tr', { class: `estado-${a.estado}` }, ...celulas, acao);
    }));
  }

  formMarcacao.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const s = servicos.find(x => String(x.id) === mServico.value);
    if (!s || !mData.value) { Interface.aviso('Escolha o serviço e a data e hora.'); return; }
    const barbeiro = mBarbeiro.selectedOptions[0]?.textContent || '';
    if (!window.confirm(`Confirmar a marcação?\n\nServiço: ${s.nome}\nPreço: ${Interface.formatarPreco(s.preco)}\nBarbeiro: ${barbeiro}\nData e hora: ${mData.value.replace('T', ' ')}`)) return;
    try {
      await Api.pedir('agendamentos_criar', 'POST', {
        servico_id: Number(mServico.value), funcionario_id: Number(mBarbeiro.value), data_hora: mData.value });
      Interface.aviso('Marcação registada.', 'sucesso');
      mData.value = '';
    } catch (erro) { Interface.aviso(erro.message); }
    await carregarMarcacoes();
  });

  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const s = servicos.find(x => String(x.id) === selServico.value);
    if (!s) { Interface.aviso('Escolha o serviço.'); return; }
    const barbeiro = selBarbeiro.selectedOptions[0]?.textContent || '';
    if (!window.confirm(`Entrar na fila?\n\nServiço: ${s.nome}\nPreço: ${Interface.formatarPreco(s.preco)}\nBarbeiro: ${barbeiro}`)) return;
    try {
      await Api.pedir('entrar_na_fila', 'POST', { servico_id: Number(selServico.value), funcionario_id: Number(selBarbeiro.value) });
      Interface.aviso('Entrou na fila.', 'sucesso');
    } catch (erro) { Interface.aviso(erro.message); }
    await carregar();
  });

  limitesData();
  await carregar();
  await carregarMarcacoes();
  // Acompanha a vez: atualiza sozinho enquanto a página estiver aberta.
  setInterval(() => carregar().catch(() => {}), 10000);
})();
