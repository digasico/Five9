CREATE PROCEDURE rollup_agent_states
    @start_interval DATETIME,
    @end_interval DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    -- Step 1: Generate 15-minute-aligned time buckets
    WITH TimeBuckets AS (
        SELECT @start_interval AS interval_start
        UNION ALL
        SELECT DATEADD(MINUTE, 15, interval_start)
        FROM TimeBuckets
        WHERE DATEADD(MINUTE, 15, interval_start) < @end_interval
    ),

    -- Step 2: Join buckets to overlapping agent states
    OverlappingEvents AS (
        SELECT
            tb.interval_start,
            ae.agent_id,
            ae.domain_id,
            ae.state,

            -- Calculate overlap in seconds
            DATEDIFF(
                SECOND,
                CASE WHEN ae.state_start_datetime > tb.interval_start 
                     THEN ae.state_start_datetime 
                     ELSE tb.interval_start END,
                CASE WHEN ae.state_end_datetime < DATEADD(MINUTE, 15, tb.interval_start)
                     THEN ae.state_end_datetime 
                     ELSE DATEADD(MINUTE, 15, tb.interval_start) END
            ) AS overlap_seconds
        FROM TimeBuckets tb
        INNER JOIN agent_event ae
            ON ae.state_start_datetime < DATEADD(MINUTE, 15, tb.interval_start)
           AND ae.state_end_datetime > tb.interval_start
    ),

    -- Step 3: Aggregate with ROLLUP
    Aggregated AS (
        SELECT
            agent_id,
            domain_id,
            interval_start AS interval,
            state,
            SUM(overlap_seconds) AS agent_state_time,

            -- Tag rollup level
			CASE
				WHEN agent_id IS NOT NULL AND state IS NOT NULL AND interval_start IS NOT NULL AND domain_id IS NOT NULL THEN 'BASE'
				WHEN agent_id IS NOT NULL AND state IS NOT NULL AND interval_start IS NOT NULL AND domain_id IS NULL THEN 'AGENT_STATE_INTERVAL'
				WHEN agent_id IS NOT NULL AND state IS NOT NULL AND interval_start IS NULL AND domain_id IS NULL THEN 'AGENT_STATE'
				WHEN agent_id IS NOT NULL AND state IS NULL AND interval_start IS NULL AND domain_id IS NULL THEN 'AGENT'
				WHEN agent_id IS NULL AND state IS NULL AND interval_start IS NULL AND domain_id IS NULL THEN 'TOTAL'
				ELSE 'UNKNOWN'
			END AS rollup_level
        FROM OverlappingEvents
        GROUP BY ROLLUP(agent_id, state, interval_start, domain_id)
    )

    -- Step 4: Upsert results
    MERGE agent_state_interval AS target
	USING (
		SELECT
			agent_id,
			domain_id,
			interval,
			state,
			agent_state_time,
			rollup_level
		FROM Aggregated
	) AS source
	ON
		(
			(target.agent_id = source.agent_id) OR (target.agent_id IS NULL AND source.agent_id IS NULL)
		)
		AND (
			(target.domain_id = source.domain_id) OR (target.domain_id IS NULL AND source.domain_id IS NULL)
		)
		AND (
			(target.interval = source.interval) OR (target.interval IS NULL AND source.interval IS NULL)
		)
		AND (
			(target.state = source.state) OR (target.state IS NULL AND source.state IS NULL)
		)
		AND (
			(target.rollup_level = source.rollup_level) OR (target.rollup_level IS NULL AND source.rollup_level IS NULL)
		)
	WHEN MATCHED THEN
		UPDATE SET
			agent_state_time = source.agent_state_time,
			db_updated_datetime = GETUTCDATE()
	WHEN NOT MATCHED THEN
		INSERT (
			agent_id,
			domain_id,
			interval,
			state,
			agent_state_time,
			db_updated_datetime,
			db_created_datetime,
			rollup_level
		)
		VALUES (
			source.agent_id,
			source.domain_id,
			source.interval,
			source.state,
			source.agent_state_time,
			GETUTCDATE(),
			GETUTCDATE(),
			source.rollup_level
		);

END
GO