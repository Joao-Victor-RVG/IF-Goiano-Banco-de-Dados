
CREATE DATABASE Atividade03;

USE Atividade03;


CREATE TABLE CLIENTE (
    codcliente INT PRIMARY KEY,
    nome VARCHAR(100),
    datanascimento DATE,
    cpf VARCHAR(11)
);

CREATE TABLE PRODUTO (
    codproduto INT PRIMARY KEY,
    descricao VARCHAR(100),
    quantidade INT
);

CREATE TABLE PEDIDO (
    codpedido INT PRIMARY KEY,
    codcliente INT,
    datapedido DATE,
    nf VARCHAR(20),
    valortotal DECIMAL(10, 2),
    FOREIGN KEY (codcliente) REFERENCES CLIENTE(codcliente)
);

CREATE TABLE ITEMPEDIDO (
    codpedido INT,
    numeroitem INT,
    valorunitario DECIMAL(10, 2),
    quantidade INT,
    codproduto INT,
    PRIMARY KEY (codpedido, numeroitem),
    FOREIGN KEY (codpedido) REFERENCES PEDIDO(codpedido),
    FOREIGN KEY (codproduto) REFERENCES PRODUTO(codproduto)
);

CREATE TABLE LOG (
    codlog INT PRIMARY KEY,
    data DATE,
    descricao TEXT
);

CREATE TABLE REQUISICAO_COMPRA (
    codrequisicaocompra INT PRIMARY KEY,
    codproduto INT,
    data DATE,
    quantidade INT,
    status VARCHAR(20)
);


INSERT INTO CLIENTE (codcliente, nome, datanascimento, cpf) VALUES
(1, 'João', '1990-05-15', '12345678900'),
(2, 'Maria', '1985-09-20', '98765432100'),
(3, 'Pedro', '1995-03-10', '45678912300'),
(4, 'Ana', '1982-07-25', '78912345600'),
(5, 'Carlos', '1978-12-03', '32165498700');


INSERT INTO PRODUTO (codproduto, descricao, quantidade) VALUES
(1, 'Produto A', 100),
(2, 'Produto B', 150),
(3, 'Produto C', 200),
(4, 'Produto D', 80),
(5, 'Produto E', 120);


INSERT INTO PEDIDO (codpedido, codcliente, datapedido, nf, valortotal) VALUES
(1, 1, '2024-04-01', 'NF123', 250.00),
(2, 2, '2024-04-02', 'NF124', 180.50),
(3, 3, '2024-04-03', 'NF125', 320.75),
(4, 4, '2024-04-04', 'NF126', 150.25),
(5, 5, '2024-04-05', 'NF127', 200.00);


INSERT INTO ITEMPEDIDO (codpedido, numeroitem, valorunitario, quantidade, codproduto) VALUES
(1, 1, 25.00, 5, 1),
(1, 2, 30.00, 3, 2),
(2, 1, 15.50, 4, 3),
(3, 1, 40.25, 6, 4),
(4, 1, 20.25, 3, 5);


INSERT INTO LOG (codlog, data, descricao) VALUES
(1, '2024-04-01', 'Log de teste 1'),
(2, '2024-04-02', 'Log de teste 2');


INSERT INTO REQUISICAO_COMPRA (codrequisicaocompra, codproduto, data, quantidade, status) VALUES
(1, 1, '2024-04-01', 20, 'Pendente'),
(2, 2, '2024-04-02', 30, 'Aprovado'),
(3, 3, '2024-04-03', 25, 'Rejeitado');



-- -----------------------------------------------

-- Triggers 1 para 13


-- 1
DELIMITER //
CREATE TRIGGER atualizar_estoque_produto AFTER INSERT ON ITEMPEDIDO
FOR EACH ROW
BEGIN
    UPDATE PRODUTO
    SET quantidade = quantidade - NEW.quantidade
    WHERE codproduto = NEW.codproduto;
END;
//
DELIMITER ;

