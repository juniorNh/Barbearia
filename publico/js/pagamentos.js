'use strict';
// Pagamentos: o pessoal regista o dinheiro recebido dos atendimentos concluídos.
(async () => {
  const eu = await Interface.exigir(['administrador', 'funcionario'], 'admin/entrar.html');
  Fin.submenu(eu.perfil, 'pagamentos');
  const corpoPorReceber = document.getElementById('por-receber');
  const corpo = document.getElementById('pagamentos');
  const resumo = document.getElementById('resumo');
  const anterior = document.getElementById('anterior');
  const seguinte = document.getElementById('seguinte');
  let pagina = 1;

  async function carregarPorReceber() {
    const { atendimentos } = await Api.pedir('por_receber');
    if (atendimentos.length === 0) { corpoPorReceber.replaceChildren(Fin.vazio(7, 'Não há pagamentos por receber.')); return; }
    corpoPorReceber.replaceChildren(...atendimentos.map(a => {
      const metodo = Interface.el('select', { 'aria-label': `Método de pagamento de ${a.cliente}` },
        ...Object.entries(Fin.METODOS).map(([v, t]) => Interface.el('option', { value: v, texto: t })));
      const registar = Interface.el('button', { class: 'pequeno', type: 'button', texto: 'Registar pagamento' });
      registar.addEventListener('click', async () => {
        const rotulo = Fin.rotuloMetodo(metodo.value);
        if (!window.confirm(`Registar o pagamento?\n\nCliente: ${a.cliente}\nServiço: ${a.servico}\nValor: ${Interface.formatarPreco(a.valor)}\nMétodo: ${rotulo}`)) return;
        try {
          await Api.pedir('pagamentos', 'POST', { atendimento_id: Number(a.id), metodo: metodo.value });
          Interface.aviso('Pagamento registado.', 'sucesso');
        } catch (erro) { Interface.aviso(erro.message); }
        await Promise.all([carregarPorReceber(), carregar()]);
      });
      return Interface.el('tr', {}, Fin.celula(a.concluido_em ? Interface.formatarDataHora(a.concluido_em) : '-'), Fin.celula(a.cliente),
        Fin.celula(a.servico), Fin.celula(a.funcionario), Fin.celula(Interface.formatarPreco(a.valor), 'valor'),
        Interface.el('td', {}, metodo), Interface.el('td', {}, registar));
    }));
  }

  async function carregar() {
    const d = await Api.pedir(`pagamentos&pagina=${pagina}`);
    if (d.pagamentos.length === 0 && d.total > 0 && pagina > 1) { pagina = Math.max(1, Math.ceil(d.total / d.por_pagina)); return carregar(); }
    corpo.replaceChildren(...(d.pagamentos.length
      ? d.pagamentos.map(p => Interface.el('tr', {}, Fin.celula(Interface.formatarDataHora(p.data_pagamento)), Fin.celula(p.cliente), Fin.celula(p.servico),
          Fin.celula(p.funcionario), Fin.celula(Fin.rotuloMetodo(p.metodo)), Fin.celula(Interface.formatarPreco(p.valor), 'valor')))
      : [Fin.vazio(6, 'Ainda não há pagamentos registados.')]));
    const inicio = d.total === 0 ? 0 : (pagina - 1) * d.por_pagina + 1;
    const fim = Math.min(pagina * d.por_pagina, d.total);
    resumo.textContent = d.total === 0 ? '0 pagamentos' : `A mostrar ${inicio} a ${fim} de ${d.total}. Total: ${Interface.formatarPreco(d.soma)}`;
    anterior.disabled = pagina <= 1;
    seguinte.disabled = fim >= d.total;
  }

  anterior.addEventListener('click', async () => { pagina -= 1; await carregar(); });
  seguinte.addEventListener('click', async () => { pagina += 1; await carregar(); });
  await Promise.all([carregarPorReceber(), carregar()]);
})();
