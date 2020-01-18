import com.mysql.jdbc.jdbc2.optional.MysqlXAConnection;
import com.mysql.jdbc.jdbc2.optional.MysqlXid;
import javax.sql.XAConnection;
import javax.transaction.xa.XAResource;
import javax.transaction.xa.Xid;
import java.sql.SQLException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.Statement;
import java.sql.ResultSet;

/**
 * Author: Yi Lyu
 * Date: 2020.1.11
 * Use XA transaction to execute distributed transactions
 */

public class Main2 {
    public static void createTableRemote(Connection conn) {
        try {
            Statement st = conn.createStatement();
            String createUserTableCommand =
                    "DROP TABLE IF EXISTS `User` ;" +
                    "CREATE TABLE IF NOT EXISTS `User` (" +
                    "  `User_Id` INT NOT NULL," +
                    "  `User_Name` VARCHAR(30) NULL," +
                    "  `Pwd` VARCHAR(30) NULL COMMENT 'Must contain capital, small letters and numbers'," +
                    "  `Sex` ENUM('0', '1') NULL COMMENT '1 for male and 0 for female'," +
                    "  `Address` VARCHAR(100) NULL," +
                    "  `Membership` ENUM('1', '0') DEFAULT '0'," +
                    "  PRIMARY KEY (`User_Id`)" +
                    "  )" +
                    "ENGINE = InnoDB;";

            String createBillTableCommand =
                    "DROP TABLE IF EXISTS `Bill`;" +
                    "CREATE TABLE IF NOT EXISTS `Bill` (" +
                            "  `Bill_Id` INT auto_increment," +
                            "  `Cart_Id` INT NULL," +
                            "  `User_Id` INT NULL," +
                            "  `Bill_No` TEXT(16) NULL COMMENT '16-digit-long string'," +
                            "  `Bill_Amount` REAL COMMENT 'non-negative real number'," +
                            "  `Bill_Time` DATETIME NULL," +
                            "  PRIMARY KEY (`Bill_Id`)," +
                            "  INDEX `User_Id_idx` (`User_Id` ASC)," +
                            "  INDEX `Cart_Id_idx` (`Cart_Id` ASC))" +
                            "ENGINE = InnoDB;";

            String createBillInfoTableCommand =
                    "DROP TABLE IF EXISTS `Bill_Info` ;" +
                    "CREATE TABLE IF NOT EXISTS `Bill_Info` (" +
                    "  `Bill_Info_Id` INT auto_increment," +
                    "  `Bill_Id` INT NULL," +
                    "  `Goods_Id` INT NULL," +
                    "  `Goods_Num` INT NULL COMMENT 'non-negative integer'," +
                    "  `Goods_Price` REAL NULL COMMENT 'non-negative real number'," +
                    "  PRIMARY KEY (`Bill_Info_Id`)," +
                    "  INDEX `Goods_Id_idx` (`Goods_Id` ASC)," +
                    "  INDEX `Bill_Id_idx` (`Bill_Id` ASC))" +
                    "ENGINE = InnoDB;";
            st.executeUpdate(createUserTableCommand + createBillTableCommand + createBillInfoTableCommand);
            conn.commit();
            System.out.print("Successfully Created the tables remotely.");
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    public static void insertData(Connection conn1, Connection conn2) {
        try {
            Statement st1 = conn1.createStatement();
            String insertUser =
                    "INSERT INTO `User` VALUES" +
                            " (1, 'A', 'Alice11', '0', 'Dongchuan 800', '0')," +
                            " (2, 'B', 'Tom22', '1', 'Meichuan 300', '0');";
            Statement st2 = conn2.createStatement();
            String insertGoods =
                    "INSERT INTO `Goods` VALUES" +
                            " (1, 'Biscuit', 3.2,  50)," +
                            " (2, 'Juice', 6.3, 100)," +
                            " (3, 'Dress', 110, 200);";
            st1.executeUpdate(insertUser);
            conn1.commit();
            st2.executeUpdate(insertGoods);
            conn2.commit();
            } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    public static void scene1_userA(Connection conn) {
        try {
            Statement stat = conn.createStatement();
            String sql1 = "select Goods_Name from Goods where Goods_Price > 100;";
            ResultSet rs1 =  stat.executeQuery(sql1);

            // Print Goods_Name
            while (rs1.next()) {
                System.out.println("Goods price higher than 100: " + rs1.getString("Goods_Name"));
            }
            rs1.close();
        } catch(Exception e) {
            e.printStackTrace();
        }
    }

    public static void scene1_userB(Connection conn) {
        try {
            Statement stat = conn.createStatement();
            stat.executeUpdate("UPDATE Goods SET Goods_Price = 0.9 * Goods_Price;");
        }
        catch (Exception e) {
            e.printStackTrace();
            try {
                //An error occured so we rollback the changes.
                conn.rollback();
            } catch (SQLException ex1) {
                ex1.printStackTrace();
            }
        }
    }

    public static void insertBillInfo(Connection conn1, Connection conn2,  int bill_id, int goods_id, int goods_num) {
        try {
            // Check if we have enough stock
            String findStockcommand = String.format(
                    "Select Goods_Stock from Goods Where Goods.Goods_Id = %d;", goods_id);

            Statement stat1 = conn1.createStatement();
            Statement stat2 = conn2.createStatement();

            ResultSet rs = stat2.executeQuery(findStockcommand);
            if (!rs.next()) {
                System.out.println(String.format("Failed to get stock from goods %d", goods_id));
                return;
            }

            // Check if we have enough goods stocks
            int goods_stock = rs.getInt("Goods_Stock");

            if (goods_stock < goods_num) {
                System.out.println(String.format("Goods %d don't have enough Stock!", goods_id));
                return;
            }

            // Insert into Bill_Info
            stat1.executeUpdate(String.format("INSERT INTO Bill_Info (Bill_Id, Goods_Id, Goods_Num) VALUES"
                    + " (%d, %d, %d);", bill_id, goods_id, goods_num));

            // Update Goods Stock
            stat2.executeUpdate(String.format("UPDATE Goods SET Goods.Goods_Stock = %d Where Goods.Goods_Id = %d;",
                    goods_stock - goods_num, goods_id));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public static void scene2_userA(Connection conn1, Connection conn2) {
        try {
            insertBillInfo(conn1, conn2, 1, 1, 30);
            insertBillInfo(conn1, conn2, 1, 2, 50);
            conn1.commit();
        }
        catch (SQLException ex) {
            ex.printStackTrace();
            try {
                //An error occured so we rollback the changes.
                conn1.rollback();
                conn2.rollback();
            } catch (SQLException ex1) {
                ex1.printStackTrace();
            }
        }
    }

    public static void scene2_userB(Connection conn1, Connection conn2) {
        try {
            insertBillInfo(conn1, conn2, 2, 2, 70);
            insertBillInfo(conn1, conn2, 2, 3, 80);

            conn2.commit();
        }
        catch (SQLException ex) {
            ex.printStackTrace();
            try {
                //An error occured so we rollback the changes.
                conn2.rollback();
            } catch (SQLException ex1) {
                ex.printStackTrace();
            }
        }
    }

    public static void main(String[] args) throws SQLException {
        //true represents print XA logs for debugging
        boolean logXaCommands = true;

        // Conn1 For Scene1
        Connection conn1 = DriverManager.getConnection("jdbc:mysql://202.120.38.131:3306/db517021910745?useSSL=false" +
                "&allowMultiQueries=true", "517021910745", "123456");
        // Conn2 and Conn3 For Scene2
        Connection conn2 = DriverManager.getConnection("jdbc:mysql://202.120.38.131:3306/db517021910745?useSSL=false" +
                "&allowMultiQueries=true", "517021910745", "123456");
        Connection conn3 = DriverManager.getConnection("jdbc:mysql://localhost:3306/ex3?useSSL=false",
                "ex3","");

        conn1.setAutoCommit(false);
        conn2.setAutoCommit(false);
        conn3.setAutoCommit(false);


        // Gain the instance of resource management(RM2)
        XAConnection xaConn1 = new MysqlXAConnection((com.mysql.jdbc.Connection) conn1, logXaCommands);
        XAResource rm1 = xaConn1.getXAResource();
        XAConnection xaConn2 = new MysqlXAConnection((com.mysql.jdbc .Connection) conn2, logXaCommands);
        XAResource rm2 = xaConn2.getXAResource();
        XAConnection xaConn3 = new MysqlXAConnection((com.mysql.jdbc .Connection) conn3, logXaCommands);
        XAResource rm3 = xaConn3.getXAResource();

        // Insert Table remotely
        createTableRemote(conn1);
        insertData(conn1, conn3);

        // Executing a distributed transaction using 2PC(2-phase-commit)
        try {
            // Generates the transaction id
            Xid xid1 = new MysqlXid(new byte[] { 0x01 }, new byte[] { 0x02 }, 100);
            Xid xid2 = new MysqlXid(new byte[] { 0x011 }, new byte[] { 0x012 }, 100);
            Xid xid3 = new MysqlXid(new byte[] { 0x010 }, new byte[] { 0x012 }, 100);
            Xid xid4 = new MysqlXid(new byte[] { 0x00 }, new byte[] { 0x012 }, 100);

            // Scene1 UserA
            rm3.start(xid1, XAResource.TMNOFLAGS);  //One of TMNOFLAGS, TMJOIN, or TMRESUME.
            scene1_userA(conn3);
            rm3.end(xid1, XAResource.TMSUCCESS);

            // Two-Phase commit
            int ret1 = rm3.prepare(xid1);
            rm3.commit(xid1, false);

            // Scene1 UserB
            rm1.start(xid2, XAResource.TMNOFLAGS);
            scene1_userB(conn3);
            rm1.end(xid2, XAResource.TMSUCCESS);

            int ret2 = rm1.prepare(xid2);
            rm1.commit(xid2, false);

            // Scene2 UserA
            rm1.start(xid3, XAResource.TMNOFLAGS);  //One of TMNOFLAGS, TMJOIN, or TMRESUME.
            scene2_userA(conn2, conn3);
            rm1.end(xid3, XAResource.TMSUCCESS);

            int ret3 = rm1.prepare(xid3);
            rm1.commit(xid3, false);

            // Scene2 UserB
            rm1.start(xid4, XAResource.TMNOFLAGS);  //One of TMNOFLAGS, TMJOIN, or TMRESUME.
            scene2_userB(conn2, conn3);
            rm1.end(xid4, XAResource.TMSUCCESS);

            // Two-Phase commit
            int ret4 = rm1.prepare(xid4);
            rm1.commit(xid4, false);

        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}


