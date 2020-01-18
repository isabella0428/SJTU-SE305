import java.sql.SQLException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.Statement;
import java.sql.ResultSet;

class Thread1 extends Thread{
    private Connection conn;
    public Thread1(Connection conn) {
        this.conn=conn;
    }
    public void selectNamePrice(Statement stat) {
        try {
            String sql1 = "select Goods_Name from Goods where Goods_Price > 100;";
            String sql2 = "select Goods_Price from Goods where Goods_Id = 3;";
            ResultSet rs1 =  stat.executeQuery(sql1);

            // Print Goods_Name
            while (rs1.next()) {
                System.out.println("Goods price higher than 100: " + rs1.getString("Goods_Name"));
            }
            rs1.close();
            ResultSet rs2 = stat.executeQuery(sql2);

            // Print Goods_Price
            while (rs2.next()) {
                System.out.println("Goods No.3 price: " + rs2.getFloat("Goods_Price"));
            }
            rs2.close();
        } catch(Exception e) {
            e.printStackTrace();
        }

    }
    public void run() {
        try {
            System.out.println("Thread1 running");
            Statement stat = conn.createStatement();

            // First time read select  --- Detect virtual read problem
            System.out.println("First Time Select");
            selectNamePrice(stat);

            // Wait for thread2
            try {
                Thread.currentThread().sleep(1000);
            }catch(Exception e) {
                e.printStackTrace();
            }

            // Second time select
            System.out.println("Second Time Select");
            selectNamePrice(stat);
            System.out.println("Thread1 exits");
            conn.commit();
        }
        catch (SQLException ex) {
            ex.printStackTrace();
            try {
                // An error occurred so we rollback the changes.
                this.conn.rollback();
            } catch (SQLException ex1) {
                ex1.printStackTrace();
            }
        }
    }
}

class Thread2 extends Thread{
    private Connection conn;
    public Thread2(Connection conn) {
        this.conn=conn;
    }
    public void run() {
        try {
            System.out.println("Thread2 running");
            Statement stat = conn.createStatement();

            // Wait for thread1 to select for the first itme
            try {
                Thread.currentThread().sleep(400);
            }catch(Exception e) {
                e.printStackTrace();
            }

            stat.executeQuery("SELECT Goods_Price from Goods WHERE Goods_Price > 100 for Update;");
            stat.executeUpdate("UPDATE Goods SET Goods_Price = 0.9 * Goods_Price;");
            conn.commit();

            // Test Dirty Read
            stat.executeUpdate("INSERT INTO Goods VALUES(4, 'Gold', 200, 10);");
            // Wait for thread2
            try {
                Thread.currentThread().sleep(2000);
            }catch(Exception e) {
                e.printStackTrace();
            }
            conn.rollback();
            System.out.println("Thread2 exits");
        }
        catch (SQLException ex) {
            ex.printStackTrace();
            try {
                //An error occured so we rollback the changes.
                this.conn.rollback();
            } catch (SQLException ex1) {
                ex1.printStackTrace();
            }
        }
    }
}

class Thread3 extends Thread{
    private Connection conn;
    public Thread3(Connection conn) {
        this.conn=conn;
    }

