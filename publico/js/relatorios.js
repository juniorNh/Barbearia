'use strict';
// Relatório: compara receitas, despesas e lucro por período (Administrador).
(async () => {
  const u = await Interface.exigir(['administrador'], 'admin/entrar.html');
  Fin.submenu(u.perfil, 'relatorios');
  const filtros = document.getElementById('filtros');
  const corpo = document.getElementById('lista');
  let primeira = true;


  async function carregar() {
    const consulta = Fin.parametros({ agrupar: filtros.elements.agrupar.value, de: primeira ? '' : filtros.elements.de.value, ate: primeira ? '' : filtros.elements.ate.value });
    const s = await Api.pedir(`financas_serie&${consulta}`);
    primeira = false;
    filtros.elements.de.value = s.de;
    filtros.elements.ate.value = s.ate;
    const linha = (rotulo, r, d, l) => {
      const lucro = Fin.celula(Interface.formatarPreco(l), 'valor');
      if (l < 0) lucro.className = 'valor negativo';
      return Interface.el('tr', {}, Fin.celula(rotulo), Fin.celula(Interface.formatarPreco(r), 'valor'), Fin.celula(Interface.formatarPreco(d), 'valor'), lucro);
    };
    corpo.replaceChildren(...s.periodos.map(p => linha(Fin.periodoLongo(s.agrupar, p.periodo), p.receitas, p.despesas, p.lucro)),
      linha('Total', s.totais.receitas, s.totais.despesas, s.totais.lucro));
    corpo.lastElementChild.className = 'estado-em_atendimento';
    document.getElementById('t-receitas').textContent = Interface.formatarPreco(s.totais.receitas);
    document.getElementById('t-despesas').textContent = Interface.formatarPreco(s.totais.despesas);
    const lucro = document.getElementById('t-lucro');
    lucro.textContent = Interface.formatarPreco(s.totais.lucro);
    lucro.className = s.totais.lucro < 0 ? 'negativo' : 'positivo';
    Graficos.barras(document.getElementById('grafico'), s.periodos.map(p => Fin.periodo(s.agrupar, p.periodo)),
      [{ nome: 'Receitas', classe: 'g-receitas', legenda: 'l-receitas', valores: s.periodos.map(p => p.receitas) },
       { nome: 'Despesas', classe: 'g-despesas', legenda: 'l-despesas', valores: s.periodos.map(p => p.despesas) }],
      { nome: 'Lucro', classe: 'g-lucro', legenda: 'l-lucro', valores: s.periodos.map(p => p.lucro) },
      `Receitas, despesas e lucro por ${{ dia: 'dia', semana: 'semana', mes: 'mês' }[s.agrupar]}`);
  }

  filtros.elements.agrupar.addEventListener('change', () => { primeira = true; carregar().catch(e => Interface.aviso(e.message)); });
  filtros.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    try { await carregar(); } catch (erro) { Interface.aviso(erro.message); }
  });
  await carregar();
})();
