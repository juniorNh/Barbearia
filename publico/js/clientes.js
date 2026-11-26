'use strict';
// Gestão de clientes (Administrador e Funcionário): registar, editar, pesquisar e consultar.
(async () => {
  await Interface.exigir(['administrador', 'funcionario'], 'admin/entrar.html');
  const form = document.getElementById('form-cliente');
  const corpo = document.getElementById('lista');
  const titulo = document.getElementById('titulo-form');
  const guardar = document.getElementById('guardar');
  const cancelar = document.getElementById('cancelar');
  const busca = document.getElementById('busca');
  const resumo = document.getElementById('resumo');
  const anterior = document.getElementById('anterior');
  const seguinte = document.getElementById('seguinte');
  let pagina = 1;
  let termo = '';
  let emEdicao = null;
  let temporizador = null;

  async function carregar() {
    const parametros = new URLSearchParams({ q: termo, pagina });
    const dados = await Api.pedir(`clientes&${parametros}`);
    if (dados.clientes.length === 0 && dados.total > 0 && pagina > 1) { // página que já não existe
      pagina = Math.max(1, Math.ceil(dados.total / dados.por_pagina));
      return carregar();
    }
    if (dados.clientes.length === 0) {
      const vazio = Interface.el('td', { colspan: '6', class: 'cinza', texto: termo ? 'Nenhum cliente encontrado.' : 'Ainda não há clientes registados.' });
      corpo.replaceChildren(Interface.el('tr', {}, vazio));
    } else {
      corpo.replaceChildren(...dados.clientes.map(linha));
    }
    const inicio = dados.total === 0 ? 0 : (pagina - 1) * dados.por_pagina + 1;
    const fim = Math.min(pagina * dados.por_pagina, dados.total);
    resumo.textContent = dados.total === 0 ? '0 clientes' : `A mostrar ${inicio} a ${fim} de ${dados.total}`;
    anterior.disabled = pagina <= 1;
    seguinte.disabled = fim >= dados.total;
  }

  function linha(c) {
    const editar = Interface.el('button', { class: 'sec pequeno', type: 'button', texto: 'Editar' });
    editar.addEventListener('click', () => iniciarEdicao(c));
    const celulas = [c.id, c.nome_completo, c.contacto, Number(c.tem_conta) ? 'Sim' : 'Não', c.data_registo.slice(0, 10)]
      .map(t => Interface.el('td', { texto: String(t) }));
    return Interface.el('tr', {}, ...celulas, Interface.el('td', {}, editar));
  }

  function iniciarEdicao(c) {
    emEdicao = c;
    form.elements.nome.value = c.nome_completo;
    form.elements.contacto.value = c.contacto;
    titulo.textContent = 'Editar cliente';
    guardar.textContent = 'Guardar alterações';
    cancelar.hidden = false;
    form.scrollIntoView({ behavior: 'smooth' });
    form.elements.nome.focus();
  }

  function terminarEdicao() {
    emEdicao = null;
    form.reset();
    titulo.textContent = 'Novo cliente';
    guardar.textContent = 'Registar cliente';
    cancelar.hidden = true;
  }

  cancelar.addEventListener('click', terminarEdicao);

  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const dados = Object.fromEntries(new FormData(form));
    try {
      if (emEdicao) {
        await Api.pedir('clientes_editar', 'POST', { ...dados, id: Number(emEdicao.id) });
        Interface.aviso('Cliente atualizado com sucesso.', 'sucesso');
      } else {
        await Api.pedir('clientes', 'POST', dados);
        Interface.aviso('Cliente registado com sucesso.', 'sucesso');
      }
      terminarEdicao();
      await carregar();
    } catch (erro) { Interface.aviso(erro.message); }
  });

  busca.addEventListener('input', () => {
    clearTimeout(temporizador);
    temporizador = setTimeout(async () => {
      termo = busca.value.trim();
      pagina = 1;
      try { await carregar(); } catch (erro) { Interface.aviso(erro.message); }
    }, 300);
  });
  anterior.addEventListener('click', async () => { pagina -= 1; await carregar(); });
  seguinte.addEventListener('click', async () => { pagina += 1; await carregar(); });

  await carregar();
})();
