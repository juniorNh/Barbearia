'use strict';
// Despesas (Administrador): registar e consultar os gastos da barbearia.
(async () => {
  const u = await Interface.exigir(['administrador'], 'admin/entrar.html');
  Fin.submenu(u.perfil, 'despesas');
  const form = document.getElementById('form-despesa');
  const filtros = document.getElementById('filtros');
  const corpo = document.getElementById('lista');
  const resumo = document.getElementById('resumo');
  const anterior = document.getElementById('anterior');
  const seguinte = document.getElementById('seguinte');
  let pagina = 1;

  const dois = (n) => String(n).padStart(2, '0');
  const hoje = () => { const d = new Date(); return `${d.getFullYear()}-${dois(d.getMonth() + 1)}-${dois(d.getDate())}`; };
  form.elements.data_despesa.value = hoje();
  form.elements.data_despesa.max = hoje();

  async function carregar() {
    const consulta = Fin.parametros({ de: filtros.elements.de.value, ate: filtros.elements.ate.value, pagina });
    const d = await Api.pedir(`despesas&${consulta}`);
    if (d.despesas.length === 0 && d.total > 0 && pagina > 1) { pagina = Math.max(1, Math.ceil(d.total / d.por_pagina)); return carregar(); }
    corpo.replaceChildren(...(d.despesas.length
      ? d.despesas.map(x => Interface.el('tr', {}, Fin.celula(Fin.data(x.data_despesa)), Fin.celula(x.descricao), Fin.celula(x.registado_por),
          Fin.celula(Interface.formatarPreco(x.valor), 'valor')))
      : [Fin.vazio(4, 'Sem despesas neste período.')]));
    const inicio = d.total === 0 ? 0 : (pagina - 1) * d.por_pagina + 1;
    const fim = Math.min(pagina * d.por_pagina, d.total);
    resumo.textContent = d.total === 0 ? '0 despesas' : `A mostrar ${inicio} a ${fim} de ${d.total}. Total: ${Interface.formatarPreco(d.soma)}`;
    anterior.disabled = pagina <= 1;
    seguinte.disabled = fim >= d.total;
  }

  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const dados = Object.fromEntries(new FormData(form));
    const valor = Number(String(dados.valor).replace(',', '.'));
    if (Number.isFinite(valor) && !window.confirm(`Registar a despesa?\n\n${dados.descricao}\nValor: ${Interface.formatarPreco(valor)}\nData: ${Fin.data(dados.data_despesa)}`)) return;
    try {
      await Api.pedir('despesas', 'POST', dados);
      Interface.aviso('Despesa registada.', 'sucesso');
      form.reset();
      form.elements.data_despesa.value = hoje();
      pagina = 1;
      await carregar();
    } catch (erro) { Interface.aviso(erro.message); }
  });
  filtros.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    pagina = 1;
    try { await carregar(); } catch (erro) { Interface.aviso(erro.message); }
  });
  anterior.addEventListener('click', async () => { pagina -= 1; await carregar(); });
  seguinte.addEventListener('click', async () => { pagina += 1; await carregar(); });
  await carregar();
})();
