-- Check newly Inserted Goods' price and stock
DROP TRIGGER IF EXISTS `ex3`.`Insert_Bill_Info`;
DELIMITER $$
CREATE TRIGGER `ex3`.`Insert_Bill_Info` BEFORE INSERT ON `ex3`.`Bill_Info`  FOR EACH ROW
        BEGIN
            DECLARE goods_stock INT;
            SELECT Goods.Goods_Stock into goods_stock from Goods where Goods.Goods_Id = NEW.Goods_Id;

            IF (NEW.Goods_Num > Goods_Stock) THEN
                signal SQLSTATE '45000' SET message_text = "Out of stock!";
            END IF;

            UPDATE Goods SET Goods.Goods_Stock = Goods_Stock - NEW.Goods_Num;
        EnD
        $$
DELIMITER ;