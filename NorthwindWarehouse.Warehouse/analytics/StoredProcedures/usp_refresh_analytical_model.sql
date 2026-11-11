/* ============================================================
   Fabric Northwind Orchestration
   Transactional analytical-model refresh
   ============================================================ */

CREATE PROCEDURE analytics.usp_refresh_analytical_model
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* ----------------------------------------------------
           1. Clear the current analytical model
           ---------------------------------------------------- */

        TRUNCATE TABLE analytics.FactSales;
        TRUNCATE TABLE analytics.DimProduct;
        TRUNCATE TABLE analytics.DimSupplier;
        TRUNCATE TABLE analytics.DimShipper;
        TRUNCATE TABLE analytics.DimEmployee;
        TRUNCATE TABLE analytics.DimCustomer;
        TRUNCATE TABLE analytics.DimCategory;


        /* ----------------------------------------------------
           2. Rebuild the category dimension
           ---------------------------------------------------- */

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


        /* ----------------------------------------------------
           3. Rebuild the customer dimension
           ---------------------------------------------------- */

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


        /* ----------------------------------------------------
           4. Rebuild the employee dimension
           ---------------------------------------------------- */

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
            CAST(
                CONCAT(FirstName, ' ', LastName)
                AS VARCHAR(101)
            ),
            CAST(Title AS VARCHAR(100)),
            CAST(City AS VARCHAR(100)),
            CAST(Region AS VARCHAR(100)),
            CAST(Country AS VARCHAR(100)),
            CAST(ReportsTo AS INT)
        FROM dbo.Employees;


        /* ----------------------------------------------------
           5. Rebuild the shipper dimension
           ---------------------------------------------------- */

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


        /* ----------------------------------------------------
           6. Rebuild the supplier dimension
           ---------------------------------------------------- */

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


        /* ----------------------------------------------------
           7. Rebuild the product dimension
           ---------------------------------------------------- */

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


        /* ----------------------------------------------------
           8. Rebuild the sales fact table

           Grain:
           One row per order-product line.

           OrderFreight is an order-level value repeated across
           order lines. Do not aggregate it across FactSales
           without order-level handling or allocation.
           ---------------------------------------------------- */

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
            CAST(
                od.Quantity * od.UnitPrice
                AS DECIMAL(18, 2)
            ),
            CAST(
                od.Quantity
                * od.UnitPrice
                * (1 - od.Discount)
                AS DECIMAL(18, 2)
            ),
            CAST(o.Freight AS DECIMAL(18, 2))
        FROM dbo.Order_Details AS od
        INNER JOIN dbo.Orders AS o
            ON o.OrderID = od.OrderID;


        /* ----------------------------------------------------
           9. Validate expected row counts
           ---------------------------------------------------- */

        IF (SELECT COUNT_BIG(*) FROM analytics.DimCategory) <> 8
        BEGIN
            THROW 51001,
                'DimCategory row-count validation failed.',
                1;
        END;

        IF (SELECT COUNT_BIG(*) FROM analytics.DimCustomer) <> 91
        BEGIN
            THROW 51002,
                'DimCustomer row-count validation failed.',
                1;
        END;

        IF (SELECT COUNT_BIG(*) FROM analytics.DimEmployee) <> 9
        BEGIN
            THROW 51003,
                'DimEmployee row-count validation failed.',
                1;
        END;

        IF (SELECT COUNT_BIG(*) FROM analytics.DimProduct) <> 77
        BEGIN
            THROW 51004,
                'DimProduct row-count validation failed.',
                1;
        END;

        IF (SELECT COUNT_BIG(*) FROM analytics.DimShipper) <> 3
        BEGIN
            THROW 51005,
                'DimShipper row-count validation failed.',
                1;
        END;

        IF (SELECT COUNT_BIG(*) FROM analytics.DimSupplier) <> 29
        BEGIN
            THROW 51006,
                'DimSupplier row-count validation failed.',
                1;
        END;

        IF (SELECT COUNT_BIG(*) FROM analytics.FactSales) <> 2155
        BEGIN
            THROW 51007,
                'FactSales row-count validation failed.',
                1;
        END;


        /* ----------------------------------------------------
           10. Validate dimension business keys
           ---------------------------------------------------- */

        IF EXISTS
        (
            SELECT
                CategoryKey
            FROM analytics.DimCategory
            GROUP BY CategoryKey
            HAVING
                CategoryKey IS NULL
                OR COUNT_BIG(*) > 1
        )
        BEGIN
            THROW 51008,
                'DimCategory key validation failed.',
                1;
        END;

        IF EXISTS
        (
            SELECT
                CustomerKey
            FROM analytics.DimCustomer
            GROUP BY CustomerKey
            HAVING
                CustomerKey IS NULL
                OR COUNT_BIG(*) > 1
        )
        BEGIN
            THROW 51009,
                'DimCustomer key validation failed.',
                1;
        END;

        IF EXISTS
        (
            SELECT
                EmployeeKey
            FROM analytics.DimEmployee
            GROUP BY EmployeeKey
            HAVING
                EmployeeKey IS NULL
                OR COUNT_BIG(*) > 1
        )
        BEGIN
            THROW 51010,
                'DimEmployee key validation failed.',
                1;
        END;

        IF EXISTS
        (
            SELECT
                ProductKey
            FROM analytics.DimProduct
            GROUP BY ProductKey
            HAVING
                ProductKey IS NULL
                OR COUNT_BIG(*) > 1
        )
        BEGIN
            THROW 51011,
                'DimProduct key validation failed.',
                1;
        END;

        IF EXISTS
        (
            SELECT
                ShipperKey
            FROM analytics.DimShipper
            GROUP BY ShipperKey
            HAVING
                ShipperKey IS NULL
                OR COUNT_BIG(*) > 1
        )
        BEGIN
            THROW 51012,
                'DimShipper key validation failed.',
                1;
        END;

        IF EXISTS
        (
            SELECT
                SupplierKey
            FROM analytics.DimSupplier
            GROUP BY SupplierKey
            HAVING
                SupplierKey IS NULL
                OR COUNT_BIG(*) > 1
        )
        BEGIN
            THROW 51013,
                'DimSupplier key validation failed.',
                1;
        END;


        /* ----------------------------------------------------
           11. Validate the fact-table grain
           ---------------------------------------------------- */

        IF EXISTS
        (
            SELECT
                OrderKey,
                ProductKey
            FROM analytics.FactSales
            GROUP BY
                OrderKey,
                ProductKey
            HAVING
                OrderKey IS NULL
                OR ProductKey IS NULL
                OR COUNT_BIG(*) > 1
        )
        BEGIN
            THROW 51014,
                'FactSales grain validation failed.',
                1;
        END;


        /* ----------------------------------------------------
           12. Validate fact-to-dimension relationships
           ---------------------------------------------------- */

        IF EXISTS
        (
            SELECT 1
            FROM analytics.FactSales AS f
            LEFT JOIN analytics.DimCustomer AS c
                ON c.CustomerKey = f.CustomerKey
            WHERE c.CustomerKey IS NULL
        )
        BEGIN
            THROW 51015,
                'FactSales customer relationship validation failed.',
                1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM analytics.FactSales AS f
            LEFT JOIN analytics.DimEmployee AS e
                ON e.EmployeeKey = f.EmployeeKey
            WHERE e.EmployeeKey IS NULL
        )
        BEGIN
            THROW 51016,
                'FactSales employee relationship validation failed.',
                1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM analytics.FactSales AS f
            LEFT JOIN analytics.DimProduct AS p
                ON p.ProductKey = f.ProductKey
            WHERE p.ProductKey IS NULL
        )
        BEGIN
            THROW 51017,
                'FactSales product relationship validation failed.',
                1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM analytics.FactSales AS f
            LEFT JOIN analytics.DimShipper AS s
                ON s.ShipperKey = f.ShipperKey
            WHERE s.ShipperKey IS NULL
        )
        BEGIN
            THROW 51018,
                'FactSales shipper relationship validation failed.',
                1;
        END;


        /* ----------------------------------------------------
           13. Validate fact-table business rules
           ---------------------------------------------------- */

        IF EXISTS
        (
            SELECT 1
            FROM analytics.FactSales
            WHERE
                Quantity IS NULL
                OR Quantity <= 0
                OR UnitPrice IS NULL
                OR UnitPrice < 0
                OR DiscountRate IS NULL
                OR DiscountRate < 0
                OR DiscountRate > 1
                OR OrderFreight IS NULL
                OR OrderFreight < 0
                OR GrossSalesAmount IS NULL
                OR NetSalesAmount IS NULL
                OR ABS(
                    GrossSalesAmount
                    - CAST(
                        Quantity * UnitPrice
                        AS DECIMAL(18, 2)
                    )
                ) > 0.01
                OR ABS(
                    NetSalesAmount
                    - CAST(
                        Quantity
                        * UnitPrice
                        * (1 - DiscountRate)
                        AS DECIMAL(18, 2)
                    )
                ) > 0.01
        )
        BEGIN
            THROW 51019,
                'FactSales business-rule validation failed.',
                1;
        END;


        /* ----------------------------------------------------
           14. Commit only after every validation passes
           ---------------------------------------------------- */

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        THROW;
    END CATCH;
END;

GO