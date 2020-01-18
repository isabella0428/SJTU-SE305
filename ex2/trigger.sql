-- Author: Yi Lyu
-- Email:	isablla_aus_china@sjtu.edu.cn
-- Date:	2019.12.08

-- Check newly Inserted User's password
DROP TRIGGER IF EXISTS `mydb`.`Before_Insert_User`;
DELIMITER $$
CREATE TRIGGER `mydb`.`Before_Insert_User` BEFORE INSERT ON `mydb`.`User` FOR EACH ROW
	BEGIN
		-- Must Add BINARY here since REGEXP ignore captical as default setting
		IF (NOT NEW.Pwd REGEXP '[0-9]' or NOT NEW.Pwd REGEXP BINARY '[a-z]'
						or NOT NEW.Pwd REGEXP BINARY '[A-Z]' ) THEN
			signal SQLSTATE '45000' SET message_text = "User Password illegal!";
		END IF;
	EnD
	$$
DELIMITER ;

-- Create Cart  for newly inserted user
DROP TRIGGER IF EXISTS `mydb`.`After_Insert_User`;
DELIMITER $$
CREATE TRIGGER `mydb`.`After_Insert_User` After INSERT ON `mydb`.`User` FOR EACH ROW
	BEGIN
		-- Create a cart for the user
		-- Cart Id is set to be equal to the user id
	  INSERT INTO `mydb`.`Cart` VALUES (New.User_Id, New.User_Id, 0);
	EnD
	$$
DELIMITER ;

-- Check newly Inserted Goods' price and stock
DROP TRIGGER IF EXISTS `mydb`.`Insert_Goods`;
DELIMITER $$
CREATE TRIGGER `mydb`.`Insert_Goods` BEFORE INSERT ON `mydb`.`Goods`  FOR EACH ROW
	BEGIN
		IF (NEW.Goods_Price < 0) THEN
			signal SQLSTATE '45000' SET message_text = "Goods Price should be a non-negative real number";
		END IF;
        IF (NEW.Goods_Stock < 0) THEN
			signal SQLSTATE '45000' SET message_text = "Goods Stock should be a non-negative integer";
		END IF;
	EnD
	$$
DELIMITER ;

-- Check newly Inserted Cart_Info
DROP TRIGGER IF EXISTS `mydb`.`Before_Insert_CartInfo`;
DELIMITER $$
CREATE TRIGGER `mydb`.`Before_Insert_CartInfo` BEFORE INSERT ON `mydb`.`Cart_Info` FOR EACH ROW
	BEGIN
	  Declare membership TEXT;
		Declare goods_price,cart_cost REAL;

		-- Initializes goods price
		SET goods_price = -1;

    -- Make sure that Goods_Num is non-negative
		IF (NEW.Goods_Num < 0) THEN
			signal SQLSTATE '45000' SET message_text = "Goods Num should be a non-negtive integer";
		END IF;

		-- Calculate goods price automatically
    SELECT `mydb`.`Goods`.Goods_Price INTO goods_price from `mydb`.Goods where Goods.Goods_Id = NEW.Goods_Id;
    IF (goods_price = -1) THEN
      signal SQLSTATE '45000' SET message_text = "Goods doesn't exist";
    END IF;

    -- Determine if user is member
		SELECT `mydb`.`User`.Membership into membership FROM `mydb`.`User`
			Where `mydb`.`User`.User_Id = NEW.Cart_Id;

		IF(membership = '1') THEN
			SET goods_price = 0.95 * goods_price;
		end if;

    SET NEW.Goods_Price =  goods_price;

    -- Set Cart Info Add Time
    SET NEW.Add_Time = NOW();

    -- Update the total goods cost in the corresponding shopping cart
    SELECT `mydb`.`Cart`.Cart_Cost into cart_cost from `mydb`.`Cart` where `mydb`.`Cart`.Cart_Id = NEW.Cart_Id;
    UPDATE `mydb`.`Cart` SET Cart_Cost = cart_cost + NEW.Goods_Price * NEW.Goods_Num WHERE `mydb`.`Cart`.Cart_Id = NEW.Cart_Id;
	EnD
	$$
DELIMITER ;

