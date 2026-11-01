CREATE TABLE [analytics].[DimProduct] (
    [ProductKey]      INT             NULL,
    [ProductName]     VARCHAR (100)   NULL,
    [SupplierKey]     INT             NULL,
    [CategoryKey]     INT             NULL,
    [QuantityPerUnit] VARCHAR (100)   NULL,
    [UnitPrice]       DECIMAL (18, 2) NULL,
    [UnitsInStock]    INT             NULL,
    [UnitsOnOrder]    INT             NULL,
    [ReorderLevel]    INT             NULL,
    [IsDiscontinued]  BIT             NULL
);


GO