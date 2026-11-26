'use strict';
// Dashboard financeiro (Administrador): indicadores e gráficos.
(async () => {
  const u = await Interface.exigir(['administrador'], 'admin/entrar.html');
  Fin.submenu(u.perfil, 'financas');
  const por = (id, valor, classe) => {
    const e = document.getElementById(id);
    e.textContent = Interface.formatarPreco(valor);
    if (classe) e.className = valor < 0 ? 'negativo' : 'positivo';
  };

  const r = await Api.pedir('financas_resumo');
  por('c-hoje', r.receitas_hoje);
  por('c-semana', r.receitas_semana);
  por('c-mes', r.receitas_mes);
  por('c-despesas-mes', r.despesas_mes);
  por('c-lucro-mes', r.lucro_mes, true);
  por('c-saldo', r.saldo, true);
  por('c-por-receber', r.por_receber);
  document.getElementById('c-n-por-receber').textContent =
    r.n_por_receber === 0 ? 'Nada em atraso' : `${r.n_por_receber} ${r.n_por_receber === 1 ? 'atendimento' : 'atendimentos'}`;

  async function grafico(agrupar, id, descricao) {
    const s = await Api.pedir(`financas_serie&agrupar=${agrupar}`);
    Graficos.barras(document.getElementById(id), s.periodos.map(p => Fin.periodo(agrupar, p.periodo)),
      [{ nome: 'Receitas', classe: 'g-receitas', legenda: 'l-receitas', valores: s.periodos.map(p => p.receitas) },
       { nome: 'Despesas', classe: 'g-despesas', legenda: 'l-despesas', valores: s.periodos.map(p => p.despesas) }],
      { nome: 'Lucro', classe: 'g-lucro', legenda: 'l-lucro', valores: s.periodos.map(p => p.lucro) }, descricao);
  }
  await grafico('dia', 'grafico-dias', 'Receitas, despesas e lucro dos últimos 30 dias');
  await grafico('mes', 'grafico-meses', 'Receitas, despesas e lucro dos últimos 12 meses');
})();
