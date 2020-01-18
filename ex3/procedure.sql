-- Author: Yi Lyu
-- Email:	isablla_aus_china@sjtu.edu.cn
-- Date:	2019.12.08

USE `ex3` ;

-- Insert User
DROP PROCEDURE IF EXISTS `ex3`.`Insert_User_legal`;
DELIMITER $$
CREATE PROCEDURE `ex3`.`Insert_User_legal`()
	BEGIN
		INSERT INTO `ex3`.`User` VALUES
			(1, 'A', 'Alice11', '0', 'Dongchuan 800', '0'),
            (2, 'B', 'Tom22', '1', 'Meichuan 300', '0');
    END
$$
DELIMITER ;

-- Insert Goods
DROP PROCEDURE IF EXISTS `ex3`.`Insert_Goods_legal`;
DELIMITER $$
CREATE PROCEDURE `ex3`.`Insert_Goods_legal`()
	BEGIN
		INSERT INTO `ex3`.`Goods` VALUES
			(1, 'Biscuit', 3.2,  50),
			(2, 'Juice', 6.3, 100),
			(3, 'Dress', 110, 200);
    END
$$
DELIMITER ;

-- Insert Cart_Info
DROP PROCEDURE IF EXISTS `ex3`.`Insert_Cart_Info_legal`;
DELIMITER $$
CREATE PROCEDURE `ex3`.`Insert_Cart_Info_legal`()
	BEGIN
		INSERT INTO `ex3`.`Cart_Info`(Cart_Info_Id, Cart_Id, Goods_Id, Goods_Num) VALUES
			(5, 1, 1, 4),
            (6,  2, 2, 20),
            (7, 1, 2, 180);			-- This should be ignored
    END
$$
DELIMITER ;

-- Insert Bill
DROP PROCEDURE IF EXISTS `ex3`.`Insert_Bill_legal`;
DELIMITER $$
CREATE PROCEDURE `ex3`.`Insert_Bill_legal`()
	BEGIN
		INSERT INTO `ex3`.`Bill` (Bill_Id, Cart_Id, User_Id) VALUES
			(1, 1, 1);
  END
$$
DELIMITER ;



-- Test User Insertion
CALL `ex3`.`Insert_User_legal`;
# CALL `ex3`.`Insert_User_illegal`;

-- Test Goods Insertion
CALL `ex3`.`Insert_Goods_legal`;
# CALL `mydb`.`Insert_Goods_illegal`;