-- Create a Bill Info
DROP TRIGGER IF EXISTS `mydb`.`Before_Insert_Bill`;
DELIMITER $$
CREATE TRIGGER `mydb`.`Before_Insert_Bill` BEFORE INSERT ON `mydb`.`Bill` FOR EACH ROW
	BEGIN
		DECLARE bill_cost, goods_price REAL;
		DECLARE goods_id, goods_stock, goods_num INT;
		DECLARE flag INT DEFAULT 0;		-- Check if we still have goods in cart
		DECLARE goods_id_List CURSOR FOR (
		  SELECT `mydb`.`Cart_Info`.Goods_Id FROM `mydb`.`Cart_Info`
		  	WHERE `mydb`.`Cart_Info`.`Cart_Id` = New.Cart_Id);
		DECLARE CONTINUE HANDLER FOR NOT FOUND SET flag = 1;

		-- Set Add Bill Time
		SET New.Bill_Time = Now();

		-- Initializes bill cost to zero
		SET bill_cost = 0;

		-- Get value from cursor
		OPEN goods_id_List;
		FETCH goods_id_List INTO goods_id;

		WHILE flag != 1 DO
		  -- Test if we have enough goods in stock
		  SELECT `mydb`.`Goods`.`Goods_Stock` into goods_stock from `mydb`.`Goods`
				where `mydb`.`Goods`.Goods_Id = goods_id;
		  SELECT `mydb`.`Cart_Info`.Goods_Num  into goods_num from `mydb`.`Cart_Info`
				where `mydb`.`Cart_Info`.Goods_Id = goods_id and `mydb`.`Cart_Info`.Cart_Id = NEW.Cart_Id;

		  IF (goods_stock >= goods_num) THEN
					-- Calculate the cost of the prices
				SELECT `mydb`.`Cart_Info`.Goods_Price into goods_price from `mydb`.`Cart_Info`
						where `mydb`.`Cart_Info`.Goods_Id = goods_id and `mydb`.`Cart_Info`.Cart_Id = NEW.Cart_Id;
				SET bill_cost = bill_cost + goods_price * goods_num;
			END IF;
			FETCH goods_id_list INTO goods_id;
		END WHILE;

		CLOSE goods_id_List;
		SET NEW.Bill_Amount = bill_cost;
	EnD
	$$
DELIMITER ;

-- Create a Bill Info
DROP TRIGGER IF EXISTS `mydb`.`After_Insert_Bill`;
DELIMITER $$
CREATE TRIGGER `mydb`.`After_Insert_Bill` After INSERT ON `mydb`.`Bill` FOR EACH ROW
	BEGIN
		DECLARE goods_price, current_cart_cost REAL;
		DECLARE goods_id, goods_num, goods_stock INT;
		DECLARE flag INT DEFAULT 0;		-- Check if we still have goods in cart
		DECLARE goods_id_List CURSOR FOR (
		  SELECT `mydb`.`Cart_Info`.Goods_Id FROM `mydb`.`Cart_Info`
		  	WHERE `mydb`.`Cart_Info`.`Cart_Id` = New.Cart_Id);
		DECLARE CONTINUE HANDLER FOR NOT FOUND SET flag = 1;

		-- Get value from cursor
		OPEN goods_id_List;
		FETCH goods_id_List INTO goods_id;

		WHILE flag != 1 DO
		  SELECT `mydb`.`Cart_Info`.Goods_Price into goods_price from `mydb`.`Cart_Info`
				where `mydb`.`Cart_Info`.Goods_Id = goods_id and `mydb`.`Cart_Info`.Cart_Id = NEW.Cart_Id;
		  SELECT `mydb`.`Cart_Info`.Goods_Num  into goods_num from `mydb`.`Cart_Info`
				where `mydb`.`Cart_Info`.Goods_Id = goods_id and `mydb`.`Cart_Info`.Cart_Id = NEW.Cart_Id;

		  -- Test if we have enough goods in stock
		  SELECT `mydb`.`Goods`.`Goods_Stock` into goods_stock from `mydb`.`Goods`
				where `mydb`.`Goods`.Goods_Id = goods_id;

		  IF (goods_stock >= goods_num) THEN
		  	INSERT INTO `mydb`.`Bill_Info` (Bill_Id, Goods_Id, Goods_Price, Goods_Num)
					VALUES(NEW.Bill_Id, goods_id, goods_price, goods_num);

				-- Delete Corresponding Cart Info
		    DELETE FROM `mydb`.Cart_Info
		    	WHERE `mydb`.`Cart_Info`.`Goods_Id` = goods_id
		    	      and `mydb`.`Cart_Info`.`Cart_Id` = NEW.Cart_Id;

		    -- Decrease the total amount in Cart
		  	SELECT `mydb`.Cart.Cart_Cost into current_cart_cost
		  		From `mydb`.`Cart` WHERE `mydb`.`Cart`.Cart_Id = NEW.Cart_Id;
		    UPDATE `mydb`.`Cart` SET `mydb`.`Cart`.`Cart_Cost` = current_cart_cost - goods_price * goods_num
		    	 WHERE `mydb`.`Cart`.`Cart_Id` = NEW.Cart_Id;

		    -- Decrease Goods stock
		    UPDATE `mydb`.`Goods` SET `mydb`.`Goods`.`Goods_Stock` = goods_stock - goods_num
		    	 WHERE `mydb`.`Goods`.`Goods_Id` = goods_id;

			END IF;

			FETCH goods_id_list INTO goods_id;
		END WHILE;

		CLOSE goods_id_List;
	EnD
	$$
