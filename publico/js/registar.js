'use strict';
// Criação de conta de cliente.
(async () => {
  Interface.menu(await Api.sessao());
  const form = document.getElementById('form-registar');
  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const botao = form.querySelector('button[type=submit]');
    botao.disabled = true;
    try {
      await Api.pedir('registar', 'POST', Object.fromEntries(new FormData(form)));
      Interface.guardarAviso('Conta criada com sucesso. Já pode entrar.');
      location.href = RAIZ + 'conta/entrar.html';
    } catch (erro) {
      Interface.aviso(erro.message);
      botao.disabled = false;
    }
  });
})();
