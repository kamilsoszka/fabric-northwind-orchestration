CREATE TABLE [dbo].[Order_Details] (
    [OrderID]   BIGINT          NULL,
    [ProductID] BIGINT          NULL,
    [UnitPrice] DECIMAL (34, 6) NULL,
    [Quantity]  BIGINT          NULL,
    [Discount]  FLOAT (53)      NULL
);


GO