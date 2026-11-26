'use strict';
// Gráficos simples em SVG, sem bibliotecas. Os mesmos números aparecem também nas tabelas.
const Graficos = {
  NS: 'http://www.w3.org/2000/svg',

  no(nome, atributos = {}, texto = null) {
    const e = document.createElementNS(this.NS, nome);
    for (const [k, v] of Object.entries(atributos)) e.setAttribute(k, String(v));
    if (texto !== null) e.textContent = texto;
    return e;
  },

  compacto(valor) {
    return new Intl.NumberFormat('pt-PT', { notation: 'compact', maximumFractionDigits: 1 }).format(valor);
  },

  /**
   * Barras agrupadas (uma por série) e, opcionalmente, uma linha por cima (por exemplo o lucro).
   * categorias: ['01/11', ...]   series: [{ nome, classe, valores }]   linha: { nome, classe, valores } | null
   */
  barras(contentor, categorias, series, linha = null, descricao = '') {
    const L = 720, A = 280, m = { e: 56, d: 12, t: 14, b: 34 };
    const valores = [...series.flatMap(s => s.valores), ...(linha ? linha.valores : [])];
    let max = Math.max(0, ...valores);
    let min = Math.min(0, ...valores);
    if (max === min) max = min + 1;
    const y = (v) => m.t + (A - m.t - m.b) * (1 - (v - min) / (max - min));
    const n = categorias.length;
    const largura = (L - m.e - m.d) / Math.max(n, 1);
    const barra = Math.max(2, (largura * 0.72) / series.length);
    const svg = this.no('svg', { viewBox: `0 0 ${L} ${A}`, role: 'img', 'aria-label': descricao || 'Gráfico' });
    svg.append(this.no('title', {}, descricao || 'Gráfico'));
    for (let i = 0; i <= 4; i++) { // linhas de referência
      const v = min + ((max - min) * i) / 4;
      svg.append(this.no('line', { x1: m.e, x2: L - m.d, y1: y(v), y2: y(v), class: 'g-eixo' }));
      svg.append(this.no('text', { x: m.e - 6, y: y(v) + 4, 'text-anchor': 'end', class: 'g-texto' }, this.compacto(v)));
    }
    if (min < 0) svg.append(this.no('line', { x1: m.e, x2: L - m.d, y1: y(0), y2: y(0), class: 'g-zero' }));
    const passo = Math.ceil(n / 10); // evita rótulos por cima uns dos outros
    categorias.forEach((nome, i) => {
      const x0 = m.e + i * largura + (largura - barra * series.length) / 2;
      series.forEach((s, j) => {
        const v = s.valores[i];
        const topo = y(Math.max(v, 0)), base = y(Math.min(v, 0));
        svg.append(this.no('rect', { x: x0 + j * barra, y: topo, width: barra - 1, height: Math.max(base - topo, v === 0 ? 0 : 1), class: s.classe }));
      });
      if (i % passo === 0) svg.append(this.no('text', { x: m.e + i * largura + largura / 2, y: A - 12, 'text-anchor': 'middle', class: 'g-texto' }, nome));
    });
    if (linha && n > 0) {
      const ponto = (v, i) => `${m.e + i * largura + largura / 2},${y(v)}`;
      svg.append(this.no('polyline', { points: linha.valores.map(ponto).join(' '), class: linha.classe }));
      linha.valores.forEach((v, i) => svg.append(this.no('circle', { cx: m.e + i * largura + largura / 2, cy: y(v), r: 2.5, class: 'g-ponto' })));
    }
    const legenda = document.createElement('div');
    legenda.className = 'legenda';
    for (const s of [...series, ...(linha ? [linha] : [])]) {
      const marca = document.createElement('i');
      marca.className = s.legenda;
      const item = document.createElement('span');
      item.append(marca, s.nome);
      legenda.append(item);
    }
    contentor.replaceChildren(svg, legenda);
  },
};