-- 2
DELIMITER //
CREATE TRIGGER log_modificacoes_cliente AFTER INSERT ON CLIENTE
FOR EACH ROW
BEGIN
    INSERT INTO LOG (data, descricao)
    VALUES (NOW(), CONCAT('Inserindo novo cliente - ', NEW.cpf));
END;
//
DELIMITER ;


-- 3

DELIMITER //
CREATE TRIGGER log_exclusao_cliente AFTER DELETE ON CLIENTE
FOR EACH ROW
BEGIN
    INSERT INTO LOG (data, descricao)
    VALUES (NOW(), CONCAT('Excluindo cliente - ', OLD.cpf));
END;
//
DELIMITER ;


DELIMITER //
CREATE TRIGGER log_atualizacao_produto AFTER UPDATE ON PRODUTO
FOR EACH ROW
BEGIN
    INSERT INTO LOG (data, descricao)
    VALUES (NOW(), CONCAT('Atualizando produto ', OLD.codproduto, ': Quantidade de ', OLD.quantidade, ' para ', NEW.quantidade));
END;
//
DELIMITER ;


-- 4
DELIMITER //
CREATE TRIGGER log_quantidade_insuficiente AFTER INSERT ON ITEMPEDIDO
FOR EACH ROW
BEGIN
    DECLARE estoque INT;
    DECLARE mensagem VARCHAR(255);

    SELECT quantidade INTO estoque FROM PRODUTO WHERE codproduto = NEW.codproduto;


    IF NEW.quantidade > estoque THEN
        SET mensagem = CONCAT('Quantidade insuficiente em estoque para o produto ', NEW.codproduto, '. Quantidade solicitada: ', NEW.quantidade, '. Quantidade disponível em estoque: ', estoque);
        INSERT INTO LOG (data, descricao)
        VALUES (NOW(), mensagem);
    END IF;
END;
//
DELIMITER ;


-- 5

DELIMITER //
CREATE TRIGGER criar_requisicao_compra AFTER INSERT ON PEDIDO
FOR EACH ROW
BEGIN
    DECLARE estoque_atual INT;
    DECLARE venda_mensal INT;
    DECLARE quantidade_requisicao INT;
    DECLARE descricao_requisicao VARCHAR(255);


    SELECT AVG(quantidade) INTO venda_mensal
    FROM (
        SELECT SUM(quantidade) as quantidade
        FROM ITEMPEDIDO
        WHERE datapedido BETWEEN DATE_SUB(CURDATE(), INTERVAL 30 DAY) AND CURDATE()
        GROUP BY MONTH(datapedido)
    ) AS vendas_mensais;

    SELECT quantidade INTO estoque_atual
    FROM PRODUTO
    WHERE codproduto = NEW.codproduto;

    SET quantidade_requisicao = CEILING(venda_mensal * 0.5) - estoque_atual;


    IF quantidade_requisicao > 0 THEN
        SET descricao_requisicao = CONCAT('Requisição de compra gerada automaticamente para o produto ', NEW.codproduto, '. Quantidade requerida: ', quantidade_requisicao);

        INSERT INTO REQUISICAO_COMPRA (codproduto, data, quantidade, status)
        VALUES (NEW.codproduto, CURDATE(), quantidade_requisicao, 'Pendente');

        INSERT INTO LOG (data, descricao)
        VALUES (NOW(), descricao_requisicao);
    END IF;
END;
//
DELIMITER ;


-- 6
DELIMITER //
CREATE TRIGGER log_remocao_itempedido AFTER DELETE ON ITEMPEDIDO
FOR EACH ROW
BEGIN
    INSERT INTO LOG (data, descricao)
    VALUES (NOW(), CONCAT('Remoção do item de pedido - Código do Pedido: ', OLD.codpedido, ', Número do Item: ', OLD.numeroitem));
END;
//
DELIMITER ;

-- 7

