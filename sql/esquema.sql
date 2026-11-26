-- Esquema da base de dados do Sistema de Gestão de Barbearia (MySQL / MariaDB)
CREATE DATABASE IF NOT EXISTS barbearia CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE barbearia;

CREATE TABLE IF NOT EXISTS utilizadores (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nome          VARCHAR(120) NOT NULL,
  email         VARCHAR(120) NOT NULL UNIQUE,
  senha_hash    VARCHAR(255) NOT NULL,
  perfil        ENUM('administrador','funcionario','cliente') NOT NULL,
  ativo         TINYINT(1) NOT NULL DEFAULT 1,
  data_registo  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS clientes (
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nome_completo  VARCHAR(120) NOT NULL,
  contacto       VARCHAR(30)  NOT NULL,
  utilizador_id  INT UNSIGNED NULL UNIQUE,
  data_registo   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_clientes_utilizador FOREIGN KEY (utilizador_id) REFERENCES utilizadores(id),
  INDEX idx_clientes_nome (nome_completo),
  INDEX idx_clientes_contacto (contacto)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS servicos (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nome       VARCHAR(80) NOT NULL UNIQUE,
  descricao  VARCHAR(255) NULL,
  preco      DECIMAL(10,2) NOT NULL,
  duracao_minutos SMALLINT UNSIGNED NOT NULL DEFAULT 30,
  ativo      TINYINT(1) NOT NULL DEFAULT 1,
  CONSTRAINT chk_servicos_preco CHECK (preco > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS atendimentos (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  cliente_id      INT UNSIGNED NOT NULL,
  servico_id      INT UNSIGNED NOT NULL,
  funcionario_id  INT UNSIGNED NOT NULL,
  preco_cobrado   DECIMAL(10,2) NOT NULL,
  estado          ENUM('em_espera','em_atendimento','concluido','cancelado') NOT NULL DEFAULT 'em_espera',
  data_hora       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  concluido_em    DATETIME NULL,
  CONSTRAINT fk_atend_cliente     FOREIGN KEY (cliente_id)     REFERENCES clientes(id),
  CONSTRAINT fk_atend_servico     FOREIGN KEY (servico_id)     REFERENCES servicos(id),
  CONSTRAINT fk_atend_funcionario FOREIGN KEY (funcionario_id) REFERENCES utilizadores(id),
  CONSTRAINT chk_atend_preco CHECK (preco_cobrado > 0),
  INDEX idx_atend_data (data_hora),
  INDEX idx_atend_fila (funcionario_id, estado, data_hora)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS despesas (
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  descricao      VARCHAR(200) NOT NULL,
  valor          DECIMAL(10,2) NOT NULL,
  data_despesa   DATE NOT NULL,
  registado_por  INT UNSIGNED NOT NULL,
  CONSTRAINT fk_despesa_utilizador FOREIGN KEY (registado_por) REFERENCES utilizadores(id),
  CONSTRAINT chk_despesa_valor CHECK (valor > 0),
  INDEX idx_despesas_data (data_despesa)
) ENGINE=InnoDB;

-- Segurança: limite de tentativas de entrada e de registo por IP
CREATE TABLE IF NOT EXISTS tentativas_acesso (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  ip         VARCHAR(45) NOT NULL,
  tipo       ENUM('entrada','registo') NOT NULL,
  criado_em  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_tentativas (ip, tipo, criado_em)
) ENGINE=InnoDB;

-- Marcações (agendamento de dia e hora)
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

-- Pagamentos: o dinheiro recebido por cada atendimento concluído (um pagamento por atendimento)
CREATE TABLE IF NOT EXISTS pagamentos (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  atendimento_id  INT UNSIGNED NOT NULL UNIQUE,
  valor           DECIMAL(10,2) NOT NULL,
  metodo          ENUM('numerario','mpesa','emola','mkesh','cartao','transferencia') NOT NULL,
  data_pagamento  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  registado_por   INT UNSIGNED NOT NULL,
  CONSTRAINT fk_pag_atendimento FOREIGN KEY (atendimento_id) REFERENCES atendimentos(id),
  CONSTRAINT fk_pag_utilizador  FOREIGN KEY (registado_por)  REFERENCES utilizadores(id),
  CONSTRAINT chk_pag_valor CHECK (valor > 0),
  INDEX idx_pag_data (data_pagamento)
) ENGINE=InnoDB;
