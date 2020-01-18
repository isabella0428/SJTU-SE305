-- Author: Yi Lyu
-- Email:	isablla_aus_china@sjtu.edu.cn
-- Date:	2019.12.08

USE `mydb` ;

-- Insert User
DROP PROCEDURE IF EXISTS `mydb`.`Insert_User_legal`;
DELIMITER $$
CREATE PROCEDURE `mydb`.`Insert_User_legal`()
	BEGIN
		INSERT INTO `mydb`.`User` VALUES
			(1, 'Alice', 'Alice11', '0', 'Dongchuan 800', '0'),
            (2, 'Tom', 'Tom22', '1', 'Meichuan 300', '0');
    END
$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `mydb`.`Insert_User_illegal`;
DELIMITER $$
CREATE PROCEDURE `mydb`.`Insert_User_illegal`()
	BEGIN
		INSERT INTO `mydb`.`User` VALUES
			(3, 'Tracy', 'Tracy', '0', 'Tongchuan 700', '0'),
            (4, 'Tim', 'tim1', '1', 'Heichuan 200', '0'),
			(5, 'TLinda', 'LINDA1', '0', 'Tianchuan 400', '0');
    END
$$
DELIMITER ;

-- Insert Goods
DROP PROCEDURE IF EXISTS `mydb`.`Insert_Goods_legal`;
DELIMITER $$
CREATE PROCEDURE `mydb`.`Insert_Goods_legal`()
	BEGIN
		INSERT INTO `mydb`.`Goods` VALUES
			(1, 'Biscuit', 3.2,  40),
      (2, 'Juice', 6.3, 100),
			(5, 'Dress', 200, 10);
    END
$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `mydb`.`Insert_Goods_illegal`;
DELIMITER $$
CREATE PROCEDURE `mydb`.`Insert_Goods_illegal`()
	BEGIN
		INSERT INTO `mydb`.`Goods` VALUES
 			(3, 'Coca Cola', -2.3, 50),		-- Goods price should be non-negative
            (4, 'Jelly', 3.1, -2);	-- Goods stock should be non-negative
    END
$$
DELIMITER ;

-- Insert Cart_Info
DROP PROCEDURE IF EXISTS `mydb`.`Insert_Cart_Info_legal`;
DELIMITER $$
CREATE PROCEDURE `mydb`.`Insert_Cart_Info_legal`()
	BEGIN
		INSERT INTO `mydb`.`Cart_Info`(Cart_Info_Id, Cart_Id, Goods_Id, Goods_Num) VALUES
			(5, 1, 1, 4),
            (6,  2, 2, 20),
            (7, 1, 2, 180);			-- This should be ignored
    END
$$
DELIMITER ;

-- Insert Cart_Info
DROP PROCEDURE IF EXISTS `mydb`.`Insert_Cart_Info_illegal`;
DELIMITER $$
CREATE PROCEDURE `mydb`.`Insert_Cart_Info_illegal`()
	BEGIN
		INSERT INTO `mydb`.`Cart_Info` (Cart_Info_Id, Cart_Id, Goods_Id, Goods_Num) VALUES
#               (5, 2, 1, -3),				-- Goods Num should be non-negative
              (6, 2, 5, 2);         -- Goods is not available
  END
$$
DELIMITER ;

-- Insert Bill
DROP PROCEDURE IF EXISTS `mydb`.`Insert_Bill_legal`;
DELIMITER $$
CREATE PROCEDURE `mydb`.`Insert_Bill_legal`()
	BEGIN
		INSERT INTO `mydb`.`Bill` (Bill_Id, Cart_Id, User_Id) VALUES
			(1, 1, 1);
  END
$$
DELIMITER ;

-- Bulk Buying(Goods Price under 100)
DROP PROCEDURE IF EXISTS `mydb`.`Bulk_Buying`;
DELIMITER $$
CREATE PROCEDURE `mydb`.`Bulk_Buying`(IN X INT)
	BEGIN
	  DECLARE goods_stock, goods_id INT;
	  DECLARE flag INT DEFAULT 0;		-- Check if we still have goods
		DECLARE goods_id_list CURSOR FOR (
		  SELECT `mydb`.`Goods`.Goods_Id From `mydb`.`Goods` WHERE `mydb`.`Goods`.Goods_Price <=100
		);
		DECLARE goods_stock_list CURSOR FOR (
		  SELECT `mydb`.`Goods`.Goods_Stock From `mydb`.`Goods` WHERE `mydb`.`Goods`.Goods_Price <=100
		);
	  DECLARE CONTINUE HANDLER FOR NOT FOUND SET flag = 1;

	  IF(X < 0) THEN
			signal SQLSTATE '45000'
			  SET MESSAGE_TEXT ='Bulk Buying Amount should be a non-negative integer!';
		end if;

		-- Get goods stock
		open goods_stock_list;
		FETCH goods_stock_list into goods_stock;

		-- Verify if we have enough stocks for each goods
		while flag !=  1 DO
			if (goods_stock < X) THEN
				signal sqlstate '45000' SET MESSAGE_TEXT = 'No enough stocks for bulk buying!';
			end if;
		  FETCH goods_stock_list into goods_stock;
		end while;

		-- Restore flag
		SET flag = 0;

	  -- Get goods id
		open goods_id_list;
		FETCH goods_id_list into goods_id;

		-- Update goods stock
		WHILE flag != 1 DO
			SELECT `mydb`.`Goods`.Goods_Stock into goods_stock FROM `mydb`.Goods
				WHERE `mydb`.`Goods`.`Goods_Id` = goods_id;
		  UPDATE `mydb`.`Goods` SET `mydb`.`Goods`.Goods_Stock = goods_stock - X
		  	WHERE `mydb`.`Goods`.Goods_Id = goods_id;
		  FETCH goods_id_list  into goods_id;
		end while;
  END
