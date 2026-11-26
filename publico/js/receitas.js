'use strict';
// Receitas por dia, semana ou mês (Administrador).
(async () => {
  const u = await Interface.exigir(['administrador'], 'admin/entrar.html');
  Fin.submenu(u.perfil, 'receitas');
  const filtros = document.getElementById('filtros');
  const corpo = document.getElementById('lista');
  const corpoMetodos = document.getElementById('metodos');
  let primeira = true;

  async function carregar() {
    // Ao mudar o agrupamento, volta ao período por defeito desse agrupamento.
    const consulta = Fin.parametros({ agrupar: filtros.elements.agrupar.value, de: primeira ? '' : filtros.elements.de.value, ate: primeira ? '' : filtros.elements.ate.value });
    const s = await Api.pedir(`financas_serie&${consulta}`);
    primeira = false;
    filtros.elements.de.value = s.de;
    filtros.elements.ate.value = s.ate;
    corpo.replaceChildren(...s.periodos.map(p => Interface.el('tr', {}, Fin.celula(Fin.periodoLongo(s.agrupar, p.periodo)),
      Fin.celula(p.pagamentos, 'valor'), Fin.celula(Interface.formatarPreco(p.receitas), 'valor'))));
    document.getElementById('t-receitas').textContent = Interface.formatarPreco(s.totais.receitas);
    document.getElementById('t-pagamentos').textContent = String(s.totais.pagamentos);
    Graficos.barras(document.getElementById('grafico'), s.periodos.map(p => Fin.periodo(s.agrupar, p.periodo)),
      [{ nome: 'Receitas', classe: 'g-receitas', legenda: 'l-receitas', valores: s.periodos.map(p => p.receitas) }], null,
      `Receitas por ${{ dia: 'dia', semana: 'semana', mes: 'mês' }[s.agrupar]}`);
    corpoMetodos.replaceChildren(...(s.por_metodo.length
      ? s.por_metodo.map(m => Interface.el('tr', {}, Fin.celula(Fin.rotuloMetodo(m.metodo)), Fin.celula(m.n, 'valor'), Fin.celula(Interface.formatarPreco(m.valor), 'valor')))
      : [Fin.vazio(3, 'Sem pagamentos neste período.')]));
  }

  filtros.elements.agrupar.addEventListener('change', () => { primeira = true; carregar().catch(e => Interface.aviso(e.message)); });
  filtros.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    try { await carregar(); } catch (erro) { Interface.aviso(erro.message); }
  });
  await carregar();
})();
