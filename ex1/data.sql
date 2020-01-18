-- Data manipulation based on model definitions in models.sql
-- Author: Yi Lyu
-- Date: October 1, 2019
-- Email: isabella_aus_china@sjtu.edu.cn

-- -----------------------------------------------------
-- Select data
-- -----------------------------------------------------

-- Data Manipulation 1: Insert client data
delimiter $$
USE `EX1`$$
DROP PROCEDURE IF EXISTS `EX1`.`insert_client` $$
USE `EX1`$$
create procedure insert_client()
begin
		insert into Client(client_age, client_gender, client_name, client_account, client_rank, client_score)
		  VALUES (19, 'female', 'Alice','203fb82ce77612a9', 'top', 702),
             (55, 'male', 'Bob', '402fb82ce77612a9', 'senior', 423);
end
$$

-- Data Manipulation 2: Insert provider data
USE `EX1`$$
DROP PROCEDURE IF EXISTS `EX1`.`insert_provider` $$
USE `EX1`$$
create procedure insert_provider()
begin
		insert into Provider(provider_age, provider_gender, provider_name, provider_account)
		  VALUES (45, 'male', 'Charlie','4f5ebf10fe982b35'),
             (21, 'male', 'David', '4eqecf10fe982b35');
end
$$

-- -----------------------------------------------------
-- Select data
-- -----------------------------------------------------
-- Select Client data
USE `EX1`$$
DROP PROCEDURE IF EXISTS `EX1`.`select_client` $$
USE `EX1`$$
create procedure select_client()
begin
  -- Data manipulation 3
  Select client_name from Client where client_age >  30;
end
$$

-- Select Provider data
USE `EX1`$$
DROP PROCEDURE IF EXISTS `EX1`.`select_provider` $$
USE `EX1`$$
create procedure select_provider()
begin
    -- Data manipulation 4
  Select provider_age,  provider_name from Provider where provider_gender = 'male';
end
$$

-- -----------------------------------------------------
-- Delete data
-- -----------------------------------------------------
-- Delete Client Goods data
USE `EX1`$$
DROP PROCEDURE IF EXISTS `EX1`.`delete_client` $$
USE `EX1`$$
create procedure delete_client()
begin
    -- Data  manipulation 5
    Delete FROM Client where client_name = 'Charlie';
end
$$

-- -----------------------------------------------------
-- Update data
-- -----------------------------------------------------
-- Update Goods data
USE `EX1`$$
DROP PROCEDURE IF EXISTS `EX1`.`update_provider` $$
USE `EX1`$$
create procedure update_provider()
begin
  Update provider SET Provider.provider_age = 22 Where provider_name = 'David';
end
$$
delimiter ;

-- All Insert operations
call insert_client;
call insert_provider;

-- Select operations
call select_client;
call select_provider;

-- All Update operations
call update_provider;

-- All delete operations
call delete_client;