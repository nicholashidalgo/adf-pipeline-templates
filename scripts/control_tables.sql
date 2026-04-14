CREATE SCHEMA control;
GO

CREATE TABLE control.watermark_table (
    table_name          VARCHAR(256) NOT NULL PRIMARY KEY,
    watermark_value     DATETIME2    NOT NULL,
    updated_at          DATETIME2    NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE control.pipeline_config (
    pipeline_name       VARCHAR(256) NOT NULL,
    source_table        VARCHAR(256) NOT NULL,
    watermark_column    VARCHAR(128) NOT NULL DEFAULT 'modified_date',
    priority            INT          NOT NULL DEFAULT 100,
    is_enabled          BIT          NOT NULL DEFAULT 1,
    created_at          DATETIME2    NOT NULL DEFAULT GETUTCDATE(),
    PRIMARY KEY (pipeline_name, source_table)
);

CREATE TABLE control.pipeline_run_log (
    log_id              INT IDENTITY(1,1) PRIMARY KEY,
    pipeline_name       VARCHAR(256) NOT NULL,
    run_id              VARCHAR(128) NOT NULL,
    status              VARCHAR(50)  NOT NULL,
    rows_copied         INT          NULL,
    duration_seconds    INT          NULL,
    logged_at           DATETIME2    NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE control.dq_rules (
    rule_id             INT IDENTITY(1,1) PRIMARY KEY,
    table_name          VARCHAR(256) NOT NULL,
    check_type          VARCHAR(50)  NOT NULL,
    threshold           VARCHAR(50)  NOT NULL,
    query               NVARCHAR(MAX) NOT NULL,
    is_active           BIT          NOT NULL DEFAULT 1
);

CREATE TABLE control.dq_results (
    result_id           INT IDENTITY(1,1) PRIMARY KEY,
    rule_id             INT          NOT NULL,
    table_name          VARCHAR(256) NOT NULL,
    check_type          VARCHAR(50)  NOT NULL,
    result_value        VARCHAR(50)  NOT NULL,
    threshold           VARCHAR(50)  NOT NULL,
    passed              BIT          NOT NULL,
    run_timestamp       DATETIME2    NOT NULL DEFAULT GETUTCDATE()
);
GO

CREATE PROCEDURE control.usp_update_watermark
    @table_name VARCHAR(256),
    @watermark_value VARCHAR(50)
AS
BEGIN
    UPDATE control.watermark_table
    SET watermark_value = @watermark_value,
        updated_at = GETUTCDATE()
    WHERE table_name = @table_name;

    IF @@ROWCOUNT = 0
        INSERT INTO control.watermark_table (table_name, watermark_value)
        VALUES (@table_name, @watermark_value);
END;
GO

CREATE PROCEDURE control.usp_log_pipeline_run
    @pipeline_name VARCHAR(256),
    @run_id VARCHAR(128),
    @status VARCHAR(50),
    @rows_copied INT = NULL,
    @duration_seconds INT = NULL
AS
BEGIN
    INSERT INTO control.pipeline_run_log (pipeline_name, run_id, status, rows_copied, duration_seconds)
    VALUES (@pipeline_name, @run_id, @status, @rows_copied, @duration_seconds);
END;
GO

CREATE PROCEDURE control.usp_log_dq_result
    @rule_id INT,
    @table_name VARCHAR(256),
    @check_type VARCHAR(50),
    @result_value VARCHAR(50),
    @threshold VARCHAR(50),
    @passed VARCHAR(5),
    @run_timestamp VARCHAR(50)
AS
BEGIN
    INSERT INTO control.dq_results (rule_id, table_name, check_type, result_value, threshold, passed, run_timestamp)
    VALUES (@rule_id, @table_name, @check_type, @result_value, @threshold, CASE @passed WHEN 'true' THEN 1 ELSE 0 END, @run_timestamp);
END;
GO
