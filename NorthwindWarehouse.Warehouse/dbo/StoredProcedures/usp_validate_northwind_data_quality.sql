-- Run measurable data quality checks and stop the pipeline when a check fails
CREATE   PROCEDURE dbo.usp_validate_northwind_data_quality
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
        'FactSales row count',
        COUNT_BIG(*),
        2155,
        CASE WHEN COUNT_BIG(*) = 2155 THEN 'Passed' ELSE 'Failed' END,
        SYSUTCDATETIME(),
        @EnvironmentName
    FROM analytics.FactSales;

    -- Stop the pipeline when any data quality check fails
    IF EXISTS
    (
        SELECT 1
        FROM dbo.DataQualityRunLog
        WHERE PipelineRunId = @PipelineRunId
          AND CheckStatus = 'Failed'
    )
    BEGIN
        THROW 50001, 'Northwind data quality validation failed.', 1;
    END;
END;

GO