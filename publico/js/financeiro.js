'use strict';
// Apoio às páginas financeiras: nomes, datas e submenu.
const Fin = {
  METODOS: { numerario: 'Numerário', mpesa: 'M-Pesa', emola: 'e-Mola', mkesh: 'mKesh', cartao: 'Cartão', transferencia: 'Transferência' },
  rotuloMetodo(m) { return this.METODOS[m] || m || '-'; },

  // 2026-11-21 -> 21/11/2026
  data(texto) { const [a, m, d] = String(texto).slice(0, 10).split('-'); return `${d}/${m}/${a}`; },

  // Rótulo curto de um período da série.
  periodo(agrupar, chave) {
    if (agrupar === 'mes') { const [a, m] = chave.split('-'); return `${m}/${a.slice(2)}`; }
    const [, m, d] = chave.split('-');
    return agrupar === 'semana' ? `sem. ${d}/${m}` : `${d}/${m}`;
  },
  periodoLongo(agrupar, chave) {
    if (agrupar === 'mes') { const [a, m] = chave.split('-'); return `${m}/${a}`; }
    return agrupar === 'semana' ? `Semana de ${this.data(chave)}` : this.data(chave);
  },

  // Submenu das páginas financeiras (só o Administrador).
  submenu(perfil, atual) {
    const caixa = document.getElementById('submenu');
    if (!caixa) return;
    if (perfil !== 'administrador') { caixa.hidden = true; return; }
    const itens = [['financas', 'Dashboard'], ['pagamentos', 'Pagamentos'], ['receitas', 'Receitas'],
      ['despesas', 'Despesas'], ['historico', 'Histórico'], ['relatorios', 'Relatórios']];
    caixa.replaceChildren(...itens.map(([id, texto]) => {
      const a = Interface.el('a', { href: `${RAIZ}admin/${id === 'financas' ? 'financas' : id}.html`, texto });
      if (id === atual) a.className = 'ativo';
      return a;
    }));
  },

  parametros(obj) {
    const p = new URLSearchParams();
    for (const [k, v] of Object.entries(obj)) if (v !== '' && v != null) p.set(k, v);
    return p.toString();
  },

  celula(texto, classe = '') { return Interface.el('td', classe ? { class: classe, texto: String(texto) } : { texto: String(texto) }); },
  vazio(colunas, texto) { return Interface.el('tr', {}, Interface.el('td', { colspan: String(colunas), class: 'cinza', texto })); },
};
