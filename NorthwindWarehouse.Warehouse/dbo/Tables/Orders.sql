CREATE TABLE [dbo].[Orders] (
    [OrderID]        BIGINT          NULL,
    [CustomerID]     VARCHAR (8000)  NULL,
    [EmployeeID]     BIGINT          NULL,
    [ShipVia]        BIGINT          NULL,
    [Freight]        DECIMAL (38, 6) NULL,
    [ShipName]       VARCHAR (8000)  NULL,
    [ShipAddress]    VARCHAR (8000)  NULL,
    [ShipCity]       VARCHAR (8000)  NULL,
    [ShipRegion]     VARCHAR (8000)  NULL,
    [ShipPostalCode] VARCHAR (8000)  NULL,
    [ShipCountry]    VARCHAR (8000)  NULL
);


GO