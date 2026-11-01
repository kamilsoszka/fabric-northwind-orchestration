-- Rebuild the curated analytical model after each full source reload
CREATE   PROCEDURE analytics.usp_refresh_analytical_model
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE analytics.FactSales;
    TRUNCATE TABLE analytics.DimProduct;
    TRUNCATE TABLE analytics.DimSupplier;
    TRUNCATE TABLE analytics.DimShipper;
    TRUNCATE TABLE analytics.DimEmployee;
    TRUNCATE TABLE analytics.DimCustomer;
    TRUNCATE TABLE analytics.DimCategory;

    INSERT INTO analytics.DimCategory
    (
        CategoryKey,
        CategoryName,
        CategoryDescription
    )
    SELECT
        CAST(CategoryID AS INT),
        CAST(CategoryName AS VARCHAR(100)),
        CAST(Description AS VARCHAR(1000))
    FROM dbo.Categories;

    INSERT INTO analytics.DimCustomer
    (
        CustomerKey,
        CompanyName,
        ContactName,
        ContactTitle,
        Address,
        City,
        Region,
        PostalCode,
        Country,
        Phone,
        Fax
    )
    SELECT
        CAST(CustomerID AS VARCHAR(10)),
        CAST(CompanyName AS VARCHAR(100)),
        CAST(ContactName AS VARCHAR(100)),
        CAST(ContactTitle AS VARCHAR(100)),
        CAST(Address AS VARCHAR(200)),
        CAST(City AS VARCHAR(100)),
        CAST(Region AS VARCHAR(100)),
        CAST(PostalCode AS VARCHAR(20)),
        CAST(Country AS VARCHAR(100)),
        CAST(Phone AS VARCHAR(50)),
        CAST(Fax AS VARCHAR(50))
    FROM dbo.Customers;

    INSERT INTO analytics.DimEmployee
    (
        EmployeeKey,
        FirstName,
        LastName,
        EmployeeName,
        JobTitle,
        City,
        Region,
        Country,
        ManagerKey
    )
    SELECT
        CAST(EmployeeID AS INT),
        CAST(FirstName AS VARCHAR(50)),
        CAST(LastName AS VARCHAR(50)),
        CAST(CONCAT(FirstName, ' ', LastName) AS VARCHAR(101)),
        CAST(Title AS VARCHAR(100)),
        CAST(City AS VARCHAR(100)),
        CAST(Region AS VARCHAR(100)),
        CAST(Country AS VARCHAR(100)),
        CAST(ReportsTo AS INT)
    FROM dbo.Employees;

    INSERT INTO analytics.DimShipper
    (
        ShipperKey,
        ShipperName,
        Phone
    )
    SELECT
        CAST(ShipperID AS INT),
        CAST(CompanyName AS VARCHAR(100)),
        CAST(Phone AS VARCHAR(50))
    FROM dbo.Shippers;

    INSERT INTO analytics.DimSupplier
    (
        SupplierKey,
        SupplierName,
        ContactName,
        ContactTitle,
        City,
        Region,
        Country,
        Phone
    )
    SELECT
        CAST(SupplierID AS INT),
        CAST(CompanyName AS VARCHAR(100)),
        CAST(ContactName AS VARCHAR(100)),
        CAST(ContactTitle AS VARCHAR(100)),
        CAST(City AS VARCHAR(100)),
        CAST(Region AS VARCHAR(100)),
        CAST(Country AS VARCHAR(100)),
        CAST(Phone AS VARCHAR(50))
    FROM dbo.Suppliers;

    INSERT INTO analytics.DimProduct
    (
        ProductKey,
        ProductName,
        SupplierKey,
        CategoryKey,
        QuantityPerUnit,
        UnitPrice,
        UnitsInStock,
        UnitsOnOrder,
        ReorderLevel,
        IsDiscontinued
    )
    SELECT
        CAST(ProductID AS INT),
        CAST(ProductName AS VARCHAR(100)),
        CAST(SupplierID AS INT),
        CAST(CategoryID AS INT),
        CAST(QuantityPerUnit AS VARCHAR(100)),
        CAST(UnitPrice AS DECIMAL(18, 2)),
        CAST(UnitsInStock AS INT),
        CAST(UnitsOnOrder AS INT),
        CAST(ReorderLevel AS INT),
        CAST(Discontinued AS BIT)
    FROM dbo.Products;

    INSERT INTO analytics.FactSales
    (
        OrderKey,
        ProductKey,
        CustomerKey,
        EmployeeKey,
        ShipperKey,
        Quantity,
        UnitPrice,
        DiscountRate,
        GrossSalesAmount,
        NetSalesAmount,
        OrderFreight
    )
    SELECT
        CAST(od.OrderID AS INT),
        CAST(od.ProductID AS INT),
        CAST(o.CustomerID AS VARCHAR(10)),
        CAST(o.EmployeeID AS INT),
        CAST(o.ShipVia AS INT),
        CAST(od.Quantity AS INT),
        CAST(od.UnitPrice AS DECIMAL(18, 2)),
        CAST(od.Discount AS DECIMAL(9, 6)),
        CAST(od.Quantity * od.UnitPrice AS DECIMAL(18, 2)),
        CAST(
            od.Quantity * od.UnitPrice * (1 - od.Discount)
            AS DECIMAL(18, 2)
        ),
        CAST(o.Freight AS DECIMAL(18, 2))
    FROM dbo.Order_Details AS od
    INNER JOIN dbo.Orders AS o
        ON od.OrderID = o.OrderID;
END;

GO