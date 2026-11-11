/* Fabric Northwind Orchestration
   Transactional analytical-model refresh with date dimension */

CREATE PROCEDURE analytics.usp_refresh_analytical_model
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MinimumDate DATE;
    DECLARE @MaximumDate DATE;
    DECLARE @ExpectedDateRows BIGINT;

    SELECT
        @MinimumDate = MIN(DateValue),
        @MaximumDate = MAX(DateValue)
    FROM
    (
        SELECT CAST(OrderDate AS DATE) AS DateValue FROM dbo.Orders WHERE OrderDate IS NOT NULL
        UNION ALL
        SELECT CAST(RequiredDate AS DATE) FROM dbo.Orders WHERE RequiredDate IS NOT NULL
        UNION ALL
        SELECT CAST(ShippedDate AS DATE) FROM dbo.Orders WHERE ShippedDate IS NOT NULL
    ) AS SourceDates;

    IF @MinimumDate IS NULL OR @MaximumDate IS NULL
        THROW 51001, 'The source date range is empty.', 1;

    SET @ExpectedDateRows = DATEDIFF(DAY, @MinimumDate, @MaximumDate) + 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        TRUNCATE TABLE analytics.FactSales;
        TRUNCATE TABLE analytics.DimDate;
        TRUNCATE TABLE analytics.DimProduct;
        TRUNCATE TABLE analytics.DimSupplier;
        TRUNCATE TABLE analytics.DimShipper;
        TRUNCATE TABLE analytics.DimEmployee;
        TRUNCATE TABLE analytics.DimCustomer;
        TRUNCATE TABLE analytics.DimCategory;

        WITH DateNumbers AS
        (
            SELECT TOP (@ExpectedDateRows)
                ROW_NUMBER() OVER (ORDER BY OrderID, ProductID) - 1 AS DayOffset
            FROM dbo.Order_Details
        ),
        DateValues AS
        (
            SELECT DATEADD(DAY, CAST(DayOffset AS INT), @MinimumDate) AS FullDate
            FROM DateNumbers
        )
        INSERT INTO analytics.DimDate
        (
            DateKey, FullDate, CalendarYear, CalendarQuarter, QuarterName,
            MonthNumber, MonthName, YearMonth, DayOfMonth,
            DayOfWeekNumber, DayOfWeekName, IsWeekend
        )
        SELECT
            CAST(CONVERT(CHAR(8), FullDate, 112) AS INT),
            FullDate,
            DATEPART(YEAR, FullDate),
            DATEPART(QUARTER, FullDate),
            CAST(CONCAT('Q', DATEPART(QUARTER, FullDate)) AS VARCHAR(2)),
            DATEPART(MONTH, FullDate),
            CAST(DATENAME(MONTH, FullDate) AS VARCHAR(20)),
            CAST(CONCAT(DATEPART(YEAR, FullDate), '-', RIGHT(CONCAT('0', DATEPART(MONTH, FullDate)), 2)) AS VARCHAR(7)),
            DATEPART(DAY, FullDate),
            (DATEDIFF(DAY, CAST('19000101' AS DATE), FullDate) % 7) + 1,
            CAST(DATENAME(WEEKDAY, FullDate) AS VARCHAR(20)),
            CAST(CASE WHEN (DATEDIFF(DAY, CAST('19000101' AS DATE), FullDate) % 7) + 1 IN (6, 7) THEN 1 ELSE 0 END AS BIT)
        FROM DateValues;

        INSERT INTO analytics.DimCategory (CategoryKey, CategoryName, CategoryDescription)
        SELECT CAST(CategoryID AS INT), CAST(CategoryName AS VARCHAR(100)), CAST(Description AS VARCHAR(1000))
        FROM dbo.Categories;

        INSERT INTO analytics.DimCustomer
        (CustomerKey, CompanyName, ContactName, ContactTitle, Address, City, Region, PostalCode, Country, Phone, Fax)
        SELECT CAST(CustomerID AS VARCHAR(10)), CAST(CompanyName AS VARCHAR(100)), CAST(ContactName AS VARCHAR(100)),
               CAST(ContactTitle AS VARCHAR(100)), CAST(Address AS VARCHAR(200)), CAST(City AS VARCHAR(100)),
               CAST(Region AS VARCHAR(100)), CAST(PostalCode AS VARCHAR(20)), CAST(Country AS VARCHAR(100)),
               CAST(Phone AS VARCHAR(50)), CAST(Fax AS VARCHAR(50))
        FROM dbo.Customers;

        INSERT INTO analytics.DimEmployee
        (EmployeeKey, FirstName, LastName, EmployeeName, JobTitle, City, Region, Country, ManagerKey)
        SELECT CAST(EmployeeID AS INT), CAST(FirstName AS VARCHAR(50)), CAST(LastName AS VARCHAR(50)),
               CAST(CONCAT(FirstName, ' ', LastName) AS VARCHAR(101)), CAST(Title AS VARCHAR(100)),
               CAST(City AS VARCHAR(100)), CAST(Region AS VARCHAR(100)), CAST(Country AS VARCHAR(100)),
               CAST(ReportsTo AS INT)
        FROM dbo.Employees;

        INSERT INTO analytics.DimShipper (ShipperKey, ShipperName, Phone)
        SELECT CAST(ShipperID AS INT), CAST(CompanyName AS VARCHAR(100)), CAST(Phone AS VARCHAR(50))
        FROM dbo.Shippers;

        INSERT INTO analytics.DimSupplier
        (SupplierKey, SupplierName, ContactName, ContactTitle, City, Region, Country, Phone)
        SELECT CAST(SupplierID AS INT), CAST(CompanyName AS VARCHAR(100)), CAST(ContactName AS VARCHAR(100)),
               CAST(ContactTitle AS VARCHAR(100)), CAST(City AS VARCHAR(100)), CAST(Region AS VARCHAR(100)),
               CAST(Country AS VARCHAR(100)), CAST(Phone AS VARCHAR(50))
        FROM dbo.Suppliers;

        INSERT INTO analytics.DimProduct
        (ProductKey, ProductName, SupplierKey, CategoryKey, QuantityPerUnit, UnitPrice,
         UnitsInStock, UnitsOnOrder, ReorderLevel, IsDiscontinued)
        SELECT CAST(ProductID AS INT), CAST(ProductName AS VARCHAR(100)), CAST(SupplierID AS INT),
               CAST(CategoryID AS INT), CAST(QuantityPerUnit AS VARCHAR(100)), CAST(UnitPrice AS DECIMAL(18,2)),
               CAST(UnitsInStock AS INT), CAST(UnitsOnOrder AS INT), CAST(ReorderLevel AS INT), CAST(Discontinued AS BIT)
        FROM dbo.Products;

        INSERT INTO analytics.FactSales
        (OrderKey, ProductKey, CustomerKey, EmployeeKey, ShipperKey, Quantity, UnitPrice,
         DiscountRate, GrossSalesAmount, NetSalesAmount, OrderFreight,
         OrderDateKey, RequiredDateKey, ShippedDateKey)
        SELECT
            CAST(od.OrderID AS INT), CAST(od.ProductID AS INT), CAST(o.CustomerID AS VARCHAR(10)),
            CAST(o.EmployeeID AS INT), CAST(o.ShipVia AS INT), CAST(od.Quantity AS INT),
            CAST(od.UnitPrice AS DECIMAL(18,2)), CAST(od.Discount AS DECIMAL(9,6)),
            CAST(od.Quantity * od.UnitPrice AS DECIMAL(18,2)),
            CAST(od.Quantity * od.UnitPrice * (1 - od.Discount) AS DECIMAL(18,2)),
            CAST(o.Freight AS DECIMAL(18,2)),
            CAST(CONVERT(CHAR(8), CAST(o.OrderDate AS DATE), 112) AS INT),
            CAST(CONVERT(CHAR(8), CAST(o.RequiredDate AS DATE), 112) AS INT),
            CASE WHEN o.ShippedDate IS NULL THEN NULL
                 ELSE CAST(CONVERT(CHAR(8), CAST(o.ShippedDate AS DATE), 112) AS INT) END
        FROM dbo.Order_Details AS od
        INNER JOIN dbo.Orders AS o ON o.OrderID = od.OrderID;

        IF (SELECT COUNT_BIG(*) FROM analytics.DimDate) <> @ExpectedDateRows THROW 51101, 'DimDate row-count validation failed.', 1;
        IF (SELECT COUNT_BIG(*) FROM analytics.DimCategory) <> 8 THROW 51102, 'DimCategory row-count validation failed.', 1;
        IF (SELECT COUNT_BIG(*) FROM analytics.DimCustomer) <> 91 THROW 51103, 'DimCustomer row-count validation failed.', 1;
        IF (SELECT COUNT_BIG(*) FROM analytics.DimEmployee) <> 9 THROW 51104, 'DimEmployee row-count validation failed.', 1;
        IF (SELECT COUNT_BIG(*) FROM analytics.DimProduct) <> 77 THROW 51105, 'DimProduct row-count validation failed.', 1;
        IF (SELECT COUNT_BIG(*) FROM analytics.DimShipper) <> 3 THROW 51106, 'DimShipper row-count validation failed.', 1;
        IF (SELECT COUNT_BIG(*) FROM analytics.DimSupplier) <> 29 THROW 51107, 'DimSupplier row-count validation failed.', 1;
        IF (SELECT COUNT_BIG(*) FROM analytics.FactSales) <> 2155 THROW 51108, 'FactSales row-count validation failed.', 1;

        IF EXISTS (SELECT DateKey FROM analytics.DimDate GROUP BY DateKey HAVING COUNT_BIG(*) > 1)
            THROW 51109, 'DimDate DateKey uniqueness validation failed.', 1;
        IF EXISTS (SELECT FullDate FROM analytics.DimDate GROUP BY FullDate HAVING COUNT_BIG(*) > 1)
            THROW 51110, 'DimDate FullDate uniqueness validation failed.', 1;
        IF (SELECT MIN(FullDate) FROM analytics.DimDate) <> @MinimumDate
            THROW 51111, 'DimDate minimum-date validation failed.', 1;
        IF (SELECT MAX(FullDate) FROM analytics.DimDate) <> @MaximumDate
            THROW 51112, 'DimDate maximum-date validation failed.', 1;

        IF EXISTS (SELECT CategoryKey FROM analytics.DimCategory GROUP BY CategoryKey HAVING CategoryKey IS NULL OR COUNT_BIG(*) > 1)
            THROW 51113, 'DimCategory key validation failed.', 1;
        IF EXISTS (SELECT CustomerKey FROM analytics.DimCustomer GROUP BY CustomerKey HAVING CustomerKey IS NULL OR COUNT_BIG(*) > 1)
            THROW 51114, 'DimCustomer key validation failed.', 1;
        IF EXISTS (SELECT EmployeeKey FROM analytics.DimEmployee GROUP BY EmployeeKey HAVING EmployeeKey IS NULL OR COUNT_BIG(*) > 1)
            THROW 51115, 'DimEmployee key validation failed.', 1;
        IF EXISTS (SELECT ProductKey FROM analytics.DimProduct GROUP BY ProductKey HAVING ProductKey IS NULL OR COUNT_BIG(*) > 1)
            THROW 51116, 'DimProduct key validation failed.', 1;
        IF EXISTS (SELECT ShipperKey FROM analytics.DimShipper GROUP BY ShipperKey HAVING ShipperKey IS NULL OR COUNT_BIG(*) > 1)
            THROW 51117, 'DimShipper key validation failed.', 1;
        IF EXISTS (SELECT SupplierKey FROM analytics.DimSupplier GROUP BY SupplierKey HAVING SupplierKey IS NULL OR COUNT_BIG(*) > 1)
            THROW 51118, 'DimSupplier key validation failed.', 1;
        IF EXISTS (SELECT OrderKey, ProductKey FROM analytics.FactSales GROUP BY OrderKey, ProductKey HAVING OrderKey IS NULL OR ProductKey IS NULL OR COUNT_BIG(*) > 1)
            THROW 51119, 'FactSales grain validation failed.', 1;

        IF EXISTS (SELECT 1 FROM analytics.FactSales f LEFT JOIN analytics.DimCustomer d ON d.CustomerKey=f.CustomerKey WHERE d.CustomerKey IS NULL)
            THROW 51120, 'FactSales customer relationship validation failed.', 1;
        IF EXISTS (SELECT 1 FROM analytics.FactSales f LEFT JOIN analytics.DimEmployee d ON d.EmployeeKey=f.EmployeeKey WHERE d.EmployeeKey IS NULL)
            THROW 51121, 'FactSales employee relationship validation failed.', 1;
        IF EXISTS (SELECT 1 FROM analytics.FactSales f LEFT JOIN analytics.DimProduct d ON d.ProductKey=f.ProductKey WHERE d.ProductKey IS NULL)
            THROW 51122, 'FactSales product relationship validation failed.', 1;
        IF EXISTS (SELECT 1 FROM analytics.FactSales f LEFT JOIN analytics.DimShipper d ON d.ShipperKey=f.ShipperKey WHERE d.ShipperKey IS NULL)
            THROW 51123, 'FactSales shipper relationship validation failed.', 1;
        IF EXISTS (SELECT 1 FROM analytics.FactSales f LEFT JOIN analytics.DimDate d ON d.DateKey=f.OrderDateKey WHERE f.OrderDateKey IS NULL OR d.DateKey IS NULL)
            THROW 51124, 'FactSales order-date relationship validation failed.', 1;
        IF EXISTS (SELECT 1 FROM analytics.FactSales f LEFT JOIN analytics.DimDate d ON d.DateKey=f.RequiredDateKey WHERE f.RequiredDateKey IS NULL OR d.DateKey IS NULL)
            THROW 51125, 'FactSales required-date relationship validation failed.', 1;
        IF EXISTS (SELECT 1 FROM analytics.FactSales f LEFT JOIN analytics.DimDate d ON d.DateKey=f.ShippedDateKey WHERE f.ShippedDateKey IS NOT NULL AND d.DateKey IS NULL)
            THROW 51126, 'FactSales shipped-date relationship validation failed.', 1;

        IF EXISTS
        (
            SELECT 1 FROM dbo.Orders
            WHERE OrderDate IS NULL OR RequiredDate IS NULL OR RequiredDate < OrderDate
               OR (ShippedDate IS NOT NULL AND ShippedDate < OrderDate)
        )
            THROW 51127, 'Source order-date chronology validation failed.', 1;

        IF EXISTS
        (
            SELECT 1 FROM analytics.FactSales
            WHERE Quantity IS NULL OR Quantity <= 0
               OR UnitPrice IS NULL OR UnitPrice < 0
               OR DiscountRate IS NULL OR DiscountRate < 0 OR DiscountRate > 1
               OR OrderFreight IS NULL OR OrderFreight < 0
               OR GrossSalesAmount IS NULL OR NetSalesAmount IS NULL
               OR ABS(GrossSalesAmount - CAST(Quantity * UnitPrice AS DECIMAL(18,2))) > 0.01
               OR ABS(NetSalesAmount - CAST(Quantity * UnitPrice * (1 - DiscountRate) AS DECIMAL(18,2))) > 0.01
        )
            THROW 51128, 'FactSales business-rule validation failed.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

GO