## Exercise 2 	Database





#### 实验目的

根据老师给定的场景进行数据库构建以及触发器定义，加深对数据库的理解和应用能力。



#### 实验要求

- [x] 构建关系数据库
- [x] 使用触发器实现业务逻辑
- [x] 使用嵌入式mysql实现业务逻辑
- [x] 使用存储过程实现业务逻辑
- [x] 附加题：在线购物系统功能拓展



#### 2. 构建关系数据库

某在线购物网站数据库中的主要关系如下：

```
1. 用户（用户ID（整形），用户名（长度不超过30的字符串）,用户密码（长度不超过30的字符串，需包含大小写字母和数字），用户性别（男/女，可用0和1两个整数表示），收货地址（长度不超过100的字符串））

2. 商品（商品ID（整形），商品名（长度不超过30的字符串）, 商品价格（非负实数），剩余库存（非负整数） ）

3. 订单（订单ID（整形），购物车ID（整形），用户ID（整形），订单编号（长度为16的数字串），订单金额（非负实数），下单时间（DATETIME））

4. 订单详情（订单详情ID（整形），订单ID（整形），商品ID（整形），商品数量（非负整数），商品价格（非负实数））

5. 购物车（购物车ID（整形），用户ID（整形），商品总价（非负实数））

6. 购物车详情（购物车详情ID（整形），购物车ID（整形），商品ID（整形），商品数量（非负整数），添加时间（DATETIME），商品价格（非负实数））
```

根据以上信息，我设计出的ER图如下所示。

<img src="/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191204194527459.png" alt="image-20191204194527459" style="zoom:40%;" />



经过分析，设计出的ER图满足3NF条件。即每个表中的元素满足原子性，每一个非主属性完全函数依赖于码(候选码)，并且每个非主属性Z不传递依赖于码X，于是我认为该逻辑模式满足3NF的条件。



#### 3. 使用触发器实现业务逻辑

要求在mysql workbench中实现以下功能：

##### a. 商品下单时状态更新

目标：在商品下单后能够正确的更新库存信息

实现这一目的主要分成购物车添加流程和订单添加流程。

##### 1. 购物车添加流程

##### Answer：

对于这一问题的理解，我认为用户在把商品添加到购物车的时候是把自己想要的商品添加到购物车详情中，之后购物车中自动增加商品金额。

由于在添加购物车详情时需要知道购物车id（从而之后可以在下单后根据购物车id在购物车表中寻找到用户id添加在订单中），我在每个用户插入用户表的时候就为每个用户分配了一个购物车，伪了方便记忆，购物车id和用户id相同。

```mysql
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
```

这样我们就可以添加购物车详情了，为了方便使用，购物车详情中的商品价格是利用商品详情中的商品id在商品表中寻找到的，购物车详情的添加时间被自动设置为当前时间。

此外在添加了购物车详情之后，我们把新增商品总价增加到购物车总价中。

```mysql
-- Check newly Inserted Cart_Info
DROP TRIGGER IF EXISTS `mydb`.`Before_Insert_CartInfo`;
DELIMITER $$
CREATE TRIGGER `mydb`.`Before_Insert_CartInfo` BEFORE INSERT ON `mydb`.`Cart_Info` FOR EACH ROW
	BEGIN
		Declare goods_price,cart_cost REAL;
		SET goods_price = -1;

    -- Make sure that Goods_Num is non-negative
		IF (NEW.Goods_Num < 0) THEN
			signal SQLSTATE '45000' SET message_text = "Goods Num should be a non-negtive integer";
		END IF;

		-- Calculate goods price automatically
    SELECT `mydb`.`Goods`.Goods_Price INTO goods_price from `mydb`.Goods where Goods.Goods_Id = NEW.Goods_Id;
    SET NEW.Goods_Price =  goods_price;

    -- Set Cart Info Add Time
    SET NEW.Add_Time = NOW();

    -- Update the total goods cost in the corresponding shopping cart
    SELECT `mydb`.`Cart`.Cart_Cost into cart_cost from `mydb`.`Cart` where `mydb`.`Cart`.Cart_Id = NEW.Cart_Id;
    UPDATE `mydb`.`Cart` SET Cart_Cost = cart_cost + NEW.Goods_Price * NEW.Goods_Num WHERE `mydb`.`Cart`.Cart_Id = NEW.Cart_Id;
	EnD
	$$
DELIMITER ;
```

在这里我同时检查了商品数量，保证商品数量非负。



##### 2. 订单添加流程

在这里订单插入过程如下：

