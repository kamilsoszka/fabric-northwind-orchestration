CREATE TABLE [dbo].[PipelineRunLog] (
    [PipelineRunId]   VARCHAR (100)  NOT NULL,
    [PipelineName]    VARCHAR (200)  NOT NULL,
    [RunStartTime]    DATETIME2 (6)  NOT NULL,
    [RunEndTime]      DATETIME2 (6)  NULL,
    [RunStatus]       VARCHAR (30)   NOT NULL,
    [ErrorMessage]    VARCHAR (4000) NULL,
    [LoadedAt]        DATETIME2 (6)  NOT NULL,
    [EnvironmentName] VARCHAR (50)   NULL
);


GO