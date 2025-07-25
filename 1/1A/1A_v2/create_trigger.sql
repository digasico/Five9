USE test1;
-- Drop the trigger if it exists
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'tr_agent_event_interval_rollup')
    DROP TRIGGER tr_agent_event_interval_rollup;
GO

-- Create the optimized set-based trigger
CREATE TRIGGER tr_agent_event_interval_rollup
ON agent_event
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Declare variables for error handling
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;

    BEGIN TRY
        -- Generate 15-minute intervals for all inserted/updated events
        WITH EventIntervals AS (
            -- Get start and end times, defaulting end to current UTC time if NULL
            SELECT 
                i.agent_id,
                i.domain_id,
                i.event_id,
                i.state,
                i.state_start_datetime,
                ISNULL(i.state_end_datetime, GETUTCDATE()) AS state_end_datetime,
                -- Generate 15-minute intervals using a numbers table or recursive CTE
                DATEADD(MINUTE, 
                    (DATEDIFF(MINUTE, '2000-01-01', i.state_start_datetime) / 15) * 15 + n.number * 15, 
                    '2000-01-01') AS interval_start
            FROM inserted i
            CROSS APPLY (
                -- Generate numbers for intervals
                SELECT number
                FROM (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS number 
                      FROM sys.all_objects WHERE object_id > 0) AS numbers
                WHERE number <= DATEDIFF(MINUTE, i.state_start_datetime, 
                                        ISNULL(i.state_end_datetime, GETUTCDATE())) / 15
            ) n
        ),
        IntervalDurations AS (
            -- Calculate duration for each interval
            SELECT 
                agent_id,
                domain_id,
                interval_start,
                state,
                -- Duration in seconds: min(end_time, interval_end) - max(start_time, interval_start)
                DATEDIFF(SECOND, 
                    CASE WHEN state_start_datetime > interval_start 
                         THEN state_start_datetime 
                         ELSE interval_start 
                    END,
                    CASE WHEN DATEADD(MINUTE, 15, interval_start) < state_end_datetime 
                         THEN DATEADD(MINUTE, 15, interval_start) 
                         ELSE state_end_datetime 
                    END) AS interval_duration
            FROM EventIntervals
            WHERE interval_start < state_end_datetime -- Exclude intervals beyond end time
        )
        -- Merge into agent_state_interval
        MERGE INTO agent_state_interval AS target
        USING (
            SELECT 
                agent_id,
                domain_id,
                interval_start AS [interval],
                state,
                SUM(interval_duration) AS agent_state_time
            FROM IntervalDurations
            GROUP BY agent_id, domain_id, state, interval_start
        ) AS source
        ON target.agent_id = source.agent_id
        AND target.domain_id = source.domain_id
        AND target.[interval] = source.[interval]
        AND target.state = source.state
        WHEN MATCHED THEN
            UPDATE SET 
                agent_state_time = target.agent_state_time + source.agent_state_time,
                db_updated_datetime = GETUTCDATE()
        WHEN NOT MATCHED THEN
            INSERT (
                agent_id, 
                domain_id, 
                [interval], 
                state, 
                agent_state_time, 
                db_updated_datetime, 
                db_created_datetime
            )
            VALUES (
                source.agent_id, 
                source.domain_id, 
                source.[interval], 
                source.state, 
                source.agent_state_time, 
                GETUTCDATE(), 
                GETUTCDATE()
            );
    END TRY
    BEGIN CATCH
        -- Capture error details
        SET @ErrorMessage = ERROR_MESSAGE();
        SET @ErrorSeverity = ERROR_SEVERITY();
        SET @ErrorState = ERROR_STATE();

        -- Log error (uncomment and adjust if you have an error logging table)
        -- INSERT INTO ErrorLog (ErrorMessage, ErrorTime)
        -- VALUES (@ErrorMessage, GETUTCDATE());

        -- Re-throw the error
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO