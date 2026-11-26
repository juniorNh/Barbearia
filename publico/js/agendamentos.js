'use strict';
// Marcações dos clientes (só consulta), para o Administrador e o Funcionário.
(async () => {
  await Interface.exigir(['administrador', 'funcionario'], 'admin/entrar.html');
  const corpo = document.getElementById('lista');
  const filtro = document.getElementById('filtro-estado');
  const resumo = document.getElementById('resumo');

  async function carregar() {
    const { agendamentos } = await Api.pedir('agendamentos_pessoal');
    const lista = filtro.value ? agendamentos.filter(a => a.estado === filtro.value) : agendamentos;
    if (lista.length === 0) {
      corpo.replaceChildren(Interface.el('tr', {}, Interface.el('td', { colspan: '7', class: 'cinza', texto: 'Sem marcações.' })));
    } else {
      corpo.replaceChildren(...lista.map(a => Interface.el('tr', { class: `estado-${a.estado}` },
        ...[Interface.formatarDataHora(a.data_hora), a.cliente, a.servico, a.funcionario, `${a.duracao_minutos} min`,
          Interface.formatarPreco(a.preco_cobrado), Interface.rotuloEstado(a.estado)].map(t => Interface.el('td', { texto: t })))));
    }
    resumo.textContent = `${lista.length} ${lista.length === 1 ? 'marcação' : 'marcações'}`;
  }

  filtro.addEventListener('change', () => carregar().catch(e => Interface.aviso(e.message)));
  await carregar();
})();
