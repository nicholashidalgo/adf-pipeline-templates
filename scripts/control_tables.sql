IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'control')
BEGIN
    EXEC('CREATE SCHEMA control');
END;
GO

CREATE TABLE control.watermark_table (
    table_name          VARCHAR(256)  NOT NULL PRIMARY KEY,
    watermark_column    VARCHAR(128)  NOT NULL DEFAULT 'modified_date',
    watermark_value     NVARCHAR(128) NOT NULL,
    updated_at          DATETIME2     NOT NULL DEFAULT GETUTCDATE()
);
GO

CREATE TABLE control.pipeline_config (
    pipeline_name       VARCHAR(256) NOT NULL,
    source_table        VARCHAR(256) NOT NULL,
    target_table        VARCHAR(256) NULL,
    watermark_column    VARCHAR(128) NOT NULL DEFAULT 'modified_date',
    load_strategy       VARCHAR(50)  NOT NULL DEFAULT 'incremental',
    priority            INT          NOT NULL DEFAULT 100,
    is_enabled          BIT          NOT NULL DEFAULT 1,
    created_at          DATETIME2    NOT NULL DEFAULT GETUTCDATE(),
    updated_at          DATETIME2    NULL,
    PRIMARY KEY (pipeline_name, source_table)
);
GO

CREATE TABLE control.pipeline_run_log (
    log_id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    pipeline_name       VARCHAR(256) NOT NULL,
    run_id              VARCHAR(128) NOT NULL,
    status              VARCHAR(50)  NOT NULL,
    source_table        VARCHAR(256) NULL,
    rows_copied         INT          NULL,
    duration_seconds    INT          NULL,
    error_message       NVARCHAR(2000) NULL,
    logged_at           DATETIME2    NOT NULL DEFAULT GETUTCDATE()
);
GO

CREATE TABLE control.dq_rules (
    rule_id             INT IDENTITY(1,1) PRIMARY KEY,
    table_name          VARCHAR(256)  NOT NULL,
    check_type          VARCHAR(50)   NOT NULL,
    comparison_operator VARCHAR(10)   NOT NULL,
    threshold           NVARCHAR(50)  NOT NULL,
    query               NVARCHAR(MAX) NOT NULL,
    severity            VARCHAR(20)   NOT NULL DEFAULT 'error',
    is_active           BIT           NOT NULL DEFAULT 1,
    created_at          DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT ck_dq_rules_operator
        CHECK (comparison_operator IN ('>', '>=', '<', '<=', '=', '<>', '!='))
);
GO

CREATE TABLE control.dq_results (
    result_id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    rule_id             INT           NOT NULL,
    table_name          VARCHAR(256)  NOT NULL,
    check_type          VARCHAR(50)   NOT NULL,
    comparison_operator VARCHAR(10)   NOT NULL,
    result_value        NVARCHAR(50)  NULL,
    threshold           NVARCHAR(50)  NOT NULL,
    passed              BIT           NOT NULL,
    severity            VARCHAR(20)   NOT NULL,
    result_status       VARCHAR(30)   NOT NULL,
    error_message       NVARCHAR(2000) NULL,
    run_timestamp       DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    logged_at           DATETIME2     NOT NULL DEFAULT GETUTCDATE()
);
GO

CREATE OR ALTER PROCEDURE control.usp_update_watermark
    @table_name VARCHAR(256),
    @watermark_column VARCHAR(128),
    @watermark_value NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE control.watermark_table
    SET watermark_column = @watermark_column,
        watermark_value = @watermark_value,
        updated_at = GETUTCDATE()
    WHERE table_name = @table_name;

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO control.watermark_table (
            table_name,
            watermark_column,
            watermark_value
        )
        VALUES (
            @table_name,
            @watermark_column,
            @watermark_value
        );
    END;
END;
GO

CREATE OR ALTER PROCEDURE control.usp_log_pipeline_run
    @pipeline_name VARCHAR(256),
    @run_id VARCHAR(128),
    @status VARCHAR(50),
    @source_table VARCHAR(256) = NULL,
    @rows_copied INT = NULL,
    @duration_seconds INT = NULL,
    @error_message NVARCHAR(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO control.pipeline_run_log (
        pipeline_name,
        run_id,
        status,
        source_table,
        rows_copied,
        duration_seconds,
        error_message
    )
    VALUES (
        @pipeline_name,
        @run_id,
        @status,
        @source_table,
        @rows_copied,
        @duration_seconds,
        @error_message
    );
END;
GO

CREATE OR ALTER PROCEDURE control.usp_evaluate_dq_result
    @rule_id INT,
    @table_name VARCHAR(256),
    @check_type VARCHAR(50),
    @comparison_operator VARCHAR(10),
    @result_value NVARCHAR(50),
    @threshold NVARCHAR(50),
    @severity VARCHAR(20),
    @run_timestamp NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @result_number DECIMAL(38, 10) = TRY_CONVERT(DECIMAL(38, 10), @result_value);
    DECLARE @threshold_number DECIMAL(38, 10) = TRY_CONVERT(DECIMAL(38, 10), @threshold);
    DECLARE @passed BIT = 0;
    DECLARE @status VARCHAR(30) = 'Evaluated';
    DECLARE @error_message NVARCHAR(2000) = NULL;
    DECLARE @evaluated_at DATETIME2 = COALESCE(TRY_CONVERT(DATETIME2, @run_timestamp), GETUTCDATE());

    IF @result_number IS NULL OR @threshold_number IS NULL
    BEGIN
        SET @status = 'InvalidResult';
        SET @error_message = 'DQ result or threshold could not be converted to a numeric value.';
    END
    ELSE
    BEGIN
        SET @passed =
            CASE
                WHEN @comparison_operator = '>'  AND @result_number >  @threshold_number THEN 1
                WHEN @comparison_operator = '>=' AND @result_number >= @threshold_number THEN 1
                WHEN @comparison_operator = '<'  AND @result_number <  @threshold_number THEN 1
                WHEN @comparison_operator = '<=' AND @result_number <= @threshold_number THEN 1
                WHEN @comparison_operator = '='  AND @result_number =  @threshold_number THEN 1
                WHEN @comparison_operator IN ('<>', '!=') AND @result_number <> @threshold_number THEN 1
                ELSE 0
            END;
    END;

    INSERT INTO control.dq_results (
        rule_id,
        table_name,
        check_type,
        comparison_operator,
        result_value,
        threshold,
        passed,
        severity,
        result_status,
        error_message,
        run_timestamp
    )
    VALUES (
        @rule_id,
        @table_name,
        @check_type,
        @comparison_operator,
        @result_value,
        @threshold,
        @passed,
        @severity,
        @status,
        @error_message,
        @evaluated_at
    );
END;
GO

CREATE OR ALTER PROCEDURE control.usp_log_dq_failure
    @rule_id INT,
    @table_name VARCHAR(256),
    @check_type VARCHAR(50),
    @comparison_operator VARCHAR(10),
    @threshold NVARCHAR(50),
    @severity VARCHAR(20),
    @error_message NVARCHAR(2000),
    @run_timestamp NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO control.dq_results (
        rule_id,
        table_name,
        check_type,
        comparison_operator,
        result_value,
        threshold,
        passed,
        severity,
        result_status,
        error_message,
        run_timestamp
    )
    VALUES (
        @rule_id,
        @table_name,
        @check_type,
        @comparison_operator,
        NULL,
        @threshold,
        0,
        @severity,
        'ExecutionFailed',
        @error_message,
        COALESCE(TRY_CONVERT(DATETIME2, @run_timestamp), GETUTCDATE())
    );
END;
GO