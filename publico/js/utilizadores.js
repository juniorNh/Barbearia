'use strict';
// Gestão de utilizadores do pessoal (Administrador).
(async () => {
  const eu = await Interface.exigir(['administrador'], 'admin/entrar.html');
  const ROTULO = { administrador: 'Administrador', funcionario: 'Funcionário' };
  const corpo = document.getElementById('lista');

  async function carregar() {
    const { utilizadores } = await Api.pedir('utilizadores');
    corpo.replaceChildren(...utilizadores.map(linha));
  }

  function linha(u) {
    const celulas = [u.nome, u.email, ROTULO[u.perfil], u.ativo === '1' || u.ativo === 1 ? 'Ativo' : 'Desativado', u.data_registo.slice(0, 10)]
      .map(t => Interface.el('td', { texto: t }));
    const acao = Interface.el('td');
    if (Number(u.id) !== eu.id) {
      const ativo = Number(u.ativo) === 1;
      const botao = Interface.el('button', { class: 'sec pequeno', type: 'button', texto: ativo ? 'Desativar' : 'Ativar' });
      botao.addEventListener('click', async () => {
        const pergunta = ativo ? 'Desativar esta conta? A pessoa deixa de poder entrar.' : 'Reativar esta conta?';
        if (!window.confirm(pergunta)) return;
        try {
          await Api.pedir('utilizadores_alternar', 'POST', { id: Number(u.id) });
          Interface.aviso('Estado da conta atualizado.', 'sucesso');
          await carregar();
        } catch (erro) { Interface.aviso(erro.message); }
      });
      acao.append(botao);
    }
    return Interface.el('tr', {}, ...celulas, acao);
  }

  const form = document.getElementById('form-utilizador');
  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    try {
      await Api.pedir('utilizadores', 'POST', Object.fromEntries(new FormData(form)));
      form.reset();
      Interface.aviso('Utilizador criado com sucesso.', 'sucesso');
      await carregar();
    } catch (erro) { Interface.aviso(erro.message); }
  });

  await carregar();
})();
