-- MySQL Script generated by MySQL Workbench
-- Sat Dec  7 18:07:11 2019
-- Model: New Model    Version: 1.0
-- MySQL Workbench Forward Engineering

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL,ALLOW_INVALID_DATES';

-- -----------------------------------------------------
-- Schema mydb
-- -----------------------------------------------------
DROP SCHEMA IF EXISTS `mydb` ;

-- -----------------------------------------------------
-- Schema mydb
-- -----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS `mydb` DEFAULT CHARACTER SET utf8 ;
USE `mydb` ;

-- -----------------------------------------------------
-- Table `mydb`.`User`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mydb`.`User` ;

CREATE TABLE IF NOT EXISTS `mydb`.`User` (
  `User_Id` INT NOT NULL,
  `User_Name` VARCHAR(30) NULL,
  `Pwd` VARCHAR(30) NULL,
  `Sex` ENUM('0', '1') NULL COMMENT '1 for male and 0 for female',
  `Address` VARCHAR(100) NULL,
  `Member` ENUM('1', '0') NULL,
  PRIMARY KEY (`User_Id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mydb`.`Goods`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mydb`.`Goods` ;

CREATE TABLE IF NOT EXISTS `mydb`.`Goods` (
  `Goods_Id` INT NOT NULL,
  `Goods_Name` VARCHAR(30) NULL,
  `Goods_Price` REAL NULL COMMENT 'non-negative real number',
  `Goods_Stock` INT NULL COMMENT 'non-negative integer',
  PRIMARY KEY (`Goods_Id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mydb`.`Cart`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mydb`.`Cart` ;

CREATE TABLE IF NOT EXISTS `mydb`.`Cart` (
  `Cart_Id` INT NOT NULL,
  `User_Id` INT NULL,
  `Cart_Cost` REAL NULL COMMENT 'Cart_Amount should be a non-negative real number',
  PRIMARY KEY (`Cart_Id`),
  INDEX `User_Id_idx` (`User_Id` ASC),
  CONSTRAINT `Cart_User_Id`
    FOREIGN KEY (`User_Id`)
    REFERENCES `mydb`.`User` (`User_Id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mydb`.`Bill`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mydb`.`Bill` ;

CREATE TABLE IF NOT EXISTS `mydb`.`Bill` (
  `Bill_Id` INT NOT NULL,
  `Cart_Id` INT NULL,
  `User_Id` INT NULL,
  `Bill_No` TEXT(16) NULL COMMENT '16-digit-long string',
  `Bill_Amount` REAL NULL COMMENT 'non-negative real number',
  `Bill_Time` DATETIME NULL,
  PRIMARY KEY (`Bill_Id`),
  INDEX `User_Id_idx` (`User_Id` ASC),
  INDEX `Cart_Id_idx` (`Cart_Id` ASC),
  CONSTRAINT `Bill_User_Id`
    FOREIGN KEY (`User_Id`)
    REFERENCES `mydb`.`User` (`User_Id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `Bill_Cart_Id`
    FOREIGN KEY (`Cart_Id`)
    REFERENCES `mydb`.`Cart` (`Cart_Id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mydb`.`Bill_Info`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mydb`.`Bill_Info` ;

CREATE TABLE IF NOT EXISTS `mydb`.`Bill_Info` (
  `Bill_Info_Id` INT NOT NULL,
  `Bill_Id` INT NULL,
  `Goods_Id` INT NULL,
  `Goods_Num` INT NULL COMMENT 'non-negative integer',
  `Goods_Price` REAL NULL COMMENT 'non-negative real number',
  PRIMARY KEY (`Bill_Info_Id`),
  INDEX `Goods_Id_idx` (`Goods_Id` ASC),
  INDEX `Bill_Id_idx` (`Bill_Id` ASC),
  CONSTRAINT `Bill_Info_Goods_Id`
    FOREIGN KEY (`Goods_Id`)
    REFERENCES `mydb`.`Goods` (`Goods_Id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `Bill_Info_Bill_Id`
    FOREIGN KEY (`Bill_Id`)
    REFERENCES `mydb`.`Bill` (`Bill_Id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mydb`.`Cart_Info`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mydb`.`Cart_Info` ;

CREATE TABLE IF NOT EXISTS `mydb`.`Cart_Info` (
  `Cart_Info_Id` INT NOT NULL,
  `Cart_Id` INT NULL,
  `Goods_Id` INT NULL,
  `Goods_Num` INT NULL COMMENT 'Goods_Num should be a non-negative integer',
  `Add_Time` DATETIME NULL,
  `Goods_Price` REAL NULL COMMENT 'Goods_Price should be a non-negative real number',
  PRIMARY KEY (`Cart_Info_Id`),
  INDEX `Cart_Id_idx` (`Cart_Id` ASC),
  INDEX `Goods_Id_idx` (`Goods_Id` ASC),
  CONSTRAINT `Cart_Info_Cart_Id`
    FOREIGN KEY (`Cart_Id`)
    REFERENCES `mydb`.`Cart` (`Cart_Id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `Cart_Info_Goods_Id`
    FOREIGN KEY (`Goods_Id`)
    REFERENCES `mydb`.`Goods` (`Goods_Id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mydb`.`Refund`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mydb`.`Refund` ;

CREATE TABLE IF NOT EXISTS `mydb`.`Refund` (
  `Refund_Id` INT NOT NULL,
  `Bill_Id` INT NULL,
  `Goods_Id` INT NULL,
  `Goods_Num` INT NULL,
  `Goods_Price` REAL NULL,
  `Refund_Time` DATETIME NULL,
  PRIMARY KEY (`Refund_Id`),
  INDEX `Bill_Id_idx` (`Goods_Id` ASC),
  CONSTRAINT `Bill_Id`
    FOREIGN KEY (`Goods_Id`)
    REFERENCES `mydb`.`Goods` (`Goods_Id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mydb`.`Feedback`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `mydb`.`Feedback` ;

CREATE TABLE IF NOT EXISTS `mydb`.`Feedback` (
  `Feedback_Id` INT NOT NULL,
  `Comment` VARCHAR(300) NULL,
  `Bill_Id` INT NULL,
  PRIMARY KEY (`Feedback_Id`),
  INDEX `Bill_Id_idx` (`Bill_Id` ASC),
  CONSTRAINT `Bill_Id`
    FOREIGN KEY (`Bill_Id`)
    REFERENCES `mydb`.`Bill` (`Bill_Id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
