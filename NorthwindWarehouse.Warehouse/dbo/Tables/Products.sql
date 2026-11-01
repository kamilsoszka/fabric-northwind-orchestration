CREATE TABLE [dbo].[Products] (
    [ProductID]       BIGINT          NULL,
    [ProductName]     VARCHAR (8000)  NULL,
    [SupplierID]      BIGINT          NULL,
    [CategoryID]      BIGINT          NULL,
    [QuantityPerUnit] VARCHAR (8000)  NULL,
    [UnitPrice]       DECIMAL (34, 6) NULL,
    [UnitsInStock]    BIGINT          NULL,
    [UnitsOnOrder]    BIGINT          NULL,
    [ReorderLevel]    BIGINT          NULL,
    [Discontinued]    BIT             NULL
);


GO