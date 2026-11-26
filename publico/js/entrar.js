'use strict';
// Entrada (usada pela área do cliente e pela área do pessoal).
(async () => {
  const sessao = await Api.sessao();
  Interface.menu(sessao);
  Interface.mostrarAvisoGuardado();
  const form = document.getElementById('form-entrar');
  const area = form.dataset.area;

  // TESTE
  console.log('Área:', area);
  console.log('Email:', form.elements.email.value);
  // Já tem sessão ativa nesta área: segue direto para o painel, sem pedir a senha outra vez.
  const u = sessao.utilizador;
  if (u && (area === 'admin') === (u.perfil !== 'cliente')) {
    location.href = RAIZ + (area === 'admin' ? 'admin/painel.html' : 'conta/inicio.html');
    return;
  }
  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const botao = form.querySelector('button[type=submit]');
    botao.disabled = true;
    try {
      const dados = await Api.pedir('entrar', 'POST', { area, email: form.elements.email.value, senha: form.elements.senha.value });
      Api.csrf = dados.csrf;
      location.href = RAIZ + (area === 'admin' ? 'admin/painel.html' : 'conta/inicio.html');
    } catch (erro) {
      Interface.aviso(erro.message);
      botao.disabled = false;
    }
  });
})();