用户提交订单信息后，系统开始检查用户对应购物车中的每条购物车详情，如果购物车详情中要求的商品数量大于商品库存，则不把这个商品添加到订单和订单详情中，如果购物车详情中要求的商品数量小于库存，则删除该条购物车详情，同时相应减少购物车中的商品总价，添加订单详情，同时增加订单总价。

由于购物车中商品数量不为1，在这里我定义了一个游标来读取购物车中的商品。由于自动生成订单总价的操作必须在before insert trigger中实现，而插入bill_info的操作必须在after insert trigger(Bill Id是Bill Info的foreign key)中实现，在这里我写了两个trigger。

在before insert trigger中，我主要设置了新插入的Bill_Amount。

```mysql
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
```

在after insert trigger中，我在判断库存和商品需求数量后删除了对应的Cart Info，减少了Cart中的商品总价，并添加了bill info,同时我减少了商品库存量。

```mysql
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

				-- Delete Corressponding Cart Info
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
```



##### b. 用户和商品的完整性约束检验

目标：在用户和商品关系中的元组插入/更新时，能满足问题场景中的用户定义完整性约束（如字符串长度、密码是否包含大小写字母和数字）

1. 检测用户密码是否符合标准（大小写，数字）

```mysql
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
```

2. 检查商品库存和价格是否是负数

```mysql
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
```



##### 测试用例

```mysql
USE `mydb` ;

-- Insert User
DROP PROCEDURE IF EXISTS `mydb`.`Insert_User_legal`;
DELIMITER $$
CREATE PROCEDURE `mydb`.`Insert_User_legal`()
	BEGIN
		INSERT INTO `mydb`.`User` VALUES
			(1, 'Alice', 'Alice11', '0', 'Dongchuan 800'),
            (2, 'Tom', 'Tom22', '1', 'Meichuan 300');
    END
$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `mydb`.`Insert_User_illegal`;
DELIMITER $$
CREATE PROCEDURE `mydb`.`Insert_User_illegal`()
	BEGIN
		INSERT INTO `mydb`.`User` VALUES
			(3, 'Tracy', 'Tracy', '0', 'Tongchuan 700'),
            (4, 'Tim', 'tim1', '1', 'Heichuan 200'),
			(3, 'TLinda', 'LINDA1', '0', 'Tianchuan 400');
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
            (2, 'Juice', 6.3, 100);
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
              (5, 2, 1, -3),				-- Goods Num should be non-negative
              (6, 2, 5, 2);         -- Goods is not available
  END
$$
DELIMITER ;

-- Insert Bill
DROP PROCEDURE IF EXISTS `mydb`.`Insert_Bill_legal`;
DELIMITER $$
CREATE PROCEDURE `mydb`.`Insert_Bill_legal`()
	BEGIN
		INSERT INTO `mydb`.`Bill` (Cart_Id, User_Id) VALUES
			(1, 1);
# 			(2, 2);
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
# CALL `mydb`.`Insert_Cart_Info_illegal`;

-- Test Bill Insertion
CALL `mydb`.`Insert_Bill_legal`;
```

在执行所有legal的操作时，程序执行无异常



##### 测试结果

User信息为：

![image-20191206121120143](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191206121120143.png)

Goods信息如下：

![image-20191206121159455](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191206121159455.png)

我们首先添加了购物车信息，让1号用户添加了4件1号商品价格，添加了180件2号商品，让二号用户添加了20件2号商品，测试结果与预计结果相同：

![image-20191206121558834](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191206121558834.png)

此时1号用户的购物车总价应该为4*3.2 + 180 * 6.3 = 1146.8，2号用户的购物车总价为20*6.3=126元，与测试结果相同

![image-20191206121828180](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191206121828180.png)

在1号用户下单以后，只有1号商品可以被成功下单，因为1号用户需要180件2号商品，而二号商品的库存量只有100件，因此应该不能成功下单。

此时1号用户关于商品1的订单应该中的总价应为4*3.2=12.8， 购物车总价应为1146.8-12.8=1134，相应的购物车详情应该被删除，相应的订单详情应该被添加。

1号商品库存应该为36

订单总价：

![image-20191206122213812](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191206122213812.png)

购物车总价：

![image-20191206122226756](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191206122226756.png)

购物车详情：

![image-20191206122325900](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191206122325900.png)

订单详情：

![image-20191206122338543](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191206122338543.png)

商品库存：

![image-20191207112950870](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207112950870.png)

##### 数据约束检验结果：

在这里分别调用每个illegal的procedure。

