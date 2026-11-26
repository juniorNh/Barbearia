'use strict';
// Gestão de serviços e preços (Administrador).
(async () => {
  await Interface.exigir(['administrador'], 'admin/entrar.html');
  const form = document.getElementById('form-servico');
  const corpo = document.getElementById('lista');
  const titulo = document.getElementById('titulo-form');
  const guardar = document.getElementById('guardar');
  const cancelar = document.getElementById('cancelar');
  let emEdicao = null; // serviço que está a ser editado

  async function carregar() {
    const { servicos } = await Api.pedir('servicos');
    corpo.replaceChildren(...servicos.map(linha));
  }

  function linha(s) {
    const ativo = Number(s.ativo) === 1;

    const editar = Interface.el('button', {
        class: 'sec pequeno',
        type: 'button',
        texto: 'Editar'
    });

    editar.addEventListener('click', () => iniciarEdicao(s));

    const alternar = Interface.el('button', {
        class: 'sec pequeno',
        type: 'button',
        texto: ativo ? 'Desativar' : 'Ativar'
    });

    alternar.addEventListener('click', async () => {
        const pergunta = ativo
            ? `Desativar "${s.nome}"? Deixa de aparecer na página do cliente.`
            : `Ativar "${s.nome}"? Passa a aparecer na página do cliente.`;

        if (!window.confirm(pergunta)) return;

        try {
            await Api.pedir('servicos_alternar', 'POST', {
                id: Number(s.id)
            });

            Interface.aviso('Estado do serviço atualizado.', 'sucesso');

            await carregar();

        } catch (erro) {
            Interface.aviso(erro.message);
        }
    });

    // Dados do serviço, incluindo a duração.
    const celulas = [
        s.nome,
        s.descricao || '',
        Interface.formatarPreco(s.preco),
        `${s.duracao_minutos} minutos`,
        ativo ? 'Ativo' : 'Desativado'
    ].map(t => Interface.el('td', { texto: t }));

    // Construir a linha da tabela.
    const linhaServico = Interface.el(
        'tr',
        ativo ? {} : { class: 'mudo' },
        ...celulas,
        Interface.el('td', {}, editar, ' ', alternar)
    );

    return linhaServico;
}
  function iniciarEdicao(s) {
    emEdicao = s;
    form.elements.nome.value = s.nome;
    form.elements.descricao.value = s.descricao || '';
    form.elements.preco.value = String(s.preco).replace('.', ',');
    titulo.textContent = 'Editar serviço';
    guardar.textContent = 'Guardar alterações';
    cancelar.hidden = false;
    form.scrollIntoView({ behavior: 'smooth' });
    form.elements.nome.focus();
    form.elements.duracao_minutos.value =
    s.duracao_minutos;
  }

  function terminarEdicao() {
    emEdicao = null;
    form.reset();
    titulo.textContent = 'Novo serviço';
    guardar.textContent = 'Adicionar serviço';
    cancelar.hidden = true;
  }

  cancelar.addEventListener('click', terminarEdicao);

  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const dados = Object.fromEntries(new FormData(form));
    try {
      if (emEdicao) {
        const novo = Number(dados.preco.replace(',', '.'));
        if (Number.isFinite(novo) && novo !== Number(emEdicao.preco)) {
          const pergunta = `Alterar o preço de "${emEdicao.nome}" de ${Interface.formatarPreco(emEdicao.preco)} para ${Interface.formatarPreco(novo)}?`;
          if (!window.confirm(pergunta)) return;
        }
        await Api.pedir('servicos_editar', 'POST', { ...dados, id: Number(emEdicao.id) });
        Interface.aviso('Serviço atualizado com sucesso.', 'sucesso');
      } else {
        await Api.pedir('servicos', 'POST', dados);
        Interface.aviso('Serviço adicionado com sucesso.', 'sucesso');
      }
      terminarEdicao();
      await carregar();
    } catch (erro) { Interface.aviso(erro.message); }
  });

  await carregar();
})();
