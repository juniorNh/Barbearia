'use strict';

(async () => {
    try {
        // 1. Verificar se existe uma sessão ativa.
        const sessao = await Api.sessao();

        if (!sessao.utilizador) {
            location.href = RAIZ + 'conta/entrar.html';
            return;
        }

        // 2. Construir o menu.
        Interface.menu(sessao);
        Interface.mostrarAvisoGuardado();

        // 3. Buscar os dados reais do perfil à API.
        const resposta = await Api.pedir('perfil');
        const perfil = resposta.perfil;

        // 4. Preparar os elementos da página.
        const formulario = document.getElementById('form-perfil');
        const campoNome = document.getElementById('campo-nome');
        const campoEmail = document.getElementById('campo-email');
        const campoContacto = document.getElementById('campo-contacto');
        const grupoContacto = document.getElementById('grupo-contacto');

        const tipos = {
            cliente: 'Cliente',
            funcionario: 'Funcionário',
            administrador: 'Administrador'
        };

        // 5. Mostrar os dados do utilizador.
        function mostrarPerfil(dados) {
            const nome = dados.nome || 'Utilizador';
            const email = dados.email || 'Email não disponível';
            const tipo = tipos[dados.perfil] || dados.perfil;

            document.getElementById('nome-perfil').textContent = nome;
            document.getElementById('email-perfil').textContent = email;
            document.getElementById('tipo-perfil').textContent = tipo;

            document.getElementById('avatar').textContent =
                nome.trim().charAt(0).toUpperCase();

            document.getElementById('dado-nome').textContent = nome;
            document.getElementById('dado-email').textContent = email;
            document.getElementById('dado-tipo').textContent = tipo;
            document.getElementById('dado-id').textContent = dados.id || '-';

            campoNome.value = nome;
            campoEmail.value = email;

            if (dados.perfil === 'cliente') {
                grupoContacto.hidden = false;
                campoContacto.value = dados.contacto || '';
            } else {
                grupoContacto.hidden = true;
            }
        }

        mostrarPerfil(perfil);

        // 6. Mostrar a página depois de carregar os dados.
        document.getElementById('conteudo').hidden = false;

        // 7. Guardar as alterações.
        formulario.addEventListener('submit', async (evento) => {
            evento.preventDefault();

            const botao = formulario.querySelector('button[type="submit"]');
            botao.disabled = true;
            botao.textContent = 'A guardar...';

            try {
                const dados = {
                    nome: campoNome.value.trim(),
                    email: campoEmail.value.trim(),
                    contacto: campoContacto.value.trim()
                };

                const resultado = await Api.pedir('perfil', 'POST', dados);

                // Atualizar a página com os dados devolvidos pela API.
                mostrarPerfil(resultado.perfil);

                Interface.aviso(
                    'Os teus dados foram atualizados com sucesso.',
                    'sucesso'
                );

            } catch (erro) {
                Interface.aviso(erro.message, 'erro');

            } finally {
                botao.disabled = false;
                botao.textContent = 'Guardar alterações';
            }
        });

    } catch (erro) {
        if (erro.estado === 401) {
            location.href = RAIZ + 'conta/entrar.html';
            return;
        }

        Interface.aviso(erro.message, 'erro');
    }
})();
