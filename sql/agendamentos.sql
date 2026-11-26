-- Atualização para quem JÁ tem a base de dados "barbearia" instalada.
-- Execute no MySQL Workbench. Corra cada bloco SÓ se o objeto ainda não existir
-- (veja primeiro com: SHOW TABLES;  e  DESCRIBE servicos;).
USE barbearia;

-- BLOCO 1: duração de cada serviço, em minutos (só se a coluna duracao_minutos NÃO existir em servicos)
ALTER TABLE servicos ADD COLUMN duracao_minutos SMALLINT UNSIGNED NOT NULL DEFAULT 30;

-- BLOCO 2: tabela das marcações (seguro repetir: só cria se não existir)
CREATE TABLE IF NOT EXISTS agendamentos (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  cliente_id      INT UNSIGNED NOT NULL,
  servico_id      INT UNSIGNED NOT NULL,
  funcionario_id  INT UNSIGNED NOT NULL,
  preco_cobrado   DECIMAL(10,2) NOT NULL,
  duracao_minutos SMALLINT UNSIGNED NOT NULL,
  data_hora       DATETIME NOT NULL,
  estado          ENUM('pendente','confirmado','concluido','cancelado') NOT NULL DEFAULT 'pendente',
  criado_em       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_agend_cliente     FOREIGN KEY (cliente_id)     REFERENCES clientes(id),
  CONSTRAINT fk_agend_servico     FOREIGN KEY (servico_id)     REFERENCES servicos(id),
  CONSTRAINT fk_agend_funcionario FOREIGN KEY (funcionario_id) REFERENCES utilizadores(id),
  CONSTRAINT chk_agend_preco CHECK (preco_cobrado > 0),
  INDEX idx_agend_barbeiro (funcionario_id, data_hora),
  INDEX idx_agend_cliente (cliente_id)
) ENGINE=InnoDB;