DELIMITER //
CREATE TRIGGER log_pedido_valor_maior_1000 AFTER INSERT ON PEDIDO
FOR EACH ROW
BEGIN
    IF NEW.valortotal > 1000.00 THEN
        INSERT INTO LOG (data, descricao)
        VALUES (NOW(), CONCAT('Pedido com valor total maior que R$ 1.000,00 - Código do Pedido: ', NEW.codpedido, ', Valor Total: R$', NEW.valortotal));
    END IF;
END;
//
DELIMITER ;

-- 8

DELIMITER //
CREATE TRIGGER verificar_data_nascimento BEFORE INSERT ON CLIENTE
FOR EACH ROW
BEGIN
    IF NEW.datanascimento > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A data de nascimento não pode ser posterior à data atual.';
    END IF;
END;
//
DELIMITER ;


-- 9
DELIMITER //
CREATE TRIGGER adicionar_saudacao BEFORE INSERT ON CLIENTE
FOR EACH ROW
BEGIN
    DECLARE idade INT;
    SET idade = TIMESTAMPDIFF(YEAR, NEW.datanascimento, CURDATE());
    IF idade > 30 THEN
        -- Adiciona "Sr(a)" ao nome
        SET NEW.nome = CONCAT('Sr(a) ', NEW.nome);
    END IF;
END;
//
DELIMITER ;

-- 10


DELIMITER //
CREATE TRIGGER evitar_itens_repetidos BEFORE INSERT ON ITEMPEDIDO
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM ITEMPEDIDO WHERE codpedido = NEW.codpedido AND numeroitem = NEW.numeroitem) THEN
        -- Dispara uma mensagem de erro indicando que o item já existe no pedido
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Item já existente no pedido.';
    END IF;
END;
//
DELIMITER ;

-- 11

DELIMITER //
CREATE TRIGGER evitar_itens_repetidos BEFORE INSERT ON ITEMPEDIDO
FOR EACH ROW
BEGIN
    -- Verifica se já existe um item com o mesmo código de pedido e número de item
    IF EXISTS (SELECT * FROM ITEMPEDIDO WHERE codpedido = NEW.codpedido AND numeroitem = NEW.numeroitem) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O item já existe no pedido.';
    END IF;
END;
//
DELIMITER ;


-- 12


DELIMITER //
CREATE TRIGGER exibir_mensagem_valor_maximo AFTER INSERT ON PEDIDO
FOR EACH ROW
BEGIN
    IF NEW.valortotal > 100000.00 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O valor total do pedido excedeu R$ 100.000,00.';
    END IF;
END;
//
DELIMITER ;



-- 13
DELIMITER //
CREATE TRIGGER verificar_reabastecimento_estoque AFTER UPDATE ON REQUISICAO_COMPRA
FOR EACH ROW
BEGIN
    DECLARE estoque_atual INT;
    DECLARE venda_mensal INT;
    DECLARE quantidade_requisicao INT;
    DECLARE descricao_mensagem VARCHAR(255);


    IF NEW.status = 'Concluída' THEN
        -- Calcula a quantidade atual em estoque
        SELECT quantidade INTO estoque_atual
        FROM PRODUTO
        WHERE codproduto = NEW.codproduto;


        SELECT AVG(quantidade) INTO venda_mensal
        FROM (
            SELECT SUM(quantidade) as quantidade
            FROM ITEMPEDIDO
            WHERE datapedido BETWEEN DATE_SUB(CURDATE(), INTERVAL 30 DAY) AND CURDATE()
            GROUP BY MONTH(datapedido)
        ) AS vendas_mensais;


        SET quantidade_requisicao = CEILING((venda_mensal * 0.5) - estoque_atual);

        IF quantidade_requisicao > 0 THEN
            SET descricao_mensagem = CONCAT('O estoque do produto ', NEW.codproduto, ' está abaixo de 50% da venda mensal. É necessário reabastecer. Quantidade requerida: ', quantidade_requisicao);
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = descricao_mensagem;
        END IF;
    END IF;
END;
//
DELIMITER ;