1. 测试用户密码是否含有大小写和数字

在这里我选取的密码是'Tracy'，'tim1'，'LINDA1'，分别不含有数字，大写字母和小写字母，在执行之后则会出现自定义的用户密码不符合标准的错误。

![image-20191206122635989](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191206122635989.png)

2. 测试商品是否符合标准

在这里我选取的测试样例的单价和库存分别都是零，然而在这里我们希望的这两个属性都是非负值。

在令单价为-2.3时，出现了以下错误提示：

![image-20191206123035793](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191206123035793.png)

在令库存量为-2时，出现了以下错误提示：

![image-20191206123111606](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191206123111606.png)

3. 测试插入的购物车详情商品数量是否为负数，以及商品是否存在

在设定商品数量为-3的时候出现了以下错误：

![image-20191206123259122](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191206123259122.png)

在设定商品Id为5（不存在）的时候出现了以下错误：

![image-20191206123409701](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191206123409701.png)

经过这些测试，可以证明trigger符合要求，通过测试😄



#### 4. 使用嵌入式MySQL实现业务逻辑

要求：在MySQL workbench中删除上述触发器，并通过MYSQL的嵌入式接口（MySQL connector for JAVA）替代触发器再次实现对应的功能  

##### Answer：

具体实现思路：在这里我利用java进行条件判断，把sql中的insert操作与对应的trigger操作封装成函数，最后利用jdbc的嵌入式sql接口执行sql操作。

在这里的异常处理我选择在console中打印出对应的错误信息，跳过之后的后续操作。

具体的实现在`     EmbededSQL.java  `文件中。



##### 测试样例

在这里与sql中的测试样例保持一致

```java
// Insert User legal
trigger.insertUser(1, "Alice", "Alice11", "0", "Dongchuan 800");
trigger.insertUser(2, "Tom", "Tom22", "1", "Meichuan 300");

// Insert User illegal
trigger.insertUser(3, "Tracy", "Tracy", "0", "Tongchuan 700");
trigger.insertUser(4, "Tim", "tim1", "1", "Heichuan 200");
trigger.insertUser(3, "TLinda", "LINDA1", "0", "Tianchuan 400");

// Insert Goods legal
trigger.insertGoods(1, "Biscuit", 3.2f,  40);
trigger.insertGoods(2, "Juice", 6.3f, 100);

// Insert Goods illegal
trigger.insertGoods(3, "Coca Cola", -2.3f, 50);
trigger.insertGoods(4, "Jelly", 3.1f, -2);

// Insert Cart Info legal
trigger.insertCartInfo(5, 1, 1, 4);
trigger.insertCartInfo(6,  2, 2, 20);
trigger.insertCartInfo(7, 1, 2, 180);

// Insert Cart Info illegal
trigger.insertCartInfo(5, 2, 1, -3);
trigger.insertCartInfo (6, 2, 5, 2);

// Insert Bill legal
trigger.insertBill(1, 1, 1);
```

在正确输入数据样例下，

结果与sql结果相同

订单总价：

![image-20191206122213812](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191206122213812.png)

购物车总价：

![image-20191206122226756](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191206122226756.png)

购物车详情：

![image-20191206122325900](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191206122325900.png)

订单详情：

![image-20191206122338543](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191206122338543.png)

商品详情：

![image-20191207112931595](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207112931595.png)



在非法样例下，生成的错误信息如下：

![image-20191207103733662](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207103733662.png)

与设计目标一致，嵌入式sql通过测试😄



#### 5. 使用存储过程实现业务逻辑

a. 批量购买

* 假设某用户购买了该系统中所有价格不超过100元的商品X件，其中X通过存储过程传入。

* 需要修改商品表中满足条件商品的剩余库存量。判断X是否小于0，若是，使用SIGNAL SQLSTATE ‘45000’实现报错。若商品库存不小于X，对商品库存进行修改；否则，使用SIGNAL SQLSTATE ‘45000’实现报错。

* 调用该存储过程，验证其正确性

##### Answer:

在这里为了测试是否能选出价格不超过100元的商品，新增商品Dress，价格为200元。

在procedure中我先判断X是否小于0，如果小于0就声称错误信息，打印“Bulk Buying Amount should be a non-negative integer!”

之后我先利用游标得到所有商品价格小于100元的商品的库存，检查库存量是否都大于等于X，如果不满足，就显示错误信息“No enough stocks for bulk buying!”

如果以上条件都满足，就把减小对应商品的库存量。

具体实现如下。

