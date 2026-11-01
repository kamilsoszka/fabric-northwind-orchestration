-- Log a failed pipeline execution with deployment environment details
CREATE   PROCEDURE dbo.usp_log_northwind_pipeline_failure
    @PipelineRunId VARCHAR(100),
    @PipelineName VARCHAR(200),
    @RunStartTime DATETIME2(6),
    @ErrorMessage VARCHAR(4000),
    @EnvironmentName VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.PipelineRunLog
    (
        PipelineRunId,
        PipelineName,
        RunStartTime,
        RunEndTime,
        RunStatus,
        ErrorMessage,
        LoadedAt,
        EnvironmentName
    )
    VALUES
    (
        @PipelineRunId,
        @PipelineName,
        @RunStartTime,
        SYSUTCDATETIME(),
        'Failed',
        @ErrorMessage,
        SYSUTCDATETIME(),
        @EnvironmentName
    );
END;

GO