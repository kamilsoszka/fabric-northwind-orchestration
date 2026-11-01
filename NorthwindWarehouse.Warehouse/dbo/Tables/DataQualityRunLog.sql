CREATE TABLE [dbo].[DataQualityRunLog] (
    [PipelineRunId]   VARCHAR (100) NOT NULL,
    [CheckName]       VARCHAR (200) NOT NULL,
    [ActualValue]     BIGINT        NOT NULL,
    [ExpectedValue]   BIGINT        NOT NULL,
    [CheckStatus]     VARCHAR (20)  NOT NULL,
    [CheckedAt]       DATETIME2 (6) NOT NULL,
    [EnvironmentName] VARCHAR (50)  NOT NULL
);


GO