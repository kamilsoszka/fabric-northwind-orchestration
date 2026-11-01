-- Prepare Northwind staging tables for a full reload
CREATE   PROCEDURE dbo.usp_prepare_northwind_full_load
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE dbo.Order_Details;
    TRUNCATE TABLE dbo.Orders;
    TRUNCATE TABLE dbo.Products;
    TRUNCATE TABLE dbo.Categories;
    TRUNCATE TABLE dbo.Customers;
    TRUNCATE TABLE dbo.Employees;
    TRUNCATE TABLE dbo.Shippers;
    TRUNCATE TABLE dbo.Suppliers;
END;

GO