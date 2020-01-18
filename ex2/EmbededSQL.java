"
"
Author: Yi Lyu
Email:  isabella_aus_china@sjtu.edu.cn
Date:   2019.12.08
"""

import java.sql.*;
import java.text.SimpleDateFormat;
import java.util.Date;

public class trigger {
    // Connect to database
    private static Statement stat, stat1;
    private static ResultSet rs;                // For all select query
    private static ResultSet goodsResultSet;    // Specfic for all goods id in cart

    /***
     * Initializes connection and statement
     */
    private trigger() {
        try {
            Connection conn = DriverManager.getConnection("jdbc:mysql://localhost:3306/ex2?useSSL=false",
                    "ex2", "ichliebedich11@");
            stat = conn.createStatement();
            stat1 = conn.createStatement();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /***
     * Execute query sql command
     */
    private static void executeQueryCommand(String sqlCommand) {
        try {
            rs = stat.executeQuery(sqlCommand);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /***
     * Execute update and insert sql command
     */
    private static void executeCommand(String sqlCommand) {
        try {
            stat.execute(sqlCommand);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /***
     * Insert User into mydb.User
     */
    private static void insertUser(int UserId, String Name, String pwd, String Sex, String Address) {
        // Check if user password contains Capital Characters, Small Characters and Digits
        if (!(pwd.matches(".*[a-z].*") && pwd.matches(".*[A-Z].*") && pwd.matches(".*[0-9].*"))) {
            System.out.println("Password not valid!");
            return;
        }

        // Insert user into `User` table
        String insertUserCommand = String.format("INSERT INTO mydb.User VALUES " +
                "(%d, \'%s\', \'%s\', \'%s\', \'%s\');", UserId, Name, pwd, Sex, Address);
        executeCommand(insertUserCommand);

        // Create a shopping cart to each user
        String insertCartCommand = String.format("INSERT INTO `mydb`.`Cart` VALUES " +
                "(%d, %d, %f);", UserId, UserId, 0f);
        executeCommand(insertCartCommand);
    }

    /***
     * Insert Goods
     */
    public static void insertGoods(int GoodsId, String GoodsName, float GoodsPrice, int GoodsStock) {
        // Make sure goods price is not negative
        if (GoodsPrice < 0) {
            System.out.println("Goods Price should  be a non-negative real number");
            return;
        }

        // Make sure goods stock is not negative
        if (GoodsStock < 0) {
            System.out.println("Goods Stock should be a non-negative integer");
            return;
        }

        String insertGoods = String.format("INSERT INTO `mydb`.`Goods` VALUES " +
                "(%d, \'%s\', %f, %d)", GoodsId, GoodsName, GoodsPrice, GoodsStock);
        executeCommand(insertGoods);
    }

    /***
     * Insert Cart Info
     */
    public static void insertCartInfo(int CartInfoId, int CartId, int GoodsId, int GoodsNum) {
        float GoodsPrice, CartCost;
        GoodsPrice = 1;
        CartCost = 0;

        // Make sure that Goods Num is not negative
        if (GoodsNum < 0) {
            System.out.println("Goods Num should be a non-negative integer");
            return;
        }

        // Make sure that Goods should exist in mydb.Goods
        String findGoods = String.format(
                "SELECT `mydb`.`Goods`.Goods_Price " +
                        "from `mydb`.Goods where Goods.Goods_Id = %d;", GoodsId);
        executeQueryCommand(findGoods);

        try {
            if (!rs.next()) {
                System.out.println("Goods doesn't exist");
                return;
            }
            // Read Goods Price
            GoodsPrice = rs.getFloat(1);
            rs.close();
        } catch (Exception e) {
            e.printStackTrace();
        }

        // Set time to now
        SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd hh:mm:ss");
        Date nowDate = new Date();
        String DateString = sdf.format(nowDate);

        // Insert Cart Info
        String insertCartInfo = String.format("INSERT INTO `mydb`.`Cart_Info` " +
                "(Cart_Info_Id, Cart_Id, Goods_Id, Goods_Num, Add_Time, Goods_Price)" +
                " VALUES(%d, %d, %d, %d, \'%s\', %f)", CartInfoId, CartId, GoodsId, GoodsNum, DateString, GoodsPrice);
        executeCommand(insertCartInfo);

        // Select cart amount
        String findOldCartAmount = String.format("SELECT `mydb`.`Cart`.Cart_Cost " +
                "from `mydb`.`Cart` where `mydb`.`Cart`.Cart_Id = %d;", CartId);
        executeQueryCommand(findOldCartAmount);

        // Read Cart Amount
        try {
            rs.next();
            // Read Goods Price
            CartCost = rs.getFloat(1);
        } catch (Exception e) {
            e.printStackTrace();
        }
        // new_cart_cost = old_cart_cost + goods_num * goods_price
        CartCost += GoodsNum * GoodsPrice;

        // Update cart amount
        String updateCart = String.format("UPDATE `mydb`.`Cart` SET Cart_Cost = %f " +
                "WHERE `mydb`.`Cart`.Cart_Id = %d;", CartCost, CartId);
        executeCommand(updateCart);
    }


    /***
     * Insert Bill
     */
    public static void insertBill(int BillId, int CartId, int UserId) {
        float bill_cost,  goods_price = 0;
        int goods_stock = -1, goods_num = 0, goods_id;

        // Set time to now
        SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd hh:mm:ss");
        Date nowDate = new Date();
        String bill_time = sdf.format(nowDate);

        // Initializes bill cost to 0
        bill_cost = 0;

        String findGoodsList = String.format("SELECT `mydb`.`Cart_Info`.Goods_Id FROM `mydb`.`Cart_Info` " +
                "WHERE `mydb`.`Cart_Info`.`Cart_Id` = %d", CartId);

        // Get all goods id in given cart
        // Here we cannot use the general rs since we need to read it during intervals and it may read other results
        // So it will be closed
        try {
            goodsResultSet = stat1.executeQuery(findGoodsList);
        } catch (Exception e) {
            e.printStackTrace();
        }

        // Iterate each goods in Cart
        try {
            while(goodsResultSet.next()) {
                goods_id = goodsResultSet.getInt("Goods_Id");

                // Read goods price
                String getGoodsPrice = String.format("SELECT `mydb`.`Goods`.`Goods_Price` from `mydb`.`Goods` " +
                        "where `mydb`.`Goods`.Goods_Id = %d;", goods_id);
                executeQueryCommand(getGoodsPrice);

                // Read goods stock
                try {
                    rs.next();
                    // Read goods stock
                    goods_price = rs.getFloat("Goods_Price");
                } catch (Exception e) {
                    e.printStackTrace();
                }

                // Check the number in stock
                String getGoodsStock = String.format("SELECT `mydb`.`Goods`.`Goods_Stock` from `mydb`.`Goods` " +
                        "where `mydb`.`Goods`.Goods_Id = %d;", goods_id);
                executeQueryCommand(getGoodsStock);

                // Read goods stock
                try {
                    rs.next();
                    // Read goods stock
                    goods_stock = rs.getInt("Goods_Stock");
                } catch (Exception e) {
                    e.printStackTrace();
                }

                // Check the number of goods required
                String getGoodsNum = String.format("SELECT `mydb`.`Cart_Info`.Goods_Num " +
                        "from `mydb`.`Cart_Info` where `mydb`.`Cart_Info`.Goods_Id = %d and " +
                        "`mydb`.`Cart_Info`.Cart_Id = %d", goods_id, CartId);
                executeQueryCommand(getGoodsNum);

                // Read goods num
                try {
                    rs.next();
                    goods_num = rs.getInt("Goods_Num");
                } catch (Exception e) {
                    e.printStackTrace();
                }

                // Skip the goods if we don't have enough goods in stock
                if (goods_num > goods_stock)
                    continue;

                // Increase bill amount
                bill_cost +=  goods_price * goods_num;

                // Insert into Bill
                String insertBill = String.format("INSERT INTO `mydb`.`Bill` " +
                        "(Bill_Id, Cart_Id, User_Id, Bill_Amount, Bill_Time)" +
                        " VALUES(%d, %d, %d, %f, \'%s\')",BillId,  CartId, UserId,  bill_cost, bill_time);
                executeCommand(insertBill);

                // Insert Bill Info
                String insertBillInfo = String.format("INSERT INTO `mydb`.`Bill_Info` " +
                        "(Bill_Id, Goods_Id, Goods_Price, Goods_Num)" +
                    "   VALUES(%d, %d, %f, %d);", BillId, goods_id,  goods_price, goods_num);
                executeCommand(insertBillInfo);

                // Delete corresponding Cart Info
                String deleteCartInfo = String.format("DELETE FROM `mydb`.Cart_Info" +
                        " WHERE `mydb`.`Cart_Info`.`Goods_Id` = %d " +
                        " and `mydb`.`Cart_Info`.`Cart_Id` = %d;", goods_id, CartId);
                executeCommand(deleteCartInfo);

                // Decrease cart amount
                // Read Current Cart Amount
                String readCartAmount = String.format("SELECT `mydb`.Cart.Cart_Cost " +
                        "From `mydb`.`Cart` WHERE `mydb`.`Cart`.Cart_Id = %d;", CartId);
                executeQueryCommand(readCartAmount);

                //Read current cart cost
                float current_cart_cost = 0.1f;
                try {
                    rs.next();
                    current_cart_cost= rs.getFloat("Cart_Cost");
                } catch (Exception e) {
                    e.printStackTrace();
                }

                String decreaseCartAmount = String.format("UPDATE `mydb`.`Cart` " +
                        "SET `mydb`.`Cart`.`Cart_Cost` = %f - %f * %d " +
                        "WHERE `mydb`.`Cart`.`Cart_Id` = %d;", current_cart_cost, goods_price, goods_num, CartId);
                executeCommand(decreaseCartAmount);

                String decreaseGoodsStock = String.format("UPDATE `mydb`.`Goods` " +
                        "SET `mydb`.`Goods`.`Goods_Stock` = %d - %d " +
                        "WHERE `mydb`.`Goods`.`Goods_Id` = %d;", goods_stock, goods_num, goods_id);
                executeCommand(decreaseGoodsStock);
            }
        }
        catch(Exception e) {
            e.printStackTrace();
        }

        try {
            goodsResultSet.close();
        }
        catch (Exception e) {
            e.printStackTrace();
        }
    }

    public static void main(String ... args) {
        trigger temp = new trigger();

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
    }
}






