CREATE TABLE [analytics].[DimEmployee] (
    [EmployeeKey]  INT           NULL,
    [FirstName]    VARCHAR (50)  NULL,
    [LastName]     VARCHAR (50)  NULL,
    [EmployeeName] VARCHAR (101) NULL,
    [JobTitle]     VARCHAR (100) NULL,
    [City]         VARCHAR (100) NULL,
    [Region]       VARCHAR (100) NULL,
    [Country]      VARCHAR (100) NULL,
    [ManagerKey]   INT           NULL
);


GO