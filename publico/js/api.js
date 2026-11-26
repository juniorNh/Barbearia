'use strict';
// Comunicação com o servidor (API em PHP). Nenhum HTML é gerado aqui.
const RAIZ = new URL('../', document.currentScript.src).pathname;

const Api = {
  csrf: null,

  async pedir(rota, metodo = 'GET', corpo = null) {
    const opcoes = { method: metodo, credentials: 'same-origin', headers: {} };
    if (metodo !== 'GET') {
      if (!this.csrf) await this.sessao();
      opcoes.headers['Content-Type'] = 'application/json';
      opcoes.headers['X-CSRF-Token'] = this.csrf;
      opcoes.body = JSON.stringify(corpo || {});
    }
    let resposta;
    try {
      resposta = await fetch(`${RAIZ}api/index.php?r=${rota}`, opcoes);
    } catch {
      throw new Error('Sem ligação ao servidor. Verifique se o Apache e o MySQL estão ativos.');
    }
    const dados = await resposta.json().catch(() => ({}));
    if (!resposta.ok) {
      const erro = new Error(dados.erro || 'Ocorreu um erro. Tente novamente.');
      erro.estado = resposta.status;
      throw erro;
    }
    return dados;
  },

  async sessao() {
    const dados = await this.pedir('sessao');
    this.csrf = dados.csrf;
    return dados;
  },
};