```mysql
-- Bulk Buying(Goods Price under 100)
DROP PROCEDURE IF EXISTS `mydb`.`Bulk_Buying`;
DELIMITER $$
CREATE PROCEDURE `mydb`.`Bulk_Buying`(IN Num INT)
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

	  IF(Num < 0) THEN
			signal SQLSTATE '45000'
			  SET MESSAGE_TEXT ='Bulk Buying Amount should be a non-negative integer!';
		end if;

		-- Get goods stock
		open goods_stock_list;
		FETCH goods_stock_list into goods_stock;

		-- Verify if we have enough stocks for each goods
		while flag !=  1 DO
			if (goods_stock < Num) THEN
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
		  UPDATE `mydb`.`Goods` SET `mydb`.`Goods`.Goods_Stock = goods_stock - Num
		  	WHERE `mydb`.`Goods`.Goods_Id = goods_id;
		  FETCH goods_id_list  into goods_id;
		end while;
  END
$$
DELIMITER ;
```



##### 测试样例：

首先我们先测试正确的样例。

```mysql
CALL `mydb`.`Bulk_Buying`(20);
```

在这里我想要购买的数量为20。三种商品中价格不超过100的有3.2的Biscuit和6.3的Jelly。

Biscuit的库存量为40-4=36(之前下单时购买了4个)，Jelly库存为100。

经过批量购买后，Biscuit的库存应该为16， Jelly的库存应该为80。

Dress由于价格超过100，库存不变，还是10。

经过测试，结果如下：

![image-20191207113443115](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207113443115.png)

与预期结果相同！

##### 错误样例

```mysql
Call `mydb`.`Bulk_Buying`(-20);
```

首先我们令购物数量为-20，运行结果如下：

![image-20191207113608658](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207113608658.png)

之后我们令购物数量为50，由于biscuit的库存只有36，商品库存不够，因此不能成功购买，运行结果如下：

```mysql
Call `mydb`.`Bulk_Buying`(50);
```

![image-20191207113716516](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207113716516.png)

总而言之，我们通过了批量购买的测试😄



##### b. 销售统计

商家需要知道某个时间点Y（DATETIME）后的平均订单金额，其中Y通过存储过程传入。

调用该存储过程，验证其正确性

##### Answer:

这里的具体实现思路比较简单，首先从Bill表中读出所有DateTime之后建立的订单的id，

之后分别设置变量存储订单个数和金额，最后相除返回平均订单值。

```mysql
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
		  	SET bill_num = bill_num + 1;
				SELECT `mydb`.`Bill`.`Bill_Amount` into bill_amount FROM `mydb`.`Bill`
		  		WHERE `mydb`.`Bill`.Bill_Id = Bill_Id;
		  	-- Update total bill amount
		  	SET total_bill_amount = total_bill_amount + bill_amount;
		end while;

		-- Return average bill amounnt
		IF (bill_num != 0) THEN
			SELECT total_bill_amount / bill_num;
		END IF;
  END
$$
DELIMITER ;
```



##### 测试样例

由于之前只有一个订单信息不好进行验证，我又提交了用户2的订单。

此时我们拥有两个订单，订单信息分别如下：

![image-20191207115751654](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207115751654.png)

测试样例：

```mysql
Call `mydb`.`Sale_Statistics`('2019-12-07 10:57:40');
```

由于这两个订单都在Y之后创建, 此时应该得到的平均订单价格为(12.8 + 126) / 2 = 69.4

![image-20191207120554716](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207120554716.png)

通过测试😄



#### 6. 在线购物系统功能扩展（附加题）

1.该线购物系统需要继续扩展以满足用户需求，可扩展的功能包括但不限于：

* 商品退货

* 会员折扣机制

* 订单评价机制

2.为了扩展功能，是否需要设计新的关系或修改现有关系？是否需要设计新的触发器、存储过程或嵌入式SQL来保证正确性？新的功能是否会影响现有触发器或存储过程的实现？请展开分析、实现并验证其正确性



##### 商品退货：

为了实现商品退货机制，我先设计了一张商品退货表。当用户对订单中的某项商品不满意需要退货的时候，我先从订单详情中删除相应信息，再减少订单金额，最后增加商品的库存。

因此我设计了新的关系，同时设计了新的触发器和存储过程，新的功能不会影响现有触发器的实现。

新的ER图如下所示：

![image-20191207164713793](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207164713793.png)

对应trigger中的实现思路具体如下：

首先我先检验对应订单号中是否有该商品，如果没有该商品，则显示该商品在订单中不存在的错误信息。之后我自动设置Refund表中的Goods_Num和Goods_Price两个属性。