$$
DELIMITER ;

-- Sale statistics
DROP PROCEDURE IF EXISTS `mydb`.`Sale_Statistics`;
DELIMITER $$
CREATE PROCEDURE `mydb`.`Sale_Statistics`(IN Y DATETIME)
	BEGIN
		DECLARE bill_num, bill_id INT;
		DECLARE total_bill_amount, bill_amount REAL;
		DECLARE flag INT default 0;
		DECLARE bill_id_list CURSOR FOR (
		  SELECT `mydb`.`Bill`.Bill_Id FROM `mydb`.`Bill` WHERE `mydb`.`Bill`.`Bill_Time` > Y
		);
		DECLARE CONTINUE HANDLER FOR NOT FOUND SET flag = 1;

		-- Initializes total_bill_amount, bill_num;
		SET total_bill_amount = 0;
		SET bill_num = 0;

		-- Read bill_id
		OPEN bill_id_list;
		FETCH bill_id_list into bill_id;

		WHILE flag != 1 DO
		  	-- Update Bill number
		  	SELECT bill_id;
		  	SET bill_num = bill_num + 1;
				SELECT `mydb`.`Bill`.`Bill_Amount` into bill_amount FROM `mydb`.`Bill`
		  		WHERE `mydb`.`Bill`.Bill_Id = Bill_Id;
		  	-- Update total bill amount
		  	SET total_bill_amount = total_bill_amount + bill_amount;
		  	FETCH bill_id_list into bill_id;
		end while;

		-- Return average bill amounnt
		IF (bill_num != 0) THEN
			SELECT total_bill_amount / bill_num;
		END IF;
  END
$$
DELIMITER ;

-- Insert Refund legal
DROP PROCEDURE IF EXISTS `mydb`.`Insert_Refund_legal`;
DELIMITER $$
CREATE PROCEDURE `mydb`.`Insert_Refund_legal`()
	BEGIN
		INSERT INTO `mydb`.`Refund` (Bill_Id, Goods_Id) VALUES
			(1, 1);
  END
$$
DELIMITER ;

-- Insert Refund illegal
DROP PROCEDURE IF EXISTS `mydb`.`Insert_Refund_illegal`;
DELIMITER $$
CREATE PROCEDURE `mydb`.`Insert_Refund_illegal`()
	BEGIN
		INSERT INTO `mydb`.`Refund` (Bill_Id, Goods_Id) VALUES
			(1, 2);
  END
$$
DELIMITER ;

-- Test member
DROP PROCEDURE IF EXISTS `mydb`.`Test_member`;
DELIMITER $$
CREATE PROCEDURE `mydb`.`Test_member`()
	BEGIN
		INSERT INTO `mydb`.`User` VALUES
			(6, 'Isabella', 'Isabella11', '0', 'Dongchuan 800', '1');
		INSERT INTO `mydb`.`Cart_Info`(Cart_Info_Id, Cart_Id, Goods_Id, Goods_Num) VALUES
			(10, 6, 1, 10);
		INSERT INTO `mydb`.`Bill` (Bill_Id, Cart_Id, User_Id) VALUE
			(6, 6, 6);
  END
$$
DELIMITER ;

-- Test Feedback
DROP PROCEDURE IF EXISTS `mydb`.`Test_Feedback`;
DELIMITER $$
CREATE PROCEDURE `mydb`.`Test_Feedback`()
	BEGIN
		INSERT INTO `mydb`.`Feedback` (Comment, Bill_Id, User_Id) VALUES
			("Finally did it!!", 6,  6);
  END
$$
DELIMITER ;


-- Test User Insertion
CALL `mydb`.`Insert_User_legal`;
# CALL `mydb`.`Insert_User_illegal`;

-- Test Goods Insertion
CALL `mydb`.`Insert_Goods_legal`;
# CALL `mydb`.`Insert_Goods_illegal`;

-- Test Cart_Info Insertion
CALL `mydb`.`Insert_Cart_Info_legal`;
#  CALL `mydb`.`Insert_Cart_Info_illegal`;

-- Test Bill Insertion
CALL `mydb`.`Insert_Bill_legal`;

-- Test Bulk Buying legal
CALL `mydb`.`Bulk_Buying`(20);

-- Test Bulk Buying illegal
Call `mydb`.`Bulk_Buying`(-20);
# Call `mydb`.`Bulk_Buying`(50);

-- Test Sale Statistics
Call `mydb`.`Sale_Statistics`('2019-12-07 10:57:40');

-- Test Refund
Call `mydb`.`Insert_Refund_legal`();
# Call `mydb`.`Insert_Refund_illegal`();

-- Test Membership
Call `mydb`.`Test_member`();

-- Test Feedback
Call `mydb`.`Test_Feedback`();

