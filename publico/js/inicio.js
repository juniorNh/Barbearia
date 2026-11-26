'use strict';
// Página inicial: menu e lista pública de serviços e preços.
(async () => {
  Interface.menu(await Api.sessao());
  const caixa = document.getElementById('servicos');
  try {
    const { servicos } = await Api.pedir('servicos_publicos');
    if (servicos.length === 0) {
      caixa.replaceChildren(Interface.el('p', { class: 'cinza', texto: 'De momento não há serviços disponíveis.' }));
      return;
    }
    caixa.replaceChildren(...servicos.map(s => Interface.el('article', { class: 'cartao' },
      Interface.el('h3', { texto: s.nome }),
      Interface.el('p', { class: 'desc', texto: s.descricao || '' }),
      Interface.el('p', { class: 'preco', texto: Interface.formatarPreco(s.preco) }))));
  } catch (erro) {
    caixa.replaceChildren(Interface.el('p', { class: 'aviso erro', texto: erro.message }));
  }
})();
