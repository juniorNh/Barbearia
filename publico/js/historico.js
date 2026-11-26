'use strict';
// Histórico de movimentos financeiros (Administrador): entradas e saídas.
(async () => {
  const u = await Interface.exigir(['administrador'], 'admin/entrar.html');
  Fin.submenu(u.perfil, 'historico');
  const filtros = document.getElementById('filtros');
  const corpo = document.getElementById('lista');
  const resumo = document.getElementById('resumo');
  const anterior = document.getElementById('anterior');
  const seguinte = document.getElementById('seguinte');
  let pagina = 1;

  async function carregar() {
    const consulta = Fin.parametros({ tipo: filtros.elements.tipo.value, de: filtros.elements.de.value, ate: filtros.elements.ate.value, pagina });
    const d = await Api.pedir(`financas_historico&${consulta}`);
    if (d.movimentos.length === 0 && d.total > 0 && pagina > 1) { pagina = Math.max(1, Math.ceil(d.total / d.por_pagina)); return carregar(); }
    corpo.replaceChildren(...(d.movimentos.length
      ? d.movimentos.map(m => {
          const entrada = m.tipo === 'entrada';
          return Interface.el('tr', {}, Fin.celula(entrada ? Interface.formatarDataHora(m.data) : Fin.data(m.data)), Fin.celula(entrada ? 'Entrada' : 'Saída'),
            Fin.celula(m.descricao), Fin.celula(entrada ? Fin.rotuloMetodo(m.metodo) : '-'),
            Fin.celula(`${entrada ? '+' : '-'} ${Interface.formatarPreco(m.valor)}`, `valor ${entrada ? 'positivo' : 'negativo'}`));
        })
      : [Fin.vazio(5, 'Sem movimentos neste período.')]));
    document.getElementById('t-entradas').textContent = Interface.formatarPreco(d.entradas);
    document.getElementById('t-saidas').textContent = Interface.formatarPreco(d.saidas);
    const dif = document.getElementById('t-diferenca');
    dif.textContent = Interface.formatarPreco(d.entradas - d.saidas);
    dif.className = d.entradas - d.saidas < 0 ? 'negativo' : 'positivo';
    const inicio = d.total === 0 ? 0 : (pagina - 1) * d.por_pagina + 1;
    const fim = Math.min(pagina * d.por_pagina, d.total);
    resumo.textContent = d.total === 0 ? '0 movimentos' : `A mostrar ${inicio} a ${fim} de ${d.total}`;
    anterior.disabled = pagina <= 1;
    seguinte.disabled = fim >= d.total;
  }

  filtros.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    pagina = 1;
    try { await carregar(); } catch (erro) { Interface.aviso(erro.message); }
  });
  anterior.addEventListener('click', async () => { pagina -= 1; await carregar(); });
  seguinte.addEventListener('click', async () => { pagina += 1; await carregar(); });
  await carregar();
})();
