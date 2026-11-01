CREATE TABLE [analytics].[FactSales] (
    [OrderKey]         INT             NULL,
    [ProductKey]       INT             NULL,
    [CustomerKey]      VARCHAR (10)    NULL,
    [EmployeeKey]      INT             NULL,
    [ShipperKey]       INT             NULL,
    [Quantity]         INT             NULL,
    [UnitPrice]        DECIMAL (18, 2) NULL,
    [DiscountRate]     DECIMAL (9, 6)  NULL,
    [GrossSalesAmount] DECIMAL (18, 2) NULL,
    [NetSalesAmount]   DECIMAL (18, 2) NULL,
    [OrderFreight]     DECIMAL (18, 2) NULL
);


GO