DELIMITER ;

-- Insert Refund
-- Automatically set Goods_Price and Goods_Num
DROP TRIGGER IF EXISTS `mydb`.`Before_Insert_Refund`;
DELIMITER $$
CREATE TRIGGER `mydb`.`Before_Insert_Refund` BEFORE INSERT ON `mydb`.`Refund` FOR EACH ROW
	BEGIN
		DECLARE goods_num, goods_stock INT;
		DECLARE goods_price, bill_amount REAL;

		-- Initializes goods_num
		SET goods_num = -1;

		SELECT `mydb`.`Bill_Info`.Goods_Num into goods_num From `mydb`.`Bill_Info`
		  Where `mydb`.`Bill_Info`.Goods_Id = New.Goods_Id
		    and `mydb`.`Bill_Info`.Bill_Id = New.Bill_Id;

		-- Check if the goods is in the bill
		IF(goods_num = -1) THEN
			signal SQLSTATE '45000' SET MESSAGE_TEXT = 'Goods to refund is not in the bill!';
		end if;

		SELECT `mydb`.`Bill_Info`.Goods_Price into goods_price From `mydb`.`Bill_Info`
		  Where `mydb`.`Bill_Info`.Goods_Id = New.Goods_Id
		    and `mydb`.`Bill_Info`.Bill_Id = New.Bill_Id;
		SET NEW.Goods_Price = goods_price;
		SET New.Goods_Num = goods_num;
		SET New.Refund_Time = Now();

		-- Update Bill Amount
	  SELECT `mydb`.`Bill`.Bill_Amount into bill_amount FROM `mydb`.`Bill`
	  	WHERE `mydb`.`Bill`.Bill_Id = NEW.Bill_Id;
	  UPDATE `mydb`.`Bill`
	  	SET `mydb`.`Bill`.`Bill_Amount` = bill_amount - goods_price * goods_num
		  Where `mydb`.`Bill`.Bill_Id = NEW.Bill_Id;

	  -- Delete Bill Info
	  DELETE FROM `mydb`.`Bill_Info`
	  	WHERE `mydb`.`Bill_Info`.Bill_Id = NEW.Bill_Id
	  	  and `mydb`.`Bill_Info`.Goods_Id = NEW.Goods_Id;

	  -- Update Goods Stock
		SELECT `mydb`.`Goods`.Goods_Stock into goods_stock FROM `mydb`.`Goods`
		  WHERE `mydb`.`Goods`.Goods_Id = NEW.Goods_Id;
		UPDATE `mydb`.`Goods` SET `mydb`.`Goods`.Goods_Stock = goods_stock + goods_num
	  	WHERE `mydb`.`Goods`.Goods_Id = New.Goods_Id;
	EnD
	$$
DELIMITER ;
