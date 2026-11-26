'use strict';
(async () => {
  const u = await Interface.exigir(['administrador', 'funcionario'], 'admin/entrar.html');
  document.getElementById('nome').textContent = u.nome;
  document.getElementById('perfil').textContent = u.perfil === 'administrador' ? 'Administrador' : 'Funcionário';
})();
