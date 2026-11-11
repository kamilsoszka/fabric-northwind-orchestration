CREATE TABLE [analytics].[DimDate] (
    [DateKey]         INT          NOT NULL,
    [FullDate]        DATE         NOT NULL,
    [CalendarYear]    INT          NOT NULL,
    [CalendarQuarter] INT          NOT NULL,
    [QuarterName]     VARCHAR (2)  NOT NULL,
    [MonthNumber]     INT          NOT NULL,
    [MonthName]       VARCHAR (20) NOT NULL,
    [YearMonth]       VARCHAR (7)  NOT NULL,
    [DayOfMonth]      INT          NOT NULL,
    [DayOfWeekNumber] INT          NOT NULL,
    [DayOfWeekName]   VARCHAR (20) NOT NULL,
    [IsWeekend]       BIT          NOT NULL
);


GO