    public void lock(String table1, String table2) {
        try {
            Statement stat = conn.createStatement();
            stat.executeQuery(String.format("Lock tables %s write, %s write;", table1, table2));
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    public void unlock() {
        try {
            Statement stat = conn.createStatement();
            stat.executeQuery("Unlock tables;");
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    public void insertBillInfo(int bill_id, int goods_id, int goods_num) {
        try {
            // Check if we have enough stock
            String findStockcommand = String.format(
                    "Select Goods_Stock from Goods Where Goods.Goods_Id = %d;", goods_id);

            Statement stat = conn.createStatement();

            ResultSet rs = stat.executeQuery(findStockcommand);
            if(!rs.next()) {
                System.out.println(String.format("Failed to get stock from goods %d", goods_id));
                return;
            }

            // Check if we have enough goods stocks
            int goods_stock = rs.getInt("Goods_Stock");

            if(goods_stock < goods_num) {
                System.out.println(String.format("Goods %d don't have enough Stock!", goods_id));
                return;
            }

            // Insert into Bill_Info
            stat.executeUpdate(String.format("INSERT INTO Bill_Info (Bill_Id, Goods_Id, Goods_Num) VALUES"
                    + " (%d, %d, %d);", bill_id, goods_id, goods_num));

            // Update Goods Stock
            stat.executeUpdate(String.format("UPDATE Goods SET Goods.Goods_Stock = %d Where Goods.Goods_Id = %d;",
                    goods_stock - goods_num, goods_id));
        }catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void run() {
        try {
            System.out.println("Thread3 running");
            // lock("Goods", "Bill_Info");
            insertBillInfo(1, 1, 30);
            insertBillInfo(1, 2, 50);
            conn.commit();
            // unlock();
            System.out.println("Thread3 exits");
        }
        catch (SQLException ex) {
            ex.printStackTrace();
            try {
                //An error occured so we rollback the changes.
                this.conn.rollback();
            } catch (SQLException ex1) {
                ex1.printStackTrace();
            }
        }
    }
}

class Thread4 extends Thread3{
    private Connection conn;
    public Thread4(Connection conn) {
        super(conn);
        this.conn = conn;
    }

    @Override
    public void run() {
        try {
            System.out.println("Thread4 running");
            //lock("Goods", "Bill_Info");

            // Wait thread3 to finish
            try {
                Thread.currentThread().sleep(2000);
            } catch(Exception e) {
                e.printStackTrace();
            }

            insertBillInfo(2, 2, 70);
            insertBillInfo(2, 3, 80);
            //unlock();
            conn.commit();
            System.out.println("Thread4 exits");
        }
        catch (SQLException ex) {
            ex.printStackTrace();
            try {
                //An error occured so we rollback the changes.
                this.conn.rollback();
            } catch (SQLException ex1) {
                ex1.printStackTrace();
            }
        }
    }
}

class Thread5 extends Thread{
    private Connection conn;
    public Thread5(Connection conn) {
        this.conn=conn;
    }
    public void lock(String table1, String command) {
        try {
            Statement stat = conn.createStatement();
            stat.executeQuery(String.format("Lock table %s %s", table1, command));
            System.out.println("Got the lock");
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    public void unlock() {
        try {
            Statement stat = conn.createStatement();
            stat.executeQuery("Unlock tables;");
            System.out.println("Release the lock");
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }
    public void run() {
        try {
            System.out.println("Thread5 running");
            Statement stat = conn.createStatement();

            lock("Goods", "write");

            // First time read select  --- Detect virtual read problem
            stat.executeUpdate("UPDATE Goods SET Goods_Price = 100 WHERE Goods_Id = 1");
            unlock();

            conn.commit();
            System.out.println("Thread5 exits");
        }
        catch (SQLException ex) {
            ex.printStackTrace();
            try {
                // An error occurred so we rollback the changes.
                this.conn.rollback();
            } catch (SQLException ex1) {
                ex1.printStackTrace();
            }
        }
    }
}

class Thread6 extends Thread5{
    private Connection conn;
    public Thread6(Connection conn) {
        super(conn);
        this.conn = conn;
    }
    public void run() {
        try {
            System.out.println("Thread6 running");
            Statement stat = conn.createStatement();

            lock("Goods", "write");

            // First time read select  --- Detect virtual read problem
            stat.executeUpdate("UPDATE Goods SET Goods_Price = 1 WHERE Goods_Id = 1");
            unlock();
            conn.commit();
            System.out.println("Thread6 exits");
        }
        catch (SQLException ex) {
            ex.printStackTrace();
            try {
                // An error occurred so we rollback the changes.
                this.conn.rollback();
            } catch (SQLException ex1) {
                ex1.printStackTrace();
            }
        }
    }
}

class Thread7 extends Thread5{
    private Connection conn;
    public Thread7(Connection conn) {
        super(conn);
        this.conn=conn;
    }
    public void run() {
        try {
            System.out.println("Thread7 running");
            Statement stat = conn.createStatement();

            lock("Goods", "write");

            // First time read select  --- Detect virtual read problem
            stat.executeUpdate("UPDATE Goods SET Goods_Price = 3 WHERE Goods_Id = 1");

            System.out.println("Thread7 exits");
            conn.commit();
        }
        catch (SQLException ex) {
            ex.printStackTrace();
            try {
                // An error occurred so we rollback the changes.
                this.conn.rollback();
            } catch (SQLException ex1) {
                ex1.printStackTrace();
            }
        }
    }
}

class Thread8 extends Thread5{
    private Connection conn;
    public Thread8(Connection conn) {
        super(conn);
        this.conn=conn;
    }
    public void run() {
        try {
            System.out.println("Thread8 running");
            Statement stat = conn.createStatement();

            lock("Goods", "write");

            // First time read select  --- Detect virtual read problem
            stat.executeUpdate("UPDATE Goods SET Goods_Price = 0 WHERE Goods_Id = 1");
            unlock();

            System.out.println("Thread8 exits");
            conn.commit();
        }
        catch (SQLException ex) {
            ex.printStackTrace();
            try {
                // An error occurred so we rollback the changes.
                this.conn.rollback();
            } catch (SQLException ex1) {
                ex1.printStackTrace();
            }
        }
    }
}

class Thread9 extends Thread{
    private Connection conn;
    public Thread9(Connection conn) {
        this.conn=conn;
    }

    public void run() {
        try {
            System.out.println("Thread9 running");
            Statement stat = conn.createStatement();

            stat.executeQuery("SELECT * FROM Goods WHERE Goods_Id = 1 FOR UPDATE");
            System.out.println("Thread 9 Got locks for Goods 1");
            stat.executeUpdate("UPDATE Goods SET Goods_Price = 10 WHERE Goods_Id = 1");


            // Wait for thread2
            try {
                Thread.currentThread().sleep(1000);
            }catch(Exception e) {
                e.printStackTrace();
            }

            stat.executeQuery("SELECT * FROM Goods WHERE Goods_Id = 2 FOR UPDATE");
            System.out.println("Thread 9 Got locks for Goods 2");
            stat.executeUpdate("UPDATE Goods SET Goods_Price = 3 WHERE Goods_Id = 2");

            System.out.println("Thread9 exits");
            conn.commit();
        }
        catch (SQLException ex) {
            ex.printStackTrace();
            try {
                // An error occurred so we rollback the changes.
                this.conn.rollback();
            } catch (SQLException ex1) {
                ex1.printStackTrace();
            }
        }
    }
}

class Thread10 extends Thread9{
    private Connection conn;
    public Thread10(Connection conn) {
        super(conn);
        this.conn=conn;
    }
    public void run() {
        try {
            System.out.println("Thread10 running");
            Statement stat = conn.createStatement();

            // Wait for thread10
            try {
                Thread.currentThread().sleep(500);
            }catch(Exception e) {
                e.printStackTrace();
            }

            stat.executeQuery("SELECT * FROM Goods WHERE Goods_Id = 2 FOR UPDATE");
            System.out.println("Thread 10 Got locks for Goods 1");
            stat.executeUpdate("UPDATE Goods SET Goods_Price = 5 WHERE Goods_Id = 1");

            stat.executeQuery("SELECT * FROM Goods WHERE Goods_Id = 1 FOR UPDATE");
            System.out.println("Thread 10 Got locks for Goods 2");
            stat.executeUpdate("UPDATE Goods SET Goods_Price = 6 WHERE Goods_Id = 2");

            System.out.println("Thread10 exits");
            conn.commit();
        }
        catch (SQLException ex) {
            ex.printStackTrace();
            try {
                // An error occurred so we rollback the changes.
                this.conn.rollback();
            } catch (SQLException ex1) {
                ex1.printStackTrace();
            }
        }
    }
}



public class Main1 {
    public static void main(String[] args) throws ClassNotFoundException {
        try {
            Connection conn1 = DriverManager.getConnection("jdbc:mysql://localhost:3308/ex3?useSSL=false",
                    "ex3","ichliebedich11");
            Connection conn2 = DriverManager.getConnection("jdbc:mysql://localhost:3308/ex3?useSSL=false",
                    "ex3","ichliebedich11");
            Connection conn3 = DriverManager.getConnection("jdbc:mysql://localhost:3308/ex3?useSSL=false",
                    "ex3","ichliebedich11");
            Connection conn4 = DriverManager.getConnection("jdbc:mysql://localhost:3308/ex3?useSSL=false",
                    "ex3","ichliebedich11");
            conn1.setAutoCommit(false);
            conn2.setAutoCommit(false);
            conn3.setAutoCommit(false);
            conn4.setAutoCommit(false);
            conn1.setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);
            conn2.setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);

            // Scene 1
//            Thread1 mTh1=new Thread1(conn1);
//            Thread2 mTh2=new Thread2(conn2);
//            mTh2.start();
//            mTh1.start();

            // Scene 2
//            Thread3 mTh3=new Thread3(conn1);
//            Thread4 mTh4=new Thread4(conn2);
//            mTh3.start();
//            mTh4.start();

            // Scene Live Lock
//            Thread5 mTh5 = new Thread5(conn1);
//            Thread6 mTh6 = new Thread6(conn2);
//            Thread7 mTh7 = new Thread7(conn3);
//            Thread8 mTh8 = new Thread8(conn4);
//            mTh5.start();
//            mTh6.start();
//            mTh7.start();
//            mTh8.start();

            // Scene Dead Lock
            Thread9 mTh9 = new Thread9(conn1);
            Thread mTh10 = new Thread10(conn2);
            mTh9.start();
            mTh10.start();
        }
        catch( Exception e )
        {
            e.printStackTrace();
        }
    }

}


