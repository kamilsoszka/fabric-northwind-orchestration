/* ============================================================
   Fabric Northwind Orchestration
   Extended data-quality validation with date-model checks
   ============================================================ */

CREATE PROCEDURE dbo.usp_validate_northwind_data_quality
    @PipelineRunId VARCHAR(100),
    @EnvironmentName VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM dbo.DataQualityRunLog
    WHERE PipelineRunId = @PipelineRunId;

    INSERT INTO dbo.DataQualityRunLog
    (
        PipelineRunId,
        CheckName,
        ActualValue,
        ExpectedValue,
        CheckStatus,
        CheckedAt,
        EnvironmentName
    )
    SELECT
        @PipelineRunId,
        'DimCategory row count',
        COUNT_BIG(*),
        8,
        CASE WHEN COUNT_BIG(*) = 8 THEN 'Passed' ELSE 'Failed' END,
        SYSUTCDATETIME(),
        @EnvironmentName
    FROM analytics.DimCategory

    UNION ALL

    SELECT
        @PipelineRunId,
        'DimCustomer row count',
        COUNT_BIG(*),
        91,
        CASE WHEN COUNT_BIG(*) = 91 THEN 'Passed' ELSE 'Failed' END,
        SYSUTCDATETIME(),
        @EnvironmentName
    FROM analytics.DimCustomer

    UNION ALL

    SELECT
        @PipelineRunId,
        'DimEmployee row count',
        COUNT_BIG(*),
        9,
        CASE WHEN COUNT_BIG(*) = 9 THEN 'Passed' ELSE 'Failed' END,
        SYSUTCDATETIME(),
        @EnvironmentName
    FROM analytics.DimEmployee

    UNION ALL

    SELECT
        @PipelineRunId,
        'DimProduct row count',
        COUNT_BIG(*),
        77,
        CASE WHEN COUNT_BIG(*) = 77 THEN 'Passed' ELSE 'Failed' END,
        SYSUTCDATETIME(),
        @EnvironmentName
    FROM analytics.DimProduct

    UNION ALL

    SELECT
        @PipelineRunId,
        'DimShipper row count',
        COUNT_BIG(*),
        3,
        CASE WHEN COUNT_BIG(*) = 3 THEN 'Passed' ELSE 'Failed' END,
        SYSUTCDATETIME(),
        @EnvironmentName
    FROM analytics.DimShipper

    UNION ALL

    SELECT
        @PipelineRunId,
        'DimSupplier row count',
        COUNT_BIG(*),
        29,
        CASE WHEN COUNT_BIG(*) = 29 THEN 'Passed' ELSE 'Failed' END,
        SYSUTCDATETIME(),
        @EnvironmentName
    FROM analytics.DimSupplier

    UNION ALL

    SELECT
        @PipelineRunId,
        'DimDate row count',
        COUNT_BIG(*),
        708,
        CASE WHEN COUNT_BIG(*) = 708 THEN 'Passed' ELSE 'Failed' END,
        SYSUTCDATETIME(),
        @EnvironmentName
    FROM analytics.DimDate

    UNION ALL

    SELECT
        @PipelineRunId,
        'FactSales row count',
        COUNT_BIG(*),
        2155,
        CASE WHEN COUNT_BIG(*) = 2155 THEN 'Passed' ELSE 'Failed' END,
        SYSUTCDATETIME(),
        @EnvironmentName
    FROM analytics.FactSales

    UNION ALL

    SELECT
        @PipelineRunId,
        'Missing required fact date keys',
        COUNT_BIG(*),
        0,
        CASE WHEN COUNT_BIG(*) = 0 THEN 'Passed' ELSE 'Failed' END,
        SYSUTCDATETIME(),
        @EnvironmentName
    FROM analytics.FactSales
    WHERE OrderDateKey IS NULL
       OR RequiredDateKey IS NULL

    UNION ALL

    SELECT
        @PipelineRunId,
        'Invalid fact date relationships',
        COUNT_BIG(*),
        0,
        CASE WHEN COUNT_BIG(*) = 0 THEN 'Passed' ELSE 'Failed' END,
        SYSUTCDATETIME(),
        @EnvironmentName
    FROM analytics.FactSales AS f
    LEFT JOIN analytics.DimDate AS od
        ON od.DateKey = f.OrderDateKey
    LEFT JOIN analytics.DimDate AS rd
        ON rd.DateKey = f.RequiredDateKey
    LEFT JOIN analytics.DimDate AS sd
        ON sd.DateKey = f.ShippedDateKey
    WHERE od.DateKey IS NULL
       OR rd.DateKey IS NULL
       OR
       (
           f.ShippedDateKey IS NOT NULL
           AND sd.DateKey IS NULL
       )

    UNION ALL

    SELECT
        @PipelineRunId,
        'Invalid source date chronology',
        COUNT_BIG(*),
        0,
        CASE WHEN COUNT_BIG(*) = 0 THEN 'Passed' ELSE 'Failed' END,
        SYSUTCDATETIME(),
        @EnvironmentName
    FROM dbo.Orders
    WHERE OrderDate IS NULL
       OR RequiredDate IS NULL
       OR RequiredDate < OrderDate
       OR
       (
           ShippedDate IS NOT NULL
           AND ShippedDate < OrderDate
       );

    IF
    (
        SELECT COUNT_BIG(*)
        FROM dbo.DataQualityRunLog
        WHERE PipelineRunId = @PipelineRunId
    ) <> 11
    BEGIN
        THROW 51201,
            'The expected number of data-quality checks was not recorded.',
            1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.DataQualityRunLog
        WHERE PipelineRunId = @PipelineRunId
          AND CheckStatus = 'Failed'
    )
    BEGIN
        THROW 51202,
            'Northwind data-quality validation failed.',
            1;
    END;
END;

GO