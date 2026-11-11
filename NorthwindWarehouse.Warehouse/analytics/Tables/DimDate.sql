CREATE TABLE [analytics].[DimDate] (
    [DateKey]         INT          NULL,
    [FullDate]        DATE         NULL,
    [CalendarYear]    INT          NULL,
    [CalendarQuarter] INT          NULL,
    [QuarterName]     VARCHAR (2)  NULL,
    [MonthNumber]     INT          NULL,
    [MonthName]       VARCHAR (30) NULL,
    [YearMonth]       VARCHAR (7)  NULL,
    [DayOfMonth]      INT          NULL,
    [DayOfWeekNumber] INT          NULL,
    [DayOfWeekName]   VARCHAR (30) NULL,
    [IsWeekend]       INT          NOT NULL
);


GO