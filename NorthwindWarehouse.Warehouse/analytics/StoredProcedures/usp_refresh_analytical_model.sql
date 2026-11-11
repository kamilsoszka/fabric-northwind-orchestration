/* Fabric Northwind Orchestration
   Transactional analytical-model refresh with continuous date dimension,
   deterministic order-freight allocation, and regression controls. */

CREATE PROCEDURE analytics.usp_refresh_analytical_model
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MinimumDate DATE;
    DECLARE @MaximumDate DATE;
    DECLARE @ExpectedDateRows INT;
    DECLARE @ExpectedFactRows BIGINT;
    DECLARE @SourceFreight DECIMAL(38, 2);
    DECLARE @FactFreight DECIMAL(38, 2);

    SELECT
        @MinimumDate = MIN(DateValue),
        @MaximumDate = MAX(DateValue)
    FROM
    (
        SELECT
            CAST(OrderDate AS DATE) AS DateValue
        FROM dbo.Orders
        WHERE OrderDate IS NOT NULL

        UNION ALL

        SELECT
            CAST(RequiredDate AS DATE)
        FROM dbo.Orders
        WHERE RequiredDate IS NOT NULL

        UNION ALL

        SELECT
            CAST(ShippedDate AS DATE)
        FROM dbo.Orders
        WHERE ShippedDate IS NOT NULL
    ) AS SourceDates;

    IF @MinimumDate IS NULL OR @MaximumDate IS NULL
    BEGIN
        THROW 51001, 'The source date range is empty.', 1;
    END;

    SET @ExpectedDateRows =
        DATEDIFF(DAY, @MinimumDate, @MaximumDate) + 1;

    SELECT
        @ExpectedFactRows = COUNT_BIG(*)
    FROM dbo.Order_Details AS od
    INNER JOIN dbo.Orders AS o
        ON o.OrderID = od.OrderID;

    SELECT
        @SourceFreight =
            CAST(SUM(CAST(Freight AS DECIMAL(38, 2))) AS DECIMAL(38, 2))
    FROM dbo.Orders;

    IF @ExpectedFactRows = 0
    BEGIN
        THROW 51002, 'The source fact dataset is empty.', 1;
    END;

    IF @SourceFreight IS NULL
    BEGIN
        THROW 51003, 'The source freight total could not be calculated.', 1;
    END;

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

        -- Generate a continuous date dimension.
        WITH DateValues AS
        (
            SELECT
                CAST(
                    DATEADD(DAY, value, @MinimumDate)
                    AS DATE
                ) AS FullDate
            FROM GENERATE_SERIES(
                CAST(0 AS INT),
                CAST(@ExpectedDateRows - 1 AS INT)
            )
        )
        INSERT INTO analytics.DimDate
        (
            DateKey,
            FullDate,
            CalendarYear,
            CalendarQuarter,
            QuarterName,
            MonthNumber,
            MonthName,
            YearMonth,
            DayOfMonth,
            DayOfWeekNumber,
            DayOfWeekName,
            IsWeekend
        )
        SELECT
            CAST(CONVERT(CHAR(8), FullDate, 112) AS INT),
            FullDate,
            DATEPART(YEAR, FullDate),
            DATEPART(QUARTER, FullDate),
            CAST(
                CONCAT(
                    'Q',
                    DATEPART(QUARTER, FullDate)
                )
                AS VARCHAR(2)
            ),
            DATEPART(MONTH, FullDate),
            CAST(DATENAME(MONTH, FullDate) AS VARCHAR(20)),
            CAST(
                CONCAT(
                    DATEPART(YEAR, FullDate),
                    '-',
                    RIGHT(
                        CONCAT(
                            '0',
                            DATEPART(MONTH, FullDate)
                        ),
                        2
                    )
                )
                AS VARCHAR(7)
            ),
            DATEPART(DAY, FullDate),
            (
                DATEDIFF(
                    DAY,
                    CAST('19000101' AS DATE),
                    FullDate
                ) % 7
            ) + 1,
            CAST(DATENAME(WEEKDAY, FullDate) AS VARCHAR(20)),
            CAST(
                CASE
                    WHEN
                        (
                            DATEDIFF(
                                DAY,
                                CAST('19000101' AS DATE),
                                FullDate
                            ) % 7
                        ) + 1 IN (6, 7)
                    THEN 1
                    ELSE 0
                END
                AS BIT
            )
        FROM DateValues;

        -- Rebuild analytical dimensions.
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

        -- Rebuild the sales fact table at one order-product line grain.
        -- Store freight once per order on the line with the lowest ProductID.
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
            OrderFreight,
            OrderDateKey,
            RequiredDateKey,
            ShippedDateKey
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
            CAST(
                CASE
                    WHEN ROW_NUMBER() OVER
                    (
                        PARTITION BY od.OrderID
                        ORDER BY od.ProductID
                    ) = 1
                    THEN o.Freight
                    ELSE 0
                END
                AS DECIMAL(18, 2)
            ),
            CAST(
                CONVERT(
                    CHAR(8),
                    CAST(o.OrderDate AS DATE),
                    112
                )
                AS INT
            ),
            CAST(
                CONVERT(
                    CHAR(8),
                    CAST(o.RequiredDate AS DATE),
                    112
                )
                AS INT
            ),
            CASE
                WHEN o.ShippedDate IS NULL
                THEN NULL
                ELSE
                    CAST(
                        CONVERT(
                            CHAR(8),
                            CAST(o.ShippedDate AS DATE),
                            112
                        )
                        AS INT
                    )
            END
        FROM dbo.Order_Details AS od
        INNER JOIN dbo.Orders AS o
            ON o.OrderID = od.OrderID;

        -- Validate row counts.
        IF
        (
            SELECT COUNT_BIG(*)
            FROM analytics.DimDate
        ) <> @ExpectedDateRows
        BEGIN
            THROW 51101, 'DimDate row-count validation failed.', 1;
        END;

        IF
        (
            SELECT COUNT_BIG(*)
            FROM analytics.DimCategory
        ) <> 8
        BEGIN
            THROW 51102, 'DimCategory row-count validation failed.', 1;
        END;

        IF
        (
            SELECT COUNT_BIG(*)
            FROM analytics.DimCustomer
        ) <> 91
        BEGIN
            THROW 51103, 'DimCustomer row-count validation failed.', 1;
        END;

        IF
        (
            SELECT COUNT_BIG(*)
            FROM analytics.DimEmployee
        ) <> 9
        BEGIN
            THROW 51104, 'DimEmployee row-count validation failed.', 1;
        END;

        IF
        (
            SELECT COUNT_BIG(*)
            FROM analytics.DimProduct
        ) <> 77
        BEGIN
            THROW 51105, 'DimProduct row-count validation failed.', 1;
        END;

        IF
        (
            SELECT COUNT_BIG(*)
            FROM analytics.DimShipper
        ) <> 3
        BEGIN
            THROW 51106, 'DimShipper row-count validation failed.', 1;
        END;

        IF
        (
            SELECT COUNT_BIG(*)
            FROM analytics.DimSupplier
        ) <> 29
        BEGIN
            THROW 51107, 'DimSupplier row-count validation failed.', 1;
        END;

        IF
        (
            SELECT COUNT_BIG(*)
            FROM analytics.FactSales
        ) <> @ExpectedFactRows
        BEGIN
            THROW 51108, 'FactSales source reconciliation failed.', 1;
        END;

        -- Validate date-dimension completeness and uniqueness.
        IF EXISTS
        (
            SELECT DateKey
            FROM analytics.DimDate
            GROUP BY DateKey
            HAVING COUNT_BIG(*) > 1
        )
        BEGIN
            THROW 51109, 'DimDate DateKey uniqueness validation failed.', 1;
        END;

        IF EXISTS
        (
            SELECT FullDate
            FROM analytics.DimDate
            GROUP BY FullDate
            HAVING COUNT_BIG(*) > 1
        )
        BEGIN
            THROW 51110, 'DimDate FullDate uniqueness validation failed.', 1;
        END;

        IF
        (
            SELECT MIN(FullDate)
            FROM analytics.DimDate
        ) <> @MinimumDate
        BEGIN
            THROW 51111, 'DimDate minimum-date validation failed.', 1;
        END;

        IF
        (
            SELECT MAX(FullDate)
            FROM analytics.DimDate
        ) <> @MaximumDate
        BEGIN
            THROW 51112, 'DimDate maximum-date validation failed.', 1;
        END;

        -- Validate dimension and fact keys.
        IF EXISTS
        (
            SELECT CategoryKey
            FROM analytics.DimCategory
            GROUP BY CategoryKey
            HAVING
                CategoryKey IS NULL
                OR COUNT_BIG(*) > 1
        )
        BEGIN
            THROW 51113, 'DimCategory key validation failed.', 1;
        END;

        IF EXISTS
        (
            SELECT CustomerKey
            FROM analytics.DimCustomer
            GROUP BY CustomerKey
            HAVING
                CustomerKey IS NULL
                OR COUNT_BIG(*) > 1
        )
        BEGIN
            THROW 51114, 'DimCustomer key validation failed.', 1;
        END;

        IF EXISTS
        (
            SELECT EmployeeKey
            FROM analytics.DimEmployee
            GROUP BY EmployeeKey
            HAVING
                EmployeeKey IS NULL
                OR COUNT_BIG(*) > 1
        )
        BEGIN
            THROW 51115, 'DimEmployee key validation failed.', 1;
        END;

        IF EXISTS
        (
            SELECT ProductKey
            FROM analytics.DimProduct
            GROUP BY ProductKey
            HAVING
                ProductKey IS NULL
                OR COUNT_BIG(*) > 1
        )
        BEGIN
            THROW 51116, 'DimProduct key validation failed.', 1;
        END;

        IF EXISTS
        (
            SELECT ShipperKey
            FROM analytics.DimShipper
            GROUP BY ShipperKey
            HAVING
                ShipperKey IS NULL
                OR COUNT_BIG(*) > 1
        )
        BEGIN
            THROW 51117, 'DimShipper key validation failed.', 1;
        END;

        IF EXISTS
        (
            SELECT SupplierKey
            FROM analytics.DimSupplier
            GROUP BY SupplierKey
            HAVING
                SupplierKey IS NULL
                OR COUNT_BIG(*) > 1
        )
        BEGIN
            THROW 51118, 'DimSupplier key validation failed.', 1;
        END;

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
            THROW 51119, 'FactSales grain validation failed.', 1;
        END;

        -- Validate dimensional relationships.
        IF EXISTS
        (
            SELECT 1
            FROM analytics.FactSales AS f
            LEFT JOIN analytics.DimCustomer AS d
                ON d.CustomerKey = f.CustomerKey
            WHERE d.CustomerKey IS NULL
        )
        BEGIN
            THROW 51120, 'FactSales customer relationship validation failed.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM analytics.FactSales AS f
            LEFT JOIN analytics.DimEmployee AS d
                ON d.EmployeeKey = f.EmployeeKey
            WHERE d.EmployeeKey IS NULL
        )
        BEGIN
            THROW 51121, 'FactSales employee relationship validation failed.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM analytics.FactSales AS f
            LEFT JOIN analytics.DimProduct AS d
                ON d.ProductKey = f.ProductKey
            WHERE d.ProductKey IS NULL
        )
        BEGIN
            THROW 51122, 'FactSales product relationship validation failed.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM analytics.FactSales AS f
            LEFT JOIN analytics.DimShipper AS d
                ON d.ShipperKey = f.ShipperKey
            WHERE d.ShipperKey IS NULL
        )
        BEGIN
            THROW 51123, 'FactSales shipper relationship validation failed.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM analytics.FactSales AS f
            LEFT JOIN analytics.DimDate AS d
                ON d.DateKey = f.OrderDateKey
            WHERE
                f.OrderDateKey IS NULL
                OR d.DateKey IS NULL
        )
        BEGIN
            THROW 51124, 'FactSales order-date relationship validation failed.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM analytics.FactSales AS f
            LEFT JOIN analytics.DimDate AS d
                ON d.DateKey = f.RequiredDateKey
            WHERE
                f.RequiredDateKey IS NULL
                OR d.DateKey IS NULL
        )
        BEGIN
            THROW 51125, 'FactSales required-date relationship validation failed.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM analytics.FactSales AS f
            LEFT JOIN analytics.DimDate AS d
                ON d.DateKey = f.ShippedDateKey
            WHERE
                f.ShippedDateKey IS NOT NULL
                AND d.DateKey IS NULL
        )
        BEGIN
            THROW 51126, 'FactSales shipped-date relationship validation failed.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM analytics.DimProduct AS p
            LEFT JOIN analytics.DimCategory AS c
                ON c.CategoryKey = p.CategoryKey
            WHERE c.CategoryKey IS NULL
        )
        BEGIN
            THROW 51127, 'DimProduct category relationship validation failed.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM analytics.DimProduct AS p
            LEFT JOIN analytics.DimSupplier AS s
                ON s.SupplierKey = p.SupplierKey
            WHERE s.SupplierKey IS NULL
        )
        BEGIN
            THROW 51128, 'DimProduct supplier relationship validation failed.', 1;
        END;

        -- Validate source date chronology.
        IF EXISTS
        (
            SELECT 1
            FROM dbo.Orders
            WHERE
                OrderDate IS NULL
                OR RequiredDate IS NULL
                OR RequiredDate < OrderDate
                OR
                (
                    ShippedDate IS NOT NULL
                    AND ShippedDate < OrderDate
                )
        )
        BEGIN
            THROW 51129, 'Source order-date chronology validation failed.', 1;
        END;

        -- Validate sales measures and business rules.
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
            THROW 51130, 'FactSales business-rule validation failed.', 1;
        END;

        -- Validate freight reconciliation and per-order allocation.
        SELECT
            @FactFreight =
                CAST(
                    SUM(
                        CAST(
                            OrderFreight
                            AS DECIMAL(38, 2)
                        )
                    )
                    AS DECIMAL(38, 2)
                )
        FROM analytics.FactSales;

        IF
            @FactFreight IS NULL
            OR ABS(@FactFreight - @SourceFreight) > 0.01
        BEGIN
            THROW 51131, 'FactSales freight-total reconciliation failed.', 1;
        END;

        IF EXISTS
        (
            SELECT
                f.OrderKey
            FROM analytics.FactSales AS f
            INNER JOIN dbo.Orders AS o
                ON o.OrderID = f.OrderKey
            GROUP BY
                f.OrderKey,
                o.Freight
            HAVING
                ABS(
                    SUM(f.OrderFreight)
                    - CAST(o.Freight AS DECIMAL(18, 2))
                ) > 0.01
                OR
                SUM(
                    CASE
                        WHEN f.OrderFreight <> 0 THEN 1
                        ELSE 0
                    END
                ) <>
                CASE
                    WHEN CAST(o.Freight AS DECIMAL(18, 2)) = 0
                    THEN 0
                    ELSE 1
                END
        )
        BEGIN
            THROW 51132, 'FactSales order-level freight allocation failed.', 1;
        END;

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
