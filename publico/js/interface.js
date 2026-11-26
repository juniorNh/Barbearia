'use strict';

// Elementos comuns da interface: menu, avisos e controlo de acesso nas páginas.
const Interface = {

  // Criar elementos HTML.
  el(etiqueta, atributos = {}, ...filhos) {
    const e = document.createElement(etiqueta);

    for (const [k, v] of Object.entries(atributos)) {
      if (k === 'texto') {
        e.textContent = v;
      } else {
        e.setAttribute(k, v);
      }
    }

    filhos.forEach(f => e.append(f));

    return e;
  },

  // Estados utilizados no sistema.
  ROTULOS_ESTADO: {
    em_espera: 'Em espera',
    em_atendimento: 'Em atendimento',
    concluido: 'Concluído',
    cancelado: 'Cancelado',
    pendente: 'Pendente',
    confirmado: 'Confirmado'
  },

  // Converter o estado para um texto legível.
  rotuloEstado(estado) {
    return this.ROTULOS_ESTADO[estado] || estado;
  },

  // Formatar data e hora.
  formatarDataHora(texto) {
    return String(texto).slice(0, 16);
  },

  // Formatar preços.
  formatarPreco(valor) {
    return new Intl.NumberFormat('pt-PT', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(Number(valor)) + ' MT';
  },

  // Mostrar avisos na página.
  aviso(texto, tipo = 'erro') {
    const caixa = document.getElementById('aviso');

    caixa.replaceChildren(
      this.el('div', {
        class: `aviso ${tipo}`,
        role: tipo === 'erro' ? 'alert' : 'status',
        texto
      })
    );
  },

  // Guardar aviso temporariamente.
  guardarAviso(texto, tipo = 'sucesso') {
    sessionStorage.setItem(
      'aviso',
      JSON.stringify({ texto, tipo })
    );
  },

  // Mostrar aviso guardado.
  mostrarAvisoGuardado() {
    const g = sessionStorage.getItem('aviso');

    if (!g) return;

    sessionStorage.removeItem('aviso');

    const { texto, tipo } = JSON.parse(g);

    this.aviso(texto, tipo);
  },

  // Construir o cabeçalho conforme a pessoa e o seu perfil.
  menu(sessao) {

    const u = sessao.utilizador;

    const ligacao = (texto, destino) =>
      this.el('a', {
        href: RAIZ + destino,
        texto
      });

    const nav = this.el('nav', {
      'aria-label': 'Navegação principal'
    });

    const pessoal = u && u.perfil !== 'cliente';

    // Menu dos funcionários e administradores.
    if (pessoal) {

      nav.append(
        ligacao('Início', 'index.html'),
        ligacao('Painel', 'admin/painel.html'),
        ligacao('Clientes', 'admin/clientes.html'),
        ligacao('Atendimentos', 'admin/atendimentos.html'),
        ligacao('Marcações', 'admin/agendamentos.html'),
        ligacao('Pagamentos', 'admin/pagamentos.html')
      );

      // Opções exclusivas do administrador.
      if (u.perfil === 'administrador') {

        nav.append(
          ligacao('Serviços', 'admin/servicos.html'),
          ligacao('Utilizadores', 'admin/utilizadores.html'),
          ligacao('Financeiro', 'admin/financas.html')
        );

      }

      nav.append(ligacao('Meu Perfil', 'conta/perfil.html'));

    }

    // Menu do cliente.
    else if (u) {

      nav.append(
        ligacao('Início', 'index.html'),
        ligacao('A minha área', 'conta/inicio.html'),
        ligacao('Meu Perfil', 'conta/perfil.html')
      );

    }

    // Menu dos visitantes.
    else {

      nav.append(
        ligacao('Início', 'index.html'),
        ligacao('Entrar', 'conta/entrar.html'),
        ligacao('Criar conta', 'conta/registar.html')
      );

    }

    // Botão para terminar sessão.
    if (u) {

      const sair = this.el('button', {
        class: 'sec pequeno',
        type: 'button',
        texto: 'Sair'
      });

      sair.addEventListener('click', async () => {

        try {
          const dados = await Api.pedir('sair', 'POST');

          Api.csrf = dados.csrf;

          location.href = RAIZ + 'index.html';

        } catch (erro) {

          this.aviso(erro.message);

        }

      });

      nav.append(sair);

    }

    // Logótipo: sempre direciona para a página inicial.
    const logo = this.el('a', {
      class: 'logo',
      href: RAIZ + 'index.html',
      texto: 'Djuzzy Barber'
    });

    document.getElementById('topo').replaceChildren(logo, nav);

    this.footer();

  },

  // Criar o rodapé do sistema.
  footer() {

    const rodape = this.el('footer', {
      class: 'rodape'
    });

    // Área da marca.
    const marca = this.el('div', {
      class: 'rodape-marca'
    });

    marca.append(

      this.el('a', {
        class: 'logo',
        href: RAIZ + 'index.html',
        texto: 'Djuzzy Barber'
      }),

      this.el('p', {
        texto: 'O teu estilo, a nossa prioridade.'
      })

    );

    // Navegação.
    const navegacao = this.el('div', {
      class: 'rodape-links'
    });

    navegacao.append(

      this.el('h3', {
        texto: 'Navegação'
      }),

      this.el('a', {
        href: RAIZ + 'index.html',
        texto: 'Início'
      }),

      this.el('a', {
        href: RAIZ + 'conta/inicio.html',
        texto: 'Área do cliente'
      }),

      this.el('a', {
        href: RAIZ + 'conta/perfil.html',
        texto: 'Meu perfil'
      })

    );

    // Parte inferior.
    const inferior = this.el('div', {
      class: 'rodape-inferior'
    });

    inferior.append(

      this.el('p', {
        texto: `© ${new Date().getFullYear()} Djuzzy Barber. Todos os direitos reservados.`
      }),

      this.el('span', {
        class: 'rodape-assinatura',
        texto: 'ESTILO • PRECISÃO • QUALIDADE'
      })

    );

    rodape.append(marca, navegacao, inferior);

    // Colocar o rodapé no final da página.
    document.body.append(rodape);

  },

  // Para páginas protegidas:
  // Sem sessão vai para a entrada.
  // Com perfil errado mostra "Acesso negado".
  exigir(perfis, paginaEntrar) {

    return (async () => {

      const sessao = await Api.sessao();

      if (!sessao.utilizador) {

        location.href = RAIZ + paginaEntrar;

        return new Promise(() => {});

      }

      this.menu(sessao);

      if (!perfis.includes(sessao.utilizador.perfil)) {

        document.getElementById('conteudo').replaceChildren(

          this.el('p', {
            class: 'aviso erro',
            texto: 'Acesso negado.'
          })

        );

        return new Promise(() => {});

      }

      return sessao.utilizador;

    })();

  }

};
