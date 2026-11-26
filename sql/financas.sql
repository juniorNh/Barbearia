-- Atualização para quem JÁ tem a base de dados "barbearia" instalada.
-- Execute TODO este ficheiro no MySQL Workbench (é seguro repetir: só cria o que não existe).
USE barbearia;

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