之后我更新订到总价，并删除对应的订单详情,并增加商品库存。

具体实现如下：

```mysql
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
	  	SET `mydb`.`Bill`.`Bill_Amount` = bill_amount - goods_price * goods_num;

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

```

##### 测试样例

在这里我想把Bill_Info中以下一条购买信息撤回。

![image-20191207165553388](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207165553388.png)

由于这次订单中只有这个商品，在撤回后订单金额应该为0， Bill_Info为空，Refund中增加相应记录。

1号库存量应该是16+4=20

运行结果如下：

Bill：

![image-20191207165724311](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207165724311.png)

Bill_Info：

![image-20191207165742552](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207165742552.png)

Refund：

![image-20191207165805199](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207165805199.png)

Goods：

![image-20191207165834650](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207165834650.png)

与预期结果一致，测试成功😄

而想退款插入订单中不存在的二号商品时，出现一下错误信息：

![image-20191207165956787](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207165956787.png)



##### 会员机制

为了实现会员机制，我首先在User表中增加了一个属性会员，'1'表示是会员，'0'表示不是会员。为了不影响之前的结果，我把之前的user都设为非会员，额外会员的测试样例。

##### Answer:

之后只需要修改添加cart_info的trigger，检查用户是否是会员，如果是会员打95折。

新的er图如下所示：

![image-20191207170956978](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207170956978.png)

在这里需要修改现有关系（增加属性），修改现有触发器。

由于我之前把cart_id设成user_id，这里不需要修改其他关系。

修改如下：

```mysql
-- Check newly Inserted Cart_Info
DROP TRIGGER IF EXISTS `mydb`.`Before_Insert_CartInfo`;
DELIMITER $$
CREATE TRIGGER `mydb`.`Before_Insert_CartInfo` BEFORE INSERT ON `mydb`.`Cart_Info` FOR EACH ROW
	BEGIN
		Declare goods_price,cart_cost REAL;
		DECLARE member TEXT;
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
		SELECT `mydb`.`User`.Member into member FROM `mydb`.`User`
			Where `mydb`.`User`.User_Id = NEW.Cart_Id;

		IF(member = '1') THEN
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
```



##### 测试样例

为了不影响之前的测试样例，在这里我单独设置了一个会员用户，让她购买10个1号商品。

那这样，每个商品的价格就是3.2*0.95 = 3.04

购物车详情中商品价格为3.04，购物车中总价为3.04*10 = 30.4

```mysql
-- Test member
DROP PROCEDURE IF EXISTS `mydb`.`Test_member`;
DELIMITER $$
CREATE PROCEDURE `mydb`.`Test_member`()
 BEGIN
  INSERT INTO `mydb`.`User` VALUES
   (6, 'Isabella', 'Isabella11', '0', 'Dongchuan 800', '1');
  INSERT INTO `mydb`.`Cart_Info`(Cart_Info_Id, Cart_Id, Goods_Id, Goods_Num) VALUES
   (6, 6, 1, 10);
  END
$$
DELIMITER ;
```

测试结果如下：

Cart：

![image-20191207175956982](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207175956982.png)

CartInfo：

![image-20191207180022545](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207180022545.png)



如果之后在提交了订单，则订单价格如下：

Bill：

![image-20191207180110029](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207180110029.png)

Bill_Info:

![image-20191207180129042](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207180129042.png)

与预期一致，测试成功！！！😄



##### 订单评价机制

这个是这几个中最简单的一个，只需要在设计一个订单评价表就好，里面包含着一个最大长度不超过300的评价信息。

新的er图如下：

![image-20191207181828107](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207181828107.png)

不需要修改以前的关系和trigger，直接增加一个新的关系Feedback就好。



##### 测试样例

```mysql
-- Test Feedback
DROP PROCEDURE IF EXISTS `mydb`.`Test_Feedback`;
DELIMITER $$
CREATE PROCEDURE `mydb`.`Test_Feedback`()
	BEGIN
		INSERT INTO `mydb`.`Feedback` (Comment, Bill_Id， User_Id) VALUES
			("Finally did it!!", 6， 6);
  END
$$
DELIMITER ;
```

应该会自动生成feedback_id（1），Comment为"Finally did it!!"，订单号为6， User_Id为6

运行结果：

![image-20191207182002662](/Users/isabella/Desktop/SJTU-courses/third_1/SE305/exercise/ex2_whole/Exercise 2  Database.assets/image-20191207182002662.png)

与预期结果一致,测试通过，做完啦😄😄